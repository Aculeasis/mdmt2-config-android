import 'dart:async';

import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/servers/servers_controller.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_instance.dart';
import 'package:native_state/native_state.dart';

class BackupLine {
  final String filename;
  final DateTime time;
  BackupLine(this.filename, this.time);
}

abstract class _BaseCMD {
  final String method;
  final dynamic params;
  _BaseCMD(this.method, this.params);
}

class _InternalCommand extends _BaseCMD {
  _InternalCommand(method, params) : super(method, params);
}

class _InternalCommandAlways extends _BaseCMD {
  _InternalCommandAlways(method, params) : super(method, params);
}

class _ExternalJRPC extends _BaseCMD {
  final AsyncResponseHandler handler;
  final bool isNotify;
  final Duration timeout;
  _ExternalJRPC(method, params, this.handler, this.isNotify, this.timeout) : super(method, params);
}

enum _ReconnectStage { no, maybe, really }

class TerminalControl extends TerminalClient {
  static const musicStateMap = {
    'pause': MusicStatus.pause,
    'play': MusicStatus.play,
    'stop': MusicStatus.stop,
    'disabled': MusicStatus.nope,
  };
  static const allowValueCMD = {'tts', 'ask', 'rec', 'volume', 'mvolume', 'backup.restore'};
  static const allowEmptyCMD = {
    'voice',
    'maintenance.reload',
    'maintenance.stop',
    'pause',
    'backup.manual',
    'backup.list'
  };

  final subscribeTo = [
    'backup',
    'listener',
    'volume',
    'music_volume',
    'music_status',
  ];

  final _seeInToads = StreamController<String>.broadcast();
  final _sendBackupList = StreamController<List<BackupLine>>.broadcast();
  final _externalStreamCMD = StreamController<_BaseCMD>();
  final InstanceViewState view;
  final Reconnect reconnect;
  final changeFnCallback _change;
  _ReconnectStage _reconnectStage = _ReconnectStage.no;

  TerminalControl(ServerData server, SavedStateData saved, log, this.view, this.reconnect, this._change)
      : super(server, saved, log) {
    subscribeTo.addAll(view.buttons.keys);
    _externalStreamCMD.stream.listen((e) {
      if (e is _InternalCommandAlways) {
        _externalCMDAlways(e.method.toLowerCase());
        return;
      }

      if (stage != ConnectStage.work) return;
      if (e is _InternalCommand)
        _externalCMD(e.method.toLowerCase(), e.params);
      else if (e is _ExternalJRPC)
        callJRPC(e.method.toLowerCase(),
            params: e.params, handler: e.handler, isNotify: e.isNotify, timeout: e.timeout);
    });
    _addHandlers();
  }

  Stream<String> get streamToads => _seeInToads.stream;
  Stream<List<BackupLine>> get streamBackupList => _sendBackupList.stream;

  // Для внешних вызовов
  executeChange(String cmd, {dynamic data}) => _externalStreamCMD.add(_InternalCommandAlways(cmd, data));
  executeMe(String cmd, {dynamic data}) => _externalStreamCMD.add(_InternalCommand(cmd, data));
  callJRPCExternal(String method, {params, AsyncResponseHandler handler, bool isNotify = false, Duration timeout}) =>
      _externalStreamCMD.add(_ExternalJRPC(method, params, handler, isNotify, timeout));

  @override
  void dispose() {
    _sendBackupList.close();
    _seeInToads.close();
    _externalStreamCMD.close();
    super.dispose();
  }

  @override
  onClose(error, type) {
    if (error == null && _reconnectStage == _ReconnectStage.really && type == WorkSignalsType.selfClose)
      reconnect.activate();
    _reconnectStage = _ReconnectStage.no;
  }

