import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';

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
  final TerminalControl control;
  final Log log;
  final InstanceViewState view;
  final Reconnect reconnect;

  TerminalInstance(this.control, this.log, this.view, this.reconnect);

  void close() {
    reconnect.close();
    control.sendClose();
  }

  void dispose() {
    reconnect.close();
    control.dispose();
    log.dispose();
    view.dispose();
  }

  bool get work => control.getStage != ConnectStage.wait;
  String get subtitle => '[${control.server.uri}] ${control.getStage.toString().split('.').last}';
  bool get hasCriticalError => control.hasCriticalError;
}
