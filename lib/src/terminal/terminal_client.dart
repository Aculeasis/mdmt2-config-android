import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'dart:math' as math;

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:native_state/native_state.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;

const mAuthorization = 'authorization';
const mAuthorizationTOTP = 'authorization.totp';
const mDuplex = 'upgrade duplex';

const DEEP_DEBUG = false;

enum ConnectStage { wait, connected, connecting, sendAuth, sendDuplex, logger, controller, happy, closing }

enum WorkingStatChange { connecting, connected, closing, disconnected, disconnectedOnError }

enum WorkingMode { logger, controller }

class WorkingNotification {
  final ServerData server;
  final WorkingStatChange signal;
  WorkingNotification(this.server, this.signal);
}

class AsyncRequest {
  final String method;
  final AsyncResponseHandler handler;
  final int timestamp;
  AsyncRequest(this.method, this.handler) : timestamp = DateTime.now().millisecondsSinceEpoch;
}

class InternalCommand {
  final String cmd;
  final dynamic data;
  InternalCommand(this.cmd, this.data);
}

class Error {
  final int code;
  final String message;

  Error(this.code, this.message);

  Error.fromJson(Map<String, dynamic> json)
      : code = json['code'],
        message = json['message'];

  Map<String, dynamic> toJson() => {
        'code': code,
        'message': message,
      };

  @override
  String toString() => '{code: $code, message: "$message"}';
}

class Result<T> {
  final bool isMissing;
  T value;

  Result(this.value, {this.isMissing = false});

  @override
  String toString() => '${isMissing ? "missing" : value}';
}

class Response {
  final Result result;
  final Error error;
  final String id;

  Response(this.result, this.error, this.id);

  Response.fromJson(Map<String, dynamic> json)
      : result = Result(json['result'], isMissing: !json.containsKey('result')),
        error = json.containsKey('error') ? Error.fromJson(json['error']) : null,
        id = json['id'];

  @override
  String toString() => '{id: "$id",${result.isMissing ? '' : ' result: "$result",'}'
      '${error == null ? '' : ' error: "$error'}';
}

class Request {
  final String method;
  final dynamic params;
  final String id;

  Request(this.method, {this.params, this.id});

  Map<String, dynamic> toJson() => {
        'method': method,
        if (params is List<dynamic> || params is Map<String, dynamic>) 'params': params,
        if (id != null) 'id': id
      };
  Request.fromJson(Map<String, dynamic> json)
      : method = json['method'],
        params = json['params'],
        id = json['id'];

  @override
  String toString() {
    return '{method: "$method", params: "$params", id: "$id"}';
  }
}

enum WorkSignalsType { close, run, selfClose }

class WorkSignals {
  final WorkSignalsType type;
  final dynamic error;
  // У сокета нельзя узнать статус, когда он умирает то подвисает при закрытии
  // тогда будем закрывать его немного иначе.
  final isDead;
  WorkSignals(this.type, this.error, this.isDead);
}

class AsyncResponseHandler {
  final void Function(String method, Response response) handler;
  final void Function(String method, Error error) errorHandler;
  AsyncResponseHandler(this.handler, this.errorHandler);
}

abstract class TerminalClient {
  static const connectLimit = 10;
  static const closeLimit = 10;
  final StreamController<WorkingNotification> _workerNotifyGlobal;
  final StreamController<WorkingStatChange> _workerNotifyLocal = StreamController<WorkingStatChange>.broadcast();
  final StreamController<WorkSignals> _workSignal = StreamController<WorkSignals>();
  final ServerData server;
  final WorkingMode mode;
  @protected
  Log log;
  final String name;
  final SavedStateData _saved;
  IOWebSocketChannel _channel;
  StreamSubscription<dynamic> _listener;
  @protected
  ConnectStage stage = ConnectStage.wait;
  bool hasCriticalError;
  set setLog(Log newLog) => log = newLog;
  ConnectStage get getStage => stage;

  // макс пул отправленных
  static const maxAsyncRequestsPool = 100;
  // Для отправленных запросов, обработаем когда получим.
  final _asyncRequests = <String, AsyncRequest>{};
  // Тут будут обработчики
  final _asyncResponseHandlers = <String, AsyncResponseHandler>{};
  final _requestHandlers = <String, void Function(Request request)>{};
  // Регистрация обработчика, Response и Error всегда корректны.
  @protected
  void addResponseHandler(String method,
          {void Function(String method, Response response) handler,
          void Function(String method, Error error) errorHandler}) =>
      _asyncResponseHandlers[method] = AsyncResponseHandler(handler, errorHandler);
  // Для входящих запросов (уведомления)
  @protected
  void addRequestHandler(String method, void Function(Request request) handler) => _requestHandlers[method] = handler;
  @protected
  void removeRequestHandler(String method) => _requestHandlers.remove(method);

