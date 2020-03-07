import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/terminal/terminal_logger.dart';

class CollectActualServerState {
  String subtitle = '';
  int errors = 0;
  int counts = 0;
  int works = 0;
  bool isControlled = false;
  bool work = false;
  bool isEnabled = false;
  bool isPartialLogger = false;
  bool isPartialControl = false;

  CollectActualServerState(ServerData server) {
    isEnabled = server.logger || server.control;
    isControlled = server.inst != null;
    if (!isControlled) return;

    String loggerStr = 'disabled', controlStr = loggerStr;
    work = server.inst.work;
    if (server.inst.logger != null) {
      counts++;
      if (server.inst.logger.hasCriticalError) errors++;
      if (server.inst.loggerWork) works++;
      loggerStr = server.inst.logger.getStage == ConnectStage.logger
          ? 'work'
          : server.inst.logger.getStage.toString().split('.').last;
      isPartialLogger = work && !server.inst.loggerWork && server.logger;
    }
    if (server.inst.control != null) {
      counts++;
      if (server.inst.control.hasCriticalError) errors++;
      if (server.inst.controlWork) works++;
      controlStr = server.inst.control.getStage == ConnectStage.controller
          ? 'work'
          : server.inst.control.getStage.toString().split('.').last;
      isPartialControl = work && !server.inst.controlWork && server.control;
    }
    assert(!(isPartialControl && isPartialLogger));

    final all = errors == 0 ? 'Ok' : errors == counts ? 'Error' : 'Partial';
    subtitle = '[${server.uri}] $all ($works/$counts).\n'
        'Log: $loggerStr. '
        'Control: $controlStr.';
  }
}

class Reconnect {
  final isActive = ValueNotifier<bool>(false);
  Duration _duration;
  Timer _timer;
  final Function() callback;
  Reconnect(this.callback);

  void close() {
    isActive.value = false;
    _timer?.cancel();
  }

  bool get isRun => _timer != null;

  void activate() {
    _timer?.cancel();
    _duration = null;
    final delay = MiscSettings().autoReconnectAfterReboot;
    if (callback != null && delay > 0) {
      debugPrint('RECONNECT activate');
      _duration = Duration(seconds: delay);
      isActive.value = true;
    }
  }

  void start() {
    if (_duration != null) {
      debugPrint('RECONNECT start');
      _timer = Timer(_duration, _onActivate);
      _duration = null;
    }
  }

  _onActivate() {
    debugPrint('RECONNECT complit');
    isActive.value = false;
    _timer = null;
    callback();
  }
}

class TerminalInstance {
  TerminalLogger logger;
  TerminalControl control;
  Log log;
  InstanceViewState view;
  Reconnect reconnect;

  TerminalInstance(this.logger, this.control, this.log, this.view, this.reconnect);

  void close() {
    reconnect.close();
    logger?.sendClose();
    control?.sendClose();
  }

  void dispose() {
    reconnect.close();
    logger?.dispose();
    control?.dispose();
    log?.dispose();
    view?.dispose();
  }

  bool get loggerWait => logger?.getStage == ConnectStage.wait;
  bool get controlWait => control?.getStage == ConnectStage.wait;
  bool get loggerWork => logger != null && logger.getStage != ConnectStage.wait;
  bool get controlWork => control != null && control.getStage != ConnectStage.wait;
  bool get work => loggerWork || controlWork;
}
