import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/terminal/terminal_logger.dart';
import 'package:mdmt2_config/src/utils.dart';

part 'package:mdmt2_config/src/blocs/instances_controller.dart';

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

  CollectActualServerState(ServerData server, TerminalInstance terminal) {
    isEnabled = server.logger || server.control;
    isControlled = terminal != null;
    if (!isControlled) return;
    String loggerStr = 'disabled', controlStr = loggerStr;
    work = terminal.work;
    if (terminal.logger != null) {
      counts++;
      if (terminal.logger.hasCriticalError) errors++;
      if (terminal.loggerWork) works++;
      loggerStr = terminal.logger.getStage == ConnectStage.logger
          ? 'work'
          : terminal.logger.getStage.toString().split('.').last;
      isPartialLogger = work && !terminal.loggerWork && server.logger;
    }
    if (terminal.control != null) {
      counts++;
      if (terminal.control.hasCriticalError) errors++;
      if (terminal.controlWork) works++;
      controlStr = terminal.control.getStage == ConnectStage.controller
          ? 'work'
          : terminal.control.getStage.toString().split('.').last;
      isPartialControl = work && !terminal.controlWork && server.control;
    }
    assert(!(isPartialControl && isPartialLogger));

    final all = errors == 0 ? 'Ok' : errors == counts ? 'Error' : 'Partial';
    subtitle = '[${server.uri}] $all ($works/$counts).\n'
        'Log: $loggerStr. '
        'Control: $controlStr.';
  }
}

enum ButtonDisplaySignal { fadeIn, hide, fadeOut }
enum MusicStatus { play, pause, stop, nope, error }

class InstanceViewState {
  static const backIndent = 200;
  static const hideButtonAfter = Duration(seconds: 2);
  static const fadeOutButtonTime = Duration(milliseconds: 600);
  static const fadeInButtonTime = Duration(milliseconds: 200);
  Timer hideButtonTimer, fadeOutButtonTimer;
  final backButton = ValueNotifier<ButtonDisplaySignal>(ButtonDisplaySignal.hide);

  double logScrollPosition = .0;

  final LogStyle style;

  final logExpanded = ValueNotifier<bool>(false);
  final controlExpanded = ValueNotifier<bool>(false);
  final pageIndex = ValueNotifier<int>(0);

  // TTS, ask, voice
  String modeTAV = 'TTS';
  String textTAV = 'Hello world!';

  // model
  final modelIndex = ValueNotifier<int>(1);
  final sampleIndex = ValueNotifier<int>(1);

  //listener OnOff
  final listenerOnOff = ValueNotifier<bool>(false);

  final buttons = {
    'talking': ResettableBoolNotifier(Duration(seconds: 60)),
    'record': ResettableBoolNotifier(Duration(seconds: 30)),
    'manual_backup': ResettableBoolNotifier(Duration(seconds: 20)),
    'model_compile': ResettableBoolNotifier(Duration(seconds: 60)),
    'sample_record': ResettableBoolNotifier(Duration(seconds: 30)),
    'terminal_stop': ResettableBoolNotifier(Duration(seconds: 90)),
  };

  final musicStatus = ValueNotifier<MusicStatus>(MusicStatus.error);
  // Перехват сообщения для сервера (command.php?qry=)
  final catchQryStatus = ValueNotifier<bool>(false);

  //volume
  final volume = ValueNotifier<int>(-1);
  final musicVolume = ValueNotifier<int>(-1);

  // play:uri
  String musicURI = '';

  InstanceViewState(this.style);

  void reset() {
    for (var btn in buttons.values) btn.reset();
  }

  void dispose() {
    _stopAnimation();
    for (var btn in buttons.values) btn.dispose();
    style.dispose();
  }

  void scrollBack(ScrollController sc) =>
      sc.animateTo(sc.position.minScrollExtent, duration: Duration(milliseconds: 200), curve: Curves.easeOut);