  TerminalClient(this.server, this.mode, this._workerNotifyGlobal, this._saved, this.name, {this.log}) {
    _restoreCriticalError();
    _workSignal.stream.listen((event) {
      if (stage == ConnectStage.connecting) return;
      if (event.type == WorkSignalsType.close || event.type == WorkSignalsType.selfClose) {
        // уже закрыли или закрываем
        if (isClosing)
          return;
        else {
          stage = ConnectStage.closing;
          _setCriticalError(event.error != null);
          _close(event, event.isDead);
        }
      } else if (event.type == WorkSignalsType.run)
      // Уже работает или запускается
      if (!isClosing)
        return;
      else {
        stage = ConnectStage.connecting;
        _runInput();
      }
    });
    void _criticalError(String method, Error error) =>
        sendSelfClose(error: '$method error ${error.code}: ${error.message}');
    void _authHandler(String method, Response response) {
      if (stage == ConnectStage.sendAuth) {
        pPrint('$method SUCCESS: ${response.result}');
        _sendPostAuth();
      } else {
        final msg = '$method error: unexpected message in $stage: $response';
        sendSelfClose(error: msg);
      }
    }

    addResponseHandler(mAuthorization, handler: _authHandler, errorHandler: _criticalError);
    addResponseHandler(mAuthorizationTOTP, handler: _authHandler, errorHandler: _criticalError);
    addResponseHandler(mDuplex, handler: (method, response) {
      if (stage == ConnectStage.sendDuplex) {
        stage = ConnectStage.controller;
        pPrint('Controller online: ${response.result}');
        _sendWorkNotify(WorkingStatChange.connected);
        onOk();
      } else {
        final msg = '$method error: unexpected message in $stage: $response';
        sendSelfClose(error: msg);
      }
    }, errorHandler: _criticalError);
  }

  StreamSubscription<WorkingStatChange> workerNotifyListen(void onData(WorkingStatChange event),
          {Function onError, void onDone(), bool cancelOnError}) =>
      _workerNotifyLocal.stream.listen(onData, onError: onError, onDone: onDone, cancelOnError: cancelOnError);

  // Закрывем сокет. Можно передать ошибку, тогда сокет будет закрыт с ошибкой.
  sendClose({dynamic error, bool isDead = false}) => _workSignal.add(WorkSignals(WorkSignalsType.close, error, isDead));
  @protected
  sendSelfClose({dynamic error, bool isDead = false}) =>
      _workSignal.add(WorkSignals(WorkSignalsType.selfClose, error, isDead));
  // Запускаем сокет, если он еще не запущен
  sendRun() => _workSignal.add(WorkSignals(WorkSignalsType.run, null, false));

  _runInput() async {
    _setCriticalError(false);
    _sendWorkNotify(WorkingStatChange.connecting);
    toSysLog('Start connecting to ${server.uri}...');
    _channel = null;
    final limit = Duration(seconds: connectLimit);
    try {
      _channel = IOWebSocketChannel(await WebSocket.connect('ws://${server.uri}').timeout(limit));
    } on TimeoutException {
      return _connectingError('Connecting timeout ($connectLimit seconds).');
    } catch (e) {
      return _connectingError('Connecting Error: "$e"!');
    }
    _listener = _channel.stream.listen((dynamic message) {
      _parse(message);
      pPrint('recived $message');
    }, onDone: () {
      sendSelfClose();
      pPrint('ws channel closed');
    }, onError: (error) {
      sendSelfClose(error: error, isDead: true);
      pPrint('ws error $error');
    }, cancelOnError: true // cancelOnError
        );

    stage = ConnectStage.connected;
    if (server.wsToken != '') _send(server.wsToken);
    if (server.token != '') {
      stage = ConnectStage.sendAuth;
      _sendAuth(server.token);
    } else {
      _sendPostAuth();
    }
  }

  void _connectingError(String msg) {
    if (msg != null) toSysLog(msg);
    _setCriticalError(true);
    stage = ConnectStage.wait;
    _sendWorkNotify(WorkingStatChange.disconnectedOnError);
  }

