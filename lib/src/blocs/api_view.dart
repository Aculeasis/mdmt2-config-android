import 'dart:async';

import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';

enum ResultMode { ok, await, refresh }

class Result {
  final ResultMode mode;
  final Map<String, EntryInfo> data;
  Result(this.mode, this.data);
}

enum _Actions { start, refresh }

class _CMD {
  final _Actions action;
  final String method;
  _CMD({this.method, this.action});
}

class ApiViewBLoC {
  static const timeLimit = Duration(seconds: 10);
  static const mInfo = 'info';
  final TerminalControl _control;
  final InstanceViewState _view;
  final _methodStream = StreamController<_CMD>();
  final _resultStream = StreamController<Result>();
  final _onlyOne = <String>{};
  ResultMode _mode = ResultMode.ok;
  StreamSubscription<WorkingNotification> _stateStreamSubscription;
  bool _isConnected;

  ApiViewBLoC(this._control, this._view) : _isConnected = _control.getStage == ConnectStage.work {
    _methodStream.stream.listen((cmd) {
      if (cmd.action != null) {
        switch (cmd.action) {
          case _Actions.refresh:
            _sendResult(mode: ResultMode.refresh);
            break;
          case _Actions.start:
            if (_view.apiViewState.data.isEmpty) {
              getAPIList();
            } else {
              _view.apiViewState.removeEmptyTiles();
              _sendResult();
            }
            break;
        }
      }
      final api = cmd.method;
      if (!_isConnected || api == null || _onlyOne.contains(api)) return;

      if (api.isEmpty) {
        _mode = ResultMode.await;
        _onlyOne
          ..clear()
          ..add(api);
        _sendResult();
        _control.callJRPCExternal(mInfo,
            handler: AsyncResponseHandler(
                (_, response) => _handleAPIList(response: response), (_, error) => _handleAPIList(error: error)),
            timeout: timeLimit);
      } else {
        _onlyOne.add(api);
        _control.callJRPCExternal(mInfo,
            params: [api],
            handler: AsyncResponseHandler((_, response) => _handleAPIIfo(api, response: response),
                (_, error) => _handleAPIIfo(api, error: error)),
            timeout: timeLimit);
      }
    });

    _stateStreamSubscription = _control.stateStream.listen((event) {
      if (!_isConnected && _control.getStage == ConnectStage.work) {
        _isConnected = true;
      } else if (_isConnected && _control.getStage != ConnectStage.work) {
        _mode = ResultMode.ok;
        _isConnected = false;
        _onlyOne.clear();
      }
    });
  }

  Stream<Result> get result => _resultStream.stream;
  void getAPIList() => _methodStream.add(_CMD(method: ''));
  void getAPIInfo(String api) => _methodStream.add(_CMD(method: api));
  void start() => _methodStream.add(_CMD(action: _Actions.start));
  void refresh() => _methodStream.add(_CMD(action: _Actions.refresh));

  void _handleAPIList({Response response, Error error}) {
    assert(_testResponse(response, error));
    if (_resultStream.isClosed) return;
    _onlyOne.remove('');
    _mode = ResultMode.ok;
    List<String> list;
    if (error != null) {
      _resultStream.addError('Error: ${error.code}: ${error.message}');
      list = List(0);
    } else {
      try {
        list = List<String>.from(response.result.value['cmd'], growable: false)..sort();
      } catch (e) {
        _resultStream.addError('Parse error: $e');
        list = List(0);
      }
    }
    _view.apiViewState.makeFromList(list);
    if (_view.apiViewState.data.isNotEmpty) _sendResult();
  }

  void _handleAPIIfo(String method, {Response response, Error error}) {
    assert(_testResponse(response, error));
    if (_resultStream.isClosed) return;
    _onlyOne.remove(method);
    EntryInfo info;
    if (error != null) {
      info = EntryInfo('Error: ${error.code}: ${error.message}', null, isError: true);
    } else {
      try {
        if (response.result.value['cmd'] != method)
          info = EntryInfo('Wrong response: "${response.result.value['cmd']}" != "$method"!', null, isError: true);
        else
          info = EntryInfo.fromJson(response.result.value);
      } catch (e) {
        info = EntryInfo('Parse error: $e', null, isError: true);
      }
    }
    _putInfo(method, info);
  }

  static bool _testResponse(Response a, Error b) => (a != null && b == null) || (a == null && b != null);

  void _putInfo(String method, EntryInfo info) {
    if (_view.apiViewState.putInfo(method, info)) _sendResult();
  }

  void _sendResult({ResultMode mode}) => _resultStream.add(Result(mode ?? _mode, _view.apiViewState.data));

  void dispose() {
    _stateStreamSubscription.cancel();
    _methodStream.close();
    _resultStream.close();
  }
}