  @override
  onOk() {
    _reconnectStage = _ReconnectStage.no;
    view.reset();
    if (server.log.value) _logSubscriber(true);
    if (server.qry.value) _cmdSubscriber(true);

    callJRPC('get',
        params: ['listener', 'volume', 'mvolume', 'mstate'],
        handler: AsyncResponseHandler((_, response) {
          view.listenerOnOff.value = _getFromMap<bool>('listener', response) ?? view.listenerOnOff.value;
          view.volume.value = _volumeSanitize(_getFromMap<int>('volume', response));
          view.musicVolume.value = _volumeSanitize(_getFromMap<int>('mvolume', response));
          view.musicStatus.value = _mStateSanitize(_getFromMap<String>('mstate', response));
        }, null));

    callJRPC('subscribe',
        params: subscribeTo,
        handler: AsyncResponseHandler((method, response) {
          if ((_getResponseAs(method, response) ?? false)) {
            for (String cmd in subscribeTo) addRequestHandler('notify.$cmd', _handleNotify);
          }
        }, null));
  }

  void _logSubscriber(bool subscribe) => _baseSubscriber(subscribe, 'log', () {
        if (subscribe != server.log.value) _change(server, log: subscribe);
      });

  void _cmdSubscriber(bool subscribe) => _baseSubscriber(subscribe, 'cmd', () {
        if (subscribe != server.qry.value) _change(server, qry: subscribe);
      });

  void _baseSubscriber(bool subscribe, String cmd, Function successCallback) {
    if (stage != ConnectStage.work) return successCallback();
    callJRPC(subscribe ? 'subscribe' : 'unsubscribe',
        params: [cmd],
        handler: AsyncResponseHandler((method, response) {
          if ((_getResponseAs(method, response) ?? false)) {
            final target = 'notify.$cmd';
            subscribe ? addRequestHandler(target, _handleNotify) : removeRequestHandler(target);
            successCallback();
          }
        }, null));
  }

  void _callToast(String msg) {
    if (_seeInToads.hasListener) _seeInToads.add(msg);
  }

  void _externalCMDAlways(String cmd) {
    if (cmd == 'qry') {
      _cmdSubscriber(!server.qry.value);
    } else if (cmd == 'log') {
      _logSubscriber(!server.log.value);
    } else
      _callToast('Unknown command: "$cmd"');
  }

  void _externalCMD(String cmd, dynamic data) {
    bool wrongData() => data == null || (data is String && data == '');
    dynamic params;
    if (cmd == 'listener') {
      params = [view.listenerOnOff.value ? 'off' : 'on'];
    } else if (cmd == 'ping') {
      params = {'time': DateTime.now().microsecondsSinceEpoch};
    } else if (cmd == 'play') {
      if (!wrongData()) params = ['$data'];
    } else if (allowValueCMD.contains(cmd)) {
      if (wrongData())
        return _callToast('What did you want?');
      else
        params = ['$data'];
    } else if (!allowEmptyCMD.contains(cmd)) {
      return _callToast('Unknown command: "$cmd"');
    }
    if (stage == ConnectStage.work) callJRPC(cmd, params: params);
  }

  _addHandlers() {
    void _error(String method, Error error) => _callToast('"$method" error: $error');
    addResponseHandler('ping', handler: (_, response) {
      int time = DateTime.now().microsecondsSinceEpoch;
      try {
        time = time - response.result.value['time'];
      } catch (e) {
        final msg = 'Ping parsing error: $e';
        pPrint(msg);
        _callToast(msg);
        return;
      }
      _callToast('Ping ${(time / 1000).toStringAsFixed(2)} ms');
    }, errorHandler: _error);
    addResponseHandler('rec', errorHandler: _error);
    addResponseHandler('backup.list',
        handler: (_, response) {
          final files = <BackupLine>[];
          try {
            for (Map<String, dynamic> file in response.result.value) {
              final String filename = file['filename'];
              final double timestamp = file['timestamp'];
              if (filename == null || filename == '') throw 'Empty filename in $file';
              if (timestamp == null) throw 'Empty timestamp in $file';
              files.add(BackupLine(filename, LogLine.timeToDateTime(timestamp)));
            }
          } catch (e) {
            final msg = 'backup.list parsing error: $e';
            _sendBackupList.addError(msg);
            pPrint(msg);
            return;
          }
          files.sort((a, b) => b.time.microsecondsSinceEpoch - a.time.microsecondsSinceEpoch);
          if (files.isEmpty) {
            _sendBackupList.addError('No backups');
          } else {
            _sendBackupList.add(files);
          }
        },
        errorHandler: (_, error) => _sendBackupList.addError('backup.list error: $error'));
    addResponseHandler('backup.restore', handler: (_, response) {
      _reconnectStage = _ReconnectStage.maybe;
      final filename = _getFromMap<String>('filename', response) ?? '.. ambiguous result';
      _callToast('Restoring started from $filename');
    }, errorHandler: _error);
    addResponseHandler('maintenance.reload', handler: (_, __) => _reconnectStage = _ReconnectStage.maybe);
  }

