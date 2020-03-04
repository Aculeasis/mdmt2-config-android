import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/misc.dart';

enum ButtonDisplaySignal { fadeIn, hide, fadeOut }
enum MusicStatus { play, pause, stop, nope, error }

class _MainStates {
  // Счетчик + уведомления о изменении сообщений в логе
  final unreadMessages = UnreadMessages(0);
  // Настройки логгера открыты
  final logExpanded = ValueNotifier<bool>(false);
  // Настройки контроллера открыты
  final controlExpanded = ValueNotifier<bool>(false);
  // Открытый таб (логгер или контроллер)
  final pageIndex = ValueNotifier<int>(0);
  // Позиция скрола логгера
  double logScrollPosition = .0;
  // TTS, ask, voice
  String modeTAV = 'TTS';
  String textTAV = 'Hello world!';
  // model
  final modelIndex = ValueNotifier<int>(1);
  final sampleIndex = ValueNotifier<int>(1);
  // Перехват сообщения для сервера (command.php?qry=)
  final catchQryStatus = ValueNotifier<bool>(false);
  // play:uri
  String musicURI = '';
}

class InstanceViewState extends _MainStates {
  static const backIndent = 200;
  static const hideButtonAfter = Duration(seconds: 2);
  static const fadeOutButtonTime = Duration(milliseconds: 600);
  static const fadeInButtonTime = Duration(milliseconds: 200);
  final LogStyle style;

  Timer hideButtonTimer, fadeOutButtonTimer;
  final backButton = ValueNotifier<ButtonDisplaySignal>(ButtonDisplaySignal.hide);

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
  //volume
  final volume = ValueNotifier<int>(-1);
  final musicVolume = ValueNotifier<int>(-1);

  InstanceViewState(this.style);

  void reset() {
    for (var btn in buttons.values) btn.reset();
    unreadMessages.reset();
  }

  void dispose() {
    _stopAnimation();
    for (var btn in buttons.values) btn.dispose();
    style.dispose();
    unreadMessages.reset();
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
