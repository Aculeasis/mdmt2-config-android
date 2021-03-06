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

enum ConnectStage { wait, connected, connecting, sendAuth, sendDuplex, work, closing }

enum WorkingStatChange { connecting, broken, connected, closing, close, closeOnError }

class WorkingNotification {
  final ServerData server;
  final WorkingStatChange signal;
  WorkingNotification(this.server, this.signal);
}

class AsyncRequest {
  final String method;
  final AsyncResponseHandler handler;
  final Timer timer;
  AsyncRequest(this.method, this.handler, this.timer);
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
  WorkSignals(this.type, this.error);
}

class AsyncResponseHandler {
  final OnResponseFn onResponse;
  final OnErrorFn onError;
  AsyncResponseHandler(this.onResponse, this.onError);
}

class _BatchEntry {
  final String method;
  final dynamic params;
  final AsyncResponseHandler handler;
  final Duration timeout;
  final String id;
  _BatchEntry(this.method, this.params, this.handler, this.timeout, this.id);
}

class CallJRPCBatch {
  final _data = <_BatchEntry>[];
  final AddAsyncRequestFn _addAsyncRequest;
  final SendFn _send;

  CallJRPCBatch(this._addAsyncRequest, this._send);

  void add(String method, {dynamic params, AsyncResponseHandler handler, Duration timeout}) {
    _data.add(_BatchEntry(method, params, handler, timeout, handler != null ? _makeRandomId() : null));
  }

  void send() {
    final request = [for (var obj in _data) Request(obj.method, params: obj.params, id: obj.id).toJson()];
    if (request.isNotEmpty && _send(jsonEncode(request))) {
      for (var obj in _data) if (obj.id != null) _addAsyncRequest(obj.id, obj.method, obj.handler, obj.timeout);
    }
    _data.clear();
  }
}

abstract class TerminalClient {
  static const connectLimit = 10;
  static const closeLimit = 10;
  static const maxAsyncRequestsPool = 100; // макс пул отправленных
  static const asyncRequestPopTimeout = Duration(seconds: 600); // Всегда выкидываем запрос из пула по таймауту

  final _stateStream = StreamController<WorkingNotification>.broadcast();
  final _workSignal = StreamController<WorkSignals>();
  // Для отправленных запросов, обработаем когда получим.
  final _asyncRequests = <String, AsyncRequest>{};
  // Тут будут обработчики
  final _responseHandlers = <String, AsyncResponseHandler>{};
  final _requestHandlers = <String, void Function(Request request)>{};

  final ServerData server;
  final Log log;
  final SavedStateData _saved;
  IOWebSocketChannel _channel;
  StreamSubscription<dynamic> _listener;
  ConnectStage _stage = ConnectStage.wait;
  bool hasCriticalError;

  TerminalClient(this.server, this._saved, this.log) {
    _restoreCriticalError();
    _responseHandlers.addAll(_makeResponseHandlers());
    _workSignal.stream.listen((event) {
      if (_stage == ConnectStage.connecting) return;
      if (event.type == WorkSignalsType.close || event.type == WorkSignalsType.selfClose) {
        if (_stage != ConnectStage.wait && _stage != ConnectStage.closing) _closeInput(event);
      } else if (event.type == WorkSignalsType.run) {
        if (_stage == ConnectStage.wait) _runInput();
      }
    });
  }

  Map<String, AsyncResponseHandler> _makeResponseHandlers() {
    void onCriticalError(String method, Error error) =>
        _sendSelfClose(error: '$method error ${error.code}: ${error.message}');
    void badStage(String method, Response response) =>
        _sendSelfClose(error: '$method error: unexpected message in $_stage: $response');

    void onAuth(String method, Response response) {
      if (_stage == ConnectStage.sendAuth) {
        _stage = ConnectStage.sendDuplex;
        pPrint('$method SUCCESS: ${response.result}');
        callJRPC(mDuplex, handler: _responseHandlers[mDuplex]);
      } else {
        badStage(method, response);
      }
    }

    void onDuplex(String method, Response response) {
      if (_stage == ConnectStage.sendDuplex) {
        _stage = ConnectStage.work;
        pPrint('Controller online: ${response.result}');
        _sendWorkNotify(WorkingStatChange.connected);
        onOk();
      } else {
        badStage(method, response);
      }
    }

    return {
      mDuplex: AsyncResponseHandler(onDuplex, onCriticalError),
      mAuthorization: AsyncResponseHandler(onAuth, onCriticalError),
    };
  }