  _handleNotify(Request request) {
    final list = request.method.split('.')..removeAt(0);
    final method = list.join('.');
    if (request.id != null) {
      pPrint('Wrong notification: $request');
      return;
    }
    if (view.buttons.containsKey(method)) {
      final value = _getFirstArg<bool>(request);
      if (value != null) {
        if (method == 'terminal_stop' && _reconnectStage == _ReconnectStage.maybe)
          _reconnectStage = _ReconnectStage.really;
        view.buttons[method].value = value;
      }

      return;
    }
    switch (method) {
      case 'log':
        final logList = _getArg<List>(request);
        if (logList != null) log.addFromResponse(logList);
        break;
      case 'backup':
        final value = (_getFirstArg<String>(request) ?? 'error').toUpperCase();
        _callToast('Backup: $value');
        break;
      case 'listener':
        view.listenerOnOff.value = _getFirstArg<bool>(request) ?? view.listenerOnOff.value;
        break;
      case 'volume':
        view.volume.value = _volumeSanitize(_getFirstArg<int>(request));
        break;
      case 'music_volume':
        view.musicVolume.value = _volumeSanitize(_getFirstArg<int>(request));
        break;
      case 'music_status':
        view.musicStatus.value = _mStateSanitize(_getFirstArg<String>(request));
        break;
      case 'cmd':
        final msg = _getKWArgsValue<String>('qry', request);
        String username = _getKWArgsValue<String>('username', request, noError: true) ?? '';
        if (msg == null) return;
        if (username.isNotEmpty) username = ', User: "$username"';
        _callToast('QRY: "$msg"$username');
        break;
      default:
        pPrint('Unknown notification $method: $request');
        break;
    }
  }

  static int _volumeSanitize(int volume) {
    if (volume == null) return -1;
    if (volume < 0)
      volume = -1;
    else if (volume > 100) volume = 100;
    return volume;
  }

  static MusicStatus _mStateSanitize(String mState) => musicStateMap[mState] ?? MusicStatus.error;

  T _getFromMap<T>(String key, Response response) {
    T result;
    dynamic error;
    try {
      result = response.result.value[key];
    } catch (e) {
      error = e;
    }
    if (result == null) pPrint('Error parsing $response: $error');
    return result;
  }

  T _getFirstArg<T>(Request request) {
    T result;
    dynamic error;
    try {
      result = request.params['args'][0];
    } catch (e) {
      error = e;
    }
    if (result == null) pPrint('Error parsing $request: $error');
    return result;
  }

  T _getArg<T>(Request request) {
    T result;
    dynamic error;
    try {
      result = request.params['args'];
    } catch (e) {
      error = e;
    }
    if (result == null) pPrint('Error parsing $request: $error');
    return result;
  }

  T _getKWArgsValue<T>(String key, Request request, {bool noError = false}) {
    T result;
    dynamic error;
    try {
      result = request.params['kwargs'][key];
    } catch (e) {
      error = e;
    }
    if (result == null && !noError) pPrint('Error parsing $request: $error');
    return result;
  }

  T _getResponseAs<T>(String method, Response response) {
    T result;
    try {
      result = response.result.value;
    } catch (e) {
      pPrint('Wrong response to $method result: $e');
      return null;
    }
    return result;
  }
}