  _close(WorkSignals event, bool isDead) async {
    if (_channel != null) {
      final _close = _channel.sink.close;
      _channel = null;
      _listener?.cancel();
      _sendWorkNotify(WorkingStatChange.closing);
      dynamic timeoutError;
      try {
        await _close(status.normalClosure).timeout(Duration(seconds: isDead ? 1 : closeLimit));
      } on TimeoutException catch (e) {
        timeoutError = e;
      }
      onClose(event.error ?? timeoutError, event.type);
      _sendWorkNotify((event.error ?? timeoutError) != null
          ? WorkingStatChange.disconnectedOnError
          : WorkingStatChange.disconnected);
      if (event.error != null) {
        if (hasCriticalError) timeoutError = null;
        toSysLog('Connecting error: ${event.error}');
      }
      String msg = 'Connection close';
      if (timeoutError != null) msg = '$msg by timeout(${TerminalClient.closeLimit} sec, socket stuck)';
      toSysLog('$msg.');
    }
    stage = ConnectStage.wait;
  }

  bool get isClosing => stage == ConnectStage.wait || stage == ConnectStage.closing;

  void dispose() {
    _workSignal.close();
    _workerNotifyLocal.close();
    _channel?.sink?.close();
    _setCriticalError(false);
    debugPrint('DISPOSE $name');
  }

  _send(dynamic data) async {
    if (isWork) {
      pPrint('send $data');
      _channel.sink.add(data);
    }
  }

  void _setCriticalError(bool isCritical) {
    hasCriticalError = isCritical;
    _saved?.putBool('${name}_hasCriticalError', isCritical);
  }

  void _restoreCriticalError() => hasCriticalError = _saved?.getBool('${name}_hasCriticalError') ?? false;

  @protected
  callJRPC(String method, {dynamic params, AsyncResponseHandler handler, bool isNotify = false}) {
    String id;
    if ((_asyncResponseHandlers.containsKey(method) || handler != null) && !isNotify) {
      id = _makeRandomId();
      _addAsyncRequest(id, method, handler);
    }
    _send(jsonEncode(Request(method, params: params, id: id)));
  }

  _addAsyncRequest(String id, method, AsyncResponseHandler handler) {
    if (_asyncRequests.length > maxAsyncRequestsPool) {
      toSysLog('WARNING! AsyncRequestsPool overloaded! Remove half.');
      final pool = _asyncRequests.keys.toList()
        ..sort((a, b) => _asyncRequests[a].timestamp - _asyncRequests[b].timestamp);
      for (int i = 0; i < (pool.length / 2).ceil(); i++) {
        _asyncRequests.remove(pool[i]);
      }
    }
    _asyncRequests[id] = AsyncRequest(method, handler);
  }

  bool get isWork => _channel != null && _channel.closeCode == null;
  bool get isHandshake =>
      stage == ConnectStage.sendAuth || stage == ConnectStage.sendDuplex || stage == ConnectStage.connected;

  _sendWorkNotify(WorkingStatChange signal) {
    if (_workerNotifyGlobal.hasListener) _workerNotifyGlobal.add(WorkingNotification(server, signal));
    if (_workerNotifyLocal.hasListener) _workerNotifyLocal.add(signal);
  }

  _sendAuth(String token) {
    if (server.totpSalt) {
      final timeTime = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
      callJRPC(mAuthorizationTOTP, params: {'hash': _makeHashWithTOTP(token, timeTime), 'timestamp': timeTime});
    } else
      callJRPC(mAuthorization, params: ['${sha512.convert(utf8.encode(token))}']);
  }

  _parse(dynamic msg) async {
    if (stage == ConnectStage.logger) {
      return await onLogger(msg);
    }
    dynamic result;
    try {
      result = jsonDecode(msg);
    } on FormatException catch (e) {
      pPrint('Json parsing error $msg :: $e');
      // Ошибка во время рукопожатия недопустима.
      if (isHandshake) {
        sendSelfClose(error: 'Handshake error: "$e"');
      }
      return;
    }
    if (!(result is List)) result = [result];
    for (var line in result) {
      Map<String, dynamic> jsonRPC;
      Request request;
      Response response;

      try {
        jsonRPC = line;
      } catch (e) {
        pPrint('Wrong JSON-RPC "$msg": $e');
        continue;
      }
      line = null;

      if (jsonRPC.containsKey('method')) {
        try {
          request = Request.fromJson(jsonRPC);
        } catch (e) {
          pPrint('Wrong JSON-RPC request "$msg": $e');
          continue;
        }
      } else {
        try {
          response = Response.fromJson(jsonRPC);
        } catch (e) {
          pPrint('Wrong JSON-RPC response "$msg": $e');
          continue;
        }
      }
      jsonRPC = null;

      if (request != null) {
        _parseRequest(request);
      } else if (!_parseResponse(response)) {
        return;
      }
    }
  }