  ConnectStage get getStage => _stage;
  Stream<WorkingNotification> get stateStream => _stateStream.stream;
  // Для входящих запросов (уведомления)
  @protected
  void addRequestHandler(String method, void Function(Request request) handler) => _requestHandlers[method] = handler;
  @protected
  void removeRequestHandler(String method) => _requestHandlers.remove(method);
  // Закрывем сокет. Можно передать ошибку, тогда сокет будет закрыт с ошибкой.
  sendClose({dynamic error}) => _workSignal.add(WorkSignals(WorkSignalsType.close, error));
  _sendSelfClose({dynamic error}) => _workSignal.add(WorkSignals(WorkSignalsType.selfClose, error));
  // Запускаем сокет, если он еще не запущен
  sendRun() => _workSignal.add(WorkSignals(WorkSignalsType.run, null));

  _runInput() async {
    _stage = ConnectStage.connecting;
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
      _sendSelfClose();
      pPrint('ws channel closed');
    }, onError: (error) {
      _sendSelfClose(error: error);
      pPrint('ws error $error');
    }, cancelOnError: true // cancelOnError
        );

    _stage = ConnectStage.connected;
    if (server.wsToken != '') _send(server.wsToken);

    _stage = ConnectStage.sendAuth;
    _sendAuth(server.token != '' ? server.token : 'empty');
  }

  void _connectingError(String msg) {
    if (msg != null) toSysLog(msg);
    _setCriticalError(true);
    _stage = ConnectStage.wait;
    _sendWorkNotify(WorkingStatChange.broken);
  }

  _closeInput(WorkSignals event) async {
    _stage = ConnectStage.closing;
    _setCriticalError(event.error != null);
    _clearAsyncRequests();
    if (_channel != null) {
      final _close = _channel.sink.close;
      _channel = null;
      _listener?.cancel();
      _sendWorkNotify(WorkingStatChange.closing);
      dynamic timeoutError;
      try {
        await _close(status.normalClosure).timeout(Duration(seconds: closeLimit));
      } on TimeoutException catch (e) {
        timeoutError = e;
      }
      onClose(event.error ?? timeoutError, event.type);
      _sendWorkNotify((event.error ?? timeoutError) != null ? WorkingStatChange.closeOnError : WorkingStatChange.close);
      if (event.error != null) {
        if (hasCriticalError) timeoutError = null;
        toSysLog('Connecting error: ${event.error}');
      }
      String msg = 'Connection close';
      if (timeoutError != null) msg = '$msg by timeout(${TerminalClient.closeLimit} sec, socket stuck)';
      toSysLog('$msg.');
    }
    _stage = ConnectStage.wait;
  }

  void _clearAsyncRequests() {
    for (var item in _asyncRequests.values) item.timer.cancel();
    _asyncRequests.clear();
  }

  void dispose() {
    _workSignal.close();
    _stateStream.close();
    _channel?.sink?.close();
    _setCriticalError(false);
    _clearAsyncRequests();
    _requestHandlers.clear();
    debugPrint('DISPOSE ${server.uri}');
  }

  bool _send(dynamic data) {
    if (isWork) {
      pPrint('send $data');
      _channel.sink.add(data);
      return true;
    }
    return false;
  }

  void _setCriticalError(bool isCritical) {
    hasCriticalError = isCritical;
    _saved?.putBool('_hasCriticalError', isCritical);
  }

  void _restoreCriticalError() => hasCriticalError = _saved?.getBool('_hasCriticalError') ?? false;

  @protected
  callJRPC(String method, {dynamic params, AsyncResponseHandler handler, Duration timeout}) {
    String id = handler != null ? _makeRandomId() : null;
    if (_send(jsonEncode(Request(method, params: params, id: id))) && id != null) {
      _addAsyncRequest(id, method, handler, timeout);
    }
  }

  @protected
  CallJRPCBatch getJRPCBatch() => CallJRPCBatch(_addAsyncRequest, _send);

  void _addAsyncRequest(String id, String method, AsyncResponseHandler handler, Duration timeout) {
    if (_asyncRequests.length > maxAsyncRequestsPool) {
      final removeLength = _asyncRequests.length ~/ 2;
      toSysLog('WARNING! AsyncRequestsPool overloaded! Remove $removeLength.');
      final removePool = _asyncRequests.keys.take(removeLength).toList(growable: false);
      for (var key in removePool) _asyncRequests.remove(key).timer?.cancel();
    }
    final timer = timeout == null
        ? Timer(asyncRequestPopTimeout, () => _popRequestHandler(id))
        : Timer(
            timeout, // Дурим обработчика подсовывая ему ответ с ошибкой
            () => _parseResponse(Response(
                Result(null, isMissing: true), Error(-1, 'Request timeout (${timeout.inMilliseconds} ms)'), id)));
    _asyncRequests[id] = AsyncRequest(method, handler, timer);
  }

  bool get isWork => _channel != null && _channel.closeCode == null;
  bool get isHandshake =>
      _stage == ConnectStage.sendAuth || _stage == ConnectStage.sendDuplex || _stage == ConnectStage.connected;

  void _sendWorkNotify(WorkingStatChange signal) => _stateStream.add(WorkingNotification(server, signal));

  _sendAuth(String token) {
    String method;
    dynamic params;
    if (server.totpSalt) {
      final timeTime = DateTime.now().toUtc().millisecondsSinceEpoch / 1000;
      method = mAuthorizationTOTP;
      params = {'hash': _makeHashWithTOTP(token, timeTime), 'timestamp': timeTime};
    } else {
      method = mAuthorization;
      params = ['${sha512.convert(utf8.encode(token))}'];
    }
    callJRPC(method, params: params, handler: _responseHandlers[mAuthorization]);
  }

  _parse(dynamic msg) async {
    dynamic result;
    try {
      result = jsonDecode(msg);
    } on FormatException catch (e) {
      pPrint('Json parsing error $msg :: $e');
      // Ошибка во время рукопожатия недопустима.
      if (isHandshake) {
        _sendSelfClose(error: 'Handshake error: "$e"');
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

  void _popRequestHandler(String id) {
    final asyncRequest = _asyncRequests.remove(id)..timer.cancel();
    toSysLog('WARNING! Request "${asyncRequest.method}" not completed on ${asyncRequestPopTimeout.inSeconds} seconds.');
  }

  bool _parseResponse(Response response) {
    final asyncRequest = _asyncRequests.remove(response.id);
    asyncRequest?.timer?.cancel();
    final handler = asyncRequest?.handler;
    final error = _responseErrorProcessing(response, handler);
    if (error != null) {
      pPrint('Recive error id=${response.id}, error: $error');
      if (isHandshake) {
        _sendSelfClose(error: '$error');
        return false;
      }
      if (handler?.onError != null) handler.onError(asyncRequest?.method, error);
    } else {
      if (handler?.onResponse != null) handler.onResponse(asyncRequest?.method, response);
    }
    return true;
  }

  static Error _responseErrorProcessing(Response response, AsyncResponseHandler handler) {
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
    } else if (handler == null) {
      msg = 'Unregistered response id=${response.id}: "$response"';
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

  static String _requestErrorProcessing(Request request, void Function(Request) handler) {
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

  @protected
  pPrint(String msg) {
    if (DEEP_DEBUG) debugPrint('* ${DateTime.now().toUtc().millisecondsSinceEpoch} ${server.uri}~$msg');
  }

  // Подключились.
  onOk();

  // Отключились (до отправки сигналов)
  onClose(dynamic error, WorkSignalsType type);

  @protected
  toSysLog(String msg) => log.addSystem(msg);
}

String _makeRandomId() {
  final data = '${DateTime.now().microsecondsSinceEpoch}${math.Random().nextDouble()}';
  return '${md5.convert(utf8.encode(data))}';
}

String _makeHashWithTOTP(String token, double timeTime, {int interval = 2}) {
  final salt = (timeTime.roundToDouble() / interval).truncate();
  return '${sha512.convert(utf8.encode(token + salt.toString()))}';
}

typedef OnResponseFn = void Function(String method, Response response);
typedef OnErrorFn = void Function(String method, Error error);
typedef CallJRPCFn = void Function(String method, {dynamic params, AsyncResponseHandler handler, Duration timeout});
typedef AddAsyncRequestFn = void Function(String id, String method, AsyncResponseHandler handler, Duration timeout);
typedef SendFn = bool Function(dynamic data);
