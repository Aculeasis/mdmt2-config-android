import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:mdmt2_config/src/terminal/file_logging.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/terminal/terminal_instance.dart';
import 'package:mdmt2_config/src/terminal/terminal_logger.dart';
import 'package:native_state/native_state.dart';
import 'package:rxdart/rxdart.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
      if (event.server.inst?.work == false) event.server.inst?.reconnect?.start();
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
    for (var server in loop) _clearInput(server);
  }

  void _stopAllInput() {
    for (var server in loop) _stopInput(server);
  }

  bool _removeInstance(ServerData server, {bool callDispose = true, bool notify = true}) {
    if (!_stopInput(server)) return false;
    final inst = server.inst;
    server.inst = null;
    final diff = (inst.logger != null ? 1 : 0) + (inst.control != null ? 1 : 0);
    _state.counts -= diff;
    if (callDispose) {
      if (diff > 0 && notify) _sendState();
      inst.dispose();
    }
    if (notify) server.notifyListeners();
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
    if (server.inst != null) {
      if (!(server.control || server.logger)) {
        clear(server);
        return;
      }
      _upgradeInstance(server);
    } else {
      _makeInstance(server);
    }
    _runInstance(server?.inst?.logger);
    _runInstance(server?.inst?.control);

    if (result != null && server.inst != null) result(server);
  }

  void _runInstance(TerminalClient inst) {
    if (inst?.getStage == ConnectStage.wait) {
      inst.sendRun();
    }
  }

  _makeInstance(ServerData server, {TerminalInstance instance, bool restoreView = false}) {
    SavedStateData _getState() => MiscSettings().saveAppState ? _saved.child('states_${server.uuid}') : null;

    instance ??= TerminalInstance(null, null, null, InstanceViewState(style.clone(), _getState(), restore: restoreView),
        Reconnect(() => run(server)));
    int incCounts = 0;
    if (server.logger) {
      instance.log ??= Log(instance.view.style, instance.view.unreadMessages, _getState(), server.uuid);
      if (instance.logger == null) {
        instance.logger = TerminalLogger(server, _getState(), instance.log);
        instance.logger.stateStream.listen(_instanceSignalCollector);
      } else {
        instance.logger.setLog = instance.log;
      }
      incCounts++;
    } else {
      instance.logger?.dispose();
      instance.logger = null;
      instance.log?.dispose();
      instance.log = null;
    }
    if (server.control) {
      if (instance.control == null) {
        instance.control = TerminalControl(server, _getState(), instance.log, instance.view, instance.reconnect);
        instance.control.stateStream.listen(_instanceSignalCollector);
      } else {
        instance.control.setLog = instance.log;
      }
      incCounts++;
    } else {
      instance.control?.dispose();
      instance.control = null;
    }

    assert(server.inst == null);
    assert((instance.logger == null && instance.log == null) || instance.logger != null && instance.log != null);

    if ((instance.logger ?? instance.control) != null) {
      assert(instance.view != null && instance.reconnect != null);
      server.inst = instance;
      _state.counts += incCounts;
      if (incCounts > 0) _sendState();
    } else
      instance.dispose();
    server.notifyListeners();
  }

  void _upgradeInstance(ServerData server) {
    final instance = server.inst;
    instance.reconnect.close();
    if (instance.work) return debugPrint(' ***Still running ${server.name}');
    if (((instance.logger != null) != server.logger || (instance.control != null) != server.control) &&
        _removeInstance(server, callDispose: false, notify: false)) {
      debugPrint(' ***Re-make ${server.name}');
      _makeInstance(server, instance: instance);
    } else
      debugPrint(' ***Nope ${server.name}');
  }

  @override
  _greatResurrector() async {
    await LogsBox().filling();
    final saveAppState = MiscSettings().saveAppState;
    if (length == 0 || !saveAppState) {
      LogsBox().dispose();
      await _saved.clear();
      return;
    }

    for (var server in _servers) {
      final states = _saved.child('states_${server.uuid}');
      if (states.getBool('flag') == true) {
        debugPrint(' * Restoring ${server.name} = ${server.uuid}');
        _makeInstance(server, restoreView: true);
      } else {
        states.clear();
      }
    }
    await LogsBox().dispose();
  }
}
