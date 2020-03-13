import 'dart:async';

import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';

class EntryInfo {
  final String msg;
  final List<String> flags;
  final bool isError;
  EntryInfo(String msg, List<String> flags, {this.isError = false})
      : this.msg = msg ?? 'Empty',
        this.flags = flags ?? List(0);
  @override
  bool operator ==(other) => other is EntryInfo && msg == other.msg && flags == other.flags && isError == other.isError;
  @override
  int get hashCode => '${msg.hashCode}${flags.hashCode}$isError'.hashCode;

  EntryInfo.fromJson(Map<String, dynamic> json)
      : msg = json['msg'] != null ? (json['msg'] as String).split('\n').map((e) => e.trim()).join('\n') : 'Empty',
        flags = json['flags'] != null ? List<String>.from(json['flags'], growable: false) : List(0),
        isError = false;
}

enum ResultMode { ok, await }

class Result {
  final ResultMode mode;
  final Map<String, EntryInfo> data;
  Result(this.mode, this.data);
}

class ApiViewBLoC {
  static const timeLimit = Duration(seconds: 10);
  static const mInfo = 'info';
  final TerminalControl _control;
  final InstanceViewState _view;
  final _methodStream = StreamController<String>();
  final _resultStream = StreamController<Result>();
  final _onlyOne = <String>{};
  StreamSubscription<WorkingNotification> _stateStreamSubscription;
  bool isConnected;

  ApiViewBLoC(this._control, this._view) : isConnected = _control.getStage == ConnectStage.work {
    _methodStream.stream.listen((api) {
      if (!isConnected || _onlyOne.contains(api)) return;

      if (api.isEmpty) {
        _onlyOne
          ..clear()
          ..add(api);
        _sendResult(ResultMode.await);
        _control.callJRPCExternal(mInfo,
            handler: AsyncResponseHandler((_, response) => _handleAPIList(response),
                (_, error) => _handleAPIListError('Error: ${error.code}: ${error.message}')),
            timeout: timeLimit);
      } else {
        _onlyOne.add(api);
        _control.callJRPCExternal(mInfo,
            params: [api],
            handler: AsyncResponseHandler(
                (_, response) => _handleAPIIfo(api, response), (_, error) => _handleAPIInfoError(api, error)),
            timeout: timeLimit);
      }
    });

    _stateStreamSubscription = _control.stateStream.listen((event) {
      if (!isConnected && _control.getStage == ConnectStage.work) {
        isConnected = true;
      } else if (isConnected && _control.getStage != ConnectStage.work) {
        isConnected = false;
        _onlyOne.clear();
      }
    });
  }

  Stream<Result> get result => _resultStream.stream;
  void getAPIList() => _methodStream.add('');
  void getAPIInfo(String api) => _methodStream.add(api);
  void start() => _view.dataAPIView.isEmpty ? getAPIList() : _sendResult();

  void _handleAPIList(Response response) {
    _view.dataAPIView.clear();
    _onlyOne.remove('');
    List<String> list;
    try {
      list = List<String>.from(response.result.value['cmd'], growable: false)..sort();
    } catch (e) {
      _resultStream.addError('Parse error: $e');
      return;
    }
    for (var line in list) _view.dataAPIView[line] = null;
    _sendResult();
  }

  void _handleAPIListError(String error) {
    _view.dataAPIView.clear();
    _onlyOne.remove('');
    _resultStream.addError(error);
  }

  void _handleAPIIfo(String method, Response response) {
    _onlyOne.remove(method);
    EntryInfo info;
    try {
      if (response.result.value['cmd'] != method)
        info = EntryInfo('Wrong response: "${response.result.value['cmd']}" != "$method"!', null, isError: true);
      else
        info = EntryInfo.fromJson(response.result.value);
    } catch (e) {
      info = EntryInfo('Parse error: $e', null, isError: true);
    }
    _putInfo(method, info);
  }

  void _handleAPIInfoError(String method, Error error) {
    _onlyOne.remove(method);
    _putInfo(method, EntryInfo('Error: ${error.code}: ${error.message}', null, isError: true));
  }

  void _putInfo(String method, EntryInfo info) {
    if (_view.dataAPIView.containsKey(method) && _view.dataAPIView[method] != info) {
      _view.dataAPIView[method] = info;
      _sendResult();
    }
  }

  void _sendResult([ResultMode mode = ResultMode.ok]) => _resultStream.add(Result(mode, _view.dataAPIView));

  void dispose() {
    _stateStreamSubscription.cancel();
    _methodStream.close();
    _resultStream.close();
  }
}
