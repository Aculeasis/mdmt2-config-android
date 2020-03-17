import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/servers/servers_array.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:mdmt2_config/src/terminal/file_logging.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/terminal/terminal_instance.dart';
import 'package:native_state/native_state.dart';
import 'package:rxdart/rxdart.dart';

part 'package:mdmt2_config/src/blocs/servers_controller.dart';
part 'package:mdmt2_config/src/servers/servers_manager.dart';

class InstancesState {
  int counts = 0, active = 0, closing = 0;
}

class ServersController extends ServersManager {
  final SavedStateData _saved;
  final style = LogStyle()..loadAsBaseStyle();
  final _state = InstancesState();
  final _stateStream = BehaviorSubject<InstancesState>();
  Stream<InstancesState> stateStream;

  ServersController(this._saved) {
    stateStream = _stateStream.throttleTime(MiscSettings().throttleTime, trailing: true);
  }

  _instanceSignalCollector(WorkingNotification event) {
    event.server.notifyListeners();
    if (event.signal == WorkingStatChange.connecting) {
      _state.active++;
    } else if (event.signal == WorkingStatChange.closing) {
      _state.closing++;
    } else if (event.signal == WorkingStatChange.broken) {
      _state.active--;
    } else if (event.signal == WorkingStatChange.close || event.signal == WorkingStatChange.closeOnError) {
      _state.active--;
      _state.closing--;
      if (event.server.inst?.work == false) event.server.inst.reconnect.start();
    } else
      return;
    _sendState();
  }

  void dispose() {
    _stateStream.close();
    _clearAllInput();
    style.dispose();
    _saved.clear();
    super.dispose();
  }

  void _sendState() {
    _stateStream.add(_state);
  }

  void _clearAllInput() {
    for (var server in _array.iterable) _clearInput(server);
  }

  void _stopAllInput() {
    for (var server in _array.iterable) _stopInput(server);
  }

  bool _removeInstance(ServerData server, {bool notify = true}) {
    if (!_stopInput(server)) return false;
    final inst = server.inst;
    server.inst = null;
    _state.counts--;
    inst.dispose();
    if (notify) {
      _sendState();
      server.notifyListeners();
    }
    return true;
  }

  bool _stopInput(ServerData server) {
    if (server.inst == null) return false;
    server.inst.close();
    return true;
  }

  void _clearInput(ServerData server) {
    if (server.inst == null || server.inst.work) return;
    _removeInstance(server);
  }

  void _runInput(ServerData server, {returnServerCallback result}) {
    if (server.inst == null) {
      _makeInstance(server);
      _sendState();
    }
    if (!server.inst.work) server.inst.control.sendRun();
    if (result != null) result(server);
  }

  void _makeInstance(ServerData server, {bool restoreView = false}) {
    assert(server.inst == null);
    final state = MiscSettings().saveAppState.value ? _saved.child('states_${server.sid}') : null;

    final reconnect = Reconnect(() => run(server));
    final view = InstanceViewState(style.clone(), state, restore: restoreView);
    final log = Log(view.style, view.unreadMessages, state, server.sid);
    final control = TerminalControl(server, state, log, view, reconnect, change)
      ..stateStream.listen(_instanceSignalCollector);

    server.inst = TerminalInstance(control, log, view, reconnect);
    _state.counts++;
    server.notifyListeners();
  }

  @override
  _greatResurrector() async {
    await LogsBox().filling();
    if (_array.length == 0 || !MiscSettings().saveAppState.value) {
      LogsBox().dispose();
      await _saved.clear();
      return;
    }

    for (var server in _array.iterable) {
      final states = _saved.child('states_${server.sid}');
      if (states.getBool('flag') == true) {
        debugPrint(' * Restoring ${server.name} = ${server.sid}');
        _makeInstance(server, restoreView: true);
      } else {
        states.clear();
      }
    }
    await LogsBox().dispose();
    _sendState();
  }
}