  bool _parseResponse(Response response) {
    final asyncRequest = _asyncRequests.remove(response.id);
    final handler = asyncRequest?.handler ?? _asyncResponseHandlers[asyncRequest?.method];
    final error = _responseErrorProcessing(response, asyncRequest, handler);
    if (error != null) {
      pPrint('Recive error id=${response.id}, error: $error');
      if (isHandshake) {
        sendSelfClose(error: '$error');
        return false;
      }
      if (handler?.errorHandler != null) handler.errorHandler(asyncRequest?.method, response.error);
    } else {
      if (handler?.handler != null) handler.handler(asyncRequest?.method, response);
    }
    return true;
  }

  Error _responseErrorProcessing(Response response, AsyncRequest asyncRequest, AsyncResponseHandler handler) {
    String msg;
    int code = -999;
    if (response.error != null) {
      if (!response.result.isMissing) {
        msg = 'Wrong JSON-RPC response: error and result present!';
      } else {
        msg = response.error.message ?? 'missing';
        code = response.error.code;
      }
    } else if (response.error == null && response.result.isMissing) {
      msg = 'Wrong JSON-RPC response: error and result missing!';
    } else if (response.id == null) {
      msg = 'Wrong JSON-RPC response: result is present and id=null';
    } else if (asyncRequest == null) {
      msg = 'Unregistered response: "$response"';
    } else if (handler == null) {
      msg = 'Unsupported response id=${response.id}: "$response"';
    }
    return msg != null ? Error(code, msg) : null;
  }

  void _parseRequest(Request request) {
    final handler = _requestHandlers[request.method];
    final error = _requestErrorProcessing(request, handler);
    if (error != null)
      pPrint(error);
    else
      handler(request);
  }

  String _requestErrorProcessing(Request request, void Function(Request) handler) {
    String msg;
    if (request.method == null || request.method == '') {
      msg = 'Wrong JSON-RPC request, method missing: $request';
    } else if (request.params == null) {
      msg = 'Wrong JSON-RPC request, params missing: $request';
    } else if (handler == null) {
      msg = 'Received unsupported request: $request';
    }
    return msg;
  }

  _sendPostAuth() {
    if (mode == WorkingMode.logger) {
      stage = ConnectStage.logger;
      callJRPC('remote_log', params: ['json'], isNotify: true);
      _sendWorkNotify(WorkingStatChange.connected);
      onOk();
    } else if (mode == WorkingMode.controller) {
      stage = ConnectStage.sendDuplex;
      // FIXME DEPRECATED: params не нужен с mdmTerminal2 0.15.7, потом убрать
      callJRPC(mDuplex, params: {'notify': false});
    } else {
      stage = ConnectStage.happy;
      _sendWorkNotify(WorkingStatChange.connected);
    }
  }

  @protected
  pPrint(String msg) {
    if (DEEP_DEBUG) debugPrint('* ${DateTime.now().toUtc().millisecondsSinceEpoch} ${server.uri}~$msg');
  }

  // Будет вызываться пока stage == ConnectStage.logger
  // Получает сообщения напрямую, без обработки, для логгера
  onLogger(dynamic msg);

  // Подключились.
  onOk();

  // Отключились (до отправки сигналов)
  onClose(dynamic error, WorkSignalsType type);

  @protected
  toSysLog(String msg) => log?.addSystem(msg, callers: ['（=ﾟ･ﾟ=）', name]);
}

String _makeRandomId() {
  final data = '${DateTime.now().microsecondsSinceEpoch}${math.Random().nextDouble()}';
  return '${md5.convert(utf8.encode(data))}';
}

String _makeHashWithTOTP(String token, double timeTime, {int interval = 2}) {
  int salt = (timeTime.roundToDouble() / interval).truncate();
  return '${sha512.convert(utf8.encode(token + salt.toString()))}';
}