  void scrollCallback(ScrollController sc) {
    if (logScrollPosition == sc.offset) return;
    logScrollPosition = sc.offset;
    final isVisible = sc.offset > backIndent && sc.position.maxScrollExtent - sc.offset > backIndent;
    if (isVisible) {
      _stopAnimation();
      hideButtonTimer = Timer(hideButtonAfter, () {
        backButton.value = ButtonDisplaySignal.fadeOut;
        fadeOutButtonTimer = Timer(fadeOutButtonTime, () => backButton.value = ButtonDisplaySignal.hide);
      });
    } else if (backButton.value == ButtonDisplaySignal.fadeOut) {
      _stopAnimation();
      fadeOutButtonTimer = Timer(fadeOutButtonTime, () => backButton.value = ButtonDisplaySignal.hide);
    }
    backButton.value = isVisible ? ButtonDisplaySignal.fadeIn : ButtonDisplaySignal.fadeOut;
  }

  _stopAnimation() {
    fadeOutButtonTimer?.cancel();
    hideButtonTimer?.cancel();
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

  bool get loggerWork => logger != null && logger.getStage != ConnectStage.wait;
  bool get controlWork => control != null && control.getStage != ConnectStage.wait;
  bool get work => loggerWork || controlWork;
}

class InstancesState {
  int counts = 0, active = 0, closing = 0;
}

class InstancesController extends _BLoC {
  final style = LogStyle()..loadAll();
  final _state = InstancesState();
  final _instances = <ServerData, TerminalInstance>{};
  final StreamController<WorkingNotification> _startStopChange = StreamController<WorkingNotification>.broadcast();
  final StreamController<InstancesState> _stateStream = StreamController<InstancesState>.broadcast();

  InstancesController() {
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
        if (_instances[event.server]?.work == false) _instances[event.server]?.reconnect?.start();
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

  TerminalInstance operator [](ServerData s) => _instances[s];
  bool contains(ServerData server) => _instances.containsKey(server);
  Stream<InstancesState> get stateStream => _stateStream.stream;

  void _clearAllInput() {
    for (var server in _instances.keys.toList()) _clearInput(server);
  }

  void _stopAllInput() {
    for (var server in _instances.keys) _stopInput(server);
  }

  bool _removeInput(ServerData server, {bool callDispose = true}) {
    if (!_stopInput(server)) return false;
    final inst = _instances.remove(server);
    final diff = (inst.logger != null ? 1 : 0) + (inst.control != null ? 1 : 0);
    _state.counts -= diff;
    if (callDispose) {
      if (diff > 0) _sendState();
      inst.dispose();
    }
    server.states.notifyListeners();
    return true;
  }

  bool _stopInput(ServerData server) {
    if (!_instances.containsKey(server)) return false;
    _instances[server].close();
    return true;
  }

  void _clearInput(ServerData server) {
    if (!_instances.containsKey(server) || _instances[server].work) return;
    _removeInput(server);
  }

  void _runInput(ServerData server, {returnInstanceCallback result}) {
    if (_instances.containsKey(server))
      _upgradeInstance(server);
    else
      _makeInstance(server);
    final instance = _instances[server];
    _runInstance(instance?.logger);
    _runInstance(instance?.control);

    if (result != null && instance != null) result(instance);
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
      _instances[server] = instance;
      server.states.notifyListeners();
      _state.counts += incCounts;
      if (incCounts > 0) _sendState();
      server.states.notifyListeners();
    } else
      instance.dispose();
  }

  void _upgradeInstance(ServerData server) {
    final instance = _instances[server];
    instance.reconnect.close();
    if (instance.work) return debugPrint(' ***Still running ${server.name}');
    if (((instance.logger != null) != server.logger || (instance.control != null) != server.control) &&
        _removeInput(server, callDispose: false)) {
      debugPrint(' ***Re-make ${server.name}');
      _makeInstance(server, instance: instance);
    } else
      debugPrint(' ***Nope ${server.name}');
  }
}

typedef returnInstanceCallback = void Function(TerminalInstance instance);
