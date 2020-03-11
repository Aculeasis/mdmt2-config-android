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
  final bool isEnabled;
  final bool isControlled;
  final bool work;
  String subtitle = '';
  int errors = 0, counts = 0, works = 0;
  bool isPartialLogger = false, isPartialControl = false;

  CollectActualServerState(ServerData server)
      : isEnabled = server.logger || server.control,
        isControlled = server.inst != null,
        work = server.inst?.work == true {
    if (!isControlled) return;
    String loggerStr = 'disabled', controlStr = 'disabled';

    if (server.inst.logger != null) {
      _filler(server.inst.logger, server.inst.loggerWork, server.logger);
      loggerStr = _getStageStr(server.inst.logger);
    }
    if (server.inst.control != null) {
      _filler(server.inst.control, server.inst.controlWork, server.control);
      controlStr = _getStageStr(server.inst.control);
    }
    assert(!(isPartialControl && isPartialLogger));

    final all = errors == 0 ? 'Ok' : errors == counts ? 'Error' : 'Partial';
    subtitle = '[${server.uri}] $all ($works/$counts).\n'
        'Log: $loggerStr. '
        'Control: $controlStr.';
  }

  void _filler(TerminalClient target, bool isWork, bool enabled) {
    final isPartial = work && !isWork && enabled;
    counts++;
    if (target.hasCriticalError) errors++;
    if (isWork) works++;
    if (target.mode == WorkingMode.logger) {
      isPartialLogger = isPartial;
    } else if (target.mode == WorkingMode.controller) {
      isPartialControl = isPartial;
    }
  }

  String _getStageStr(TerminalClient target) => target.hasCriticalError && target.getStage == ConnectStage.wait
      ? 'error'
      : target.getStage.toString().split('.').last;
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
    final delay = MiscSettings().autoReconnectAfterReboot.value;
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
  final InstanceViewState view;
  final Reconnect reconnect;

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
    view.dispose();
  }

  bool get loggerWait => logger?.getStage == ConnectStage.wait;
  bool get controlWait => control?.getStage == ConnectStage.wait;
  bool get loggerWork => logger != null && logger.getStage != ConnectStage.wait;
  bool get controlWork => control != null && control.getStage != ConnectStage.wait;
  bool get work => loggerWork || controlWork;
}
