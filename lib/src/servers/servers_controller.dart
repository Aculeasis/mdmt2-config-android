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
  final _startStopChange = StreamController<WorkingNotification>.broadcast();
  final _stateStream = BehaviorSubject<InstancesState>();
  Stream<InstancesState> stateStream;

  ServersController(this._saved) {
    stateStream = _stateStream.throttleTime(MiscSettings().throttleTime, trailing: true);
    _startStopChange.stream.listen((event) {
      event.server.notifyListeners();
      if (event.signal == WorkingStatChange.connecting)
        _state.active++;
      else if (event.signal == WorkingStatChange.closing)
        _state.closing++;
      else if (event.signal == WorkingStatChange.disconnected ||
          event.signal == WorkingStatChange.disconnectedOnError) {
        _state.active--;
        _state.closing--;
        if (event.server.inst?.work == false) event.server.inst?.reconnect?.start();
      } else
        return;
      _sendState();
    });
  }

  void dispose() {
    _startStopChange.close();
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
    if (!_stopInput(server) || server.inst.lock > 0) return false;
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
    if (server.inst != null)
      _upgradeInstance(server);
    else
      _makeInstance(server);
    _runInstance(server?.inst?.logger);
    _runInstance(server?.inst?.control);

    if (result != null && server.inst != null) result(server);
  }

  void _runInstance(TerminalClient inst) {
    if (inst?.getStage == ConnectStage.wait) {
      inst.sendRun();
    }
  }

  _makeInstance(ServerData server, {TerminalInstance instance, bool restoreView = false, bool restoreLog = false}) {
    SavedStateData _getLogState() {
      final _child = _saved.child('log_${server.uuid}');
      _child.putString('name', server.uuid);
      return _child;
    }

    final toSave = MiscSettings().saveAppState;
    instance ??= TerminalInstance(
        null,
        null,
        null,
        InstanceViewState(style.clone(), toSave ? _saved.child('view_${server.uuid}') : null,
            restore: restoreView),
        Reconnect(() => run(server)));
    int incCounts = 0;
    if (server.logger) {
      instance.log ??=
          Log(instance.view.style, instance.view.unreadMessages, toSave ? _getLogState() : null, restoreLog);
      if (instance.logger == null)
        instance.logger = TerminalLogger(server, _startStopChange, instance.log);
      else
        instance.logger.setLog = instance.log;
      incCounts++;
    } else {
      instance.logger?.dispose();
      instance.logger = null;
      instance.log?.dispose();
      instance.log = null;
    }
    if (server.control) {
      if (instance.control == null)
        instance.control = TerminalControl(server, _startStopChange, instance.log, instance.view, instance.reconnect);
      else
        instance.control.setLog = instance.log;
      incCounts++;
    } else {
      instance.control?.dispose();
      instance.control = null;
    }

    if ((instance.logger ?? instance.control) != null) {
      server.inst = instance;
      server.notifyListeners();
      _state.counts += incCounts;
      if (incCounts > 0) _sendState();
    } else
      instance.dispose();
  }

  void _upgradeInstance(ServerData server) {
    final instance = server.inst;
    instance.reconnect.close();
    if (instance.work) return debugPrint(' ***Still running ${server.name}');
    if (((instance.logger != null) != server.logger || (instance.control != null) != server.control) &&
        _removeInstance(server, callDispose: false)) {
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
      final viewChild = _saved.child('view_${server.uuid}');
      if (viewChild.getBool('flag') == true) {
        debugPrint(' * Restoring ${server.name} = ${server.uuid}');
        final logChild = _saved.child('log_${server.uuid}');
        bool restoreLog = false;
        if (logChild.getBool('flag') == true) {
          restoreLog = true;
        } else {
          logChild.clear();
        }
        _makeInstance(server, restoreView: true, restoreLog: restoreLog);
      } else {
        viewChild.clear();
      }
    }
    await LogsBox().dispose();
  }
}
