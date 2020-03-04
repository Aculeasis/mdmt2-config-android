import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/utils.dart';

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
