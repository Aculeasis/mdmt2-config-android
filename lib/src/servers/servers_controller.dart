import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/terminal/terminal_instance.dart';
import 'package:mdmt2_config/src/terminal/terminal_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'package:mdmt2_config/src/blocs/servers_controller.dart';
part 'package:mdmt2_config/src/servers/servers_manager.dart';

class InstancesState {
  int counts = 0, active = 0, closing = 0;
}

class ServersController extends ServersManager {
  final style = LogStyle()..loadAll();
  final _state = InstancesState();
  final StreamController<WorkingNotification> _startStopChange = StreamController<WorkingNotification>.broadcast();
  final StreamController<InstancesState> _stateStream = StreamController<InstancesState>.broadcast();

  ServersController() {
    _startStopChange.stream.listen((event) {
      event.server.states.notifyListeners();
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
    super.dispose();
  }

  void _sendState() {
    _stateStream.add(_state);
  }

  Stream<InstancesState> get stateStream => _stateStream.stream;

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
    if (notify) server.states.notifyListeners();
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

  _makeInstance(ServerData server, {TerminalInstance instance}) {
    instance ??= TerminalInstance(null, null, null, InstanceViewState(style.clone()), Reconnect(() => run(server)));
    int incCounts = 0;
    if (server.logger) {
      instance.log ??= Log(instance.view.style, server.states);
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
      server.states.notifyListeners();
      _state.counts += incCounts;
      if (incCounts > 0) _sendState();
      server.states.notifyListeners();
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
}
