import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:native_state/native_state.dart';

enum ButtonDisplaySignal { fadeIn, hide, fadeOut }
enum MusicStatus { play, pause, stop, nope, error }

class _N {
  static const unreadMessages = '1';
  static const logExpanded = '2';
  static const controlExpanded = '3';
  static const pageIndex = '4';
  static const logScrollPosition = '5';
  static const modeTAV = '6';
  static const textTAV = '7';
  static const modelIndex = '8';
  static const sampleIndex = '9';
  static const catchQryStatus = '10';
  static const musicURI = '11';
  static const style = '12';
}

class _MainStates {
  final _removeListeners = <Function>[];
  final SavedStateData _saved;
  final LogStyle style;
  // Счетчик + уведомления о изменении сообщений в логе
  final unreadMessages = UnreadMessages(0);
  // Настройки логгера открыты
  final logExpanded = ValueNotifier<bool>(false);
  // Настройки контроллера открыты
  final controlExpanded = ValueNotifier<bool>(false);
  // Открытый таб (логгер или контроллер)
  final pageIndex = ValueNotifier<int>(0);
  // model
  final modelIndex = ValueNotifier<int>(1);
  final sampleIndex = ValueNotifier<int>(1);
  // Перехват сообщения для сервера (command.php?qry=)
  final catchQryStatus = ValueNotifier<bool>(false);
  // Позиция скрола логгера
  double _logScrollPosition = .0;
  double get logScrollPosition => _logScrollPosition;
  set logScrollPosition(double value) {
    _logScrollPosition = value;
    _saved?.putDouble(_N.logScrollPosition, value);
  }

  // TTS, ask, voice
  String _modeTAV = 'TTS';
  String get modeTAV => _modeTAV;
  set modeTAV(String value) {
    _modeTAV = value;
    _saved?.putString(_N.modeTAV, value);
  }

  String _textTAV = 'Hello world!';
  String get textTAV => _textTAV;
  set textTAV(String value) {
    _textTAV = value;
    _saved?.putString(_N.textTAV, value);
  }

  // play:uri
  String _musicURI = '';
  String get musicURI => _musicURI;
  set musicURI(String value) {
    _musicURI = value;
    _saved?.putString(_N.musicURI, value);
  }

  _addListeners() {
    _saved.putBool('flag', true);

    final cb1 = () => _saved.putInt(_N.unreadMessages, unreadMessages.value);
    unreadMessages.addListener(cb1);
    _removeListeners.add(() => unreadMessages.removeListener(cb1));

    final cb2 = () => _saved.putBool(_N.logExpanded, logExpanded.value);
    logExpanded.addListener(cb2);
    _removeListeners.add(() => logExpanded.removeListener(cb2));

    final cb3 = () => _saved.putBool(_N.controlExpanded, controlExpanded.value);
    controlExpanded.addListener(cb3);
    _removeListeners.add(() => controlExpanded.removeListener(cb3));

    final cb4 = () => _saved.putInt(_N.pageIndex, pageIndex.value);
    pageIndex.addListener(cb4);
    _removeListeners.add(() => pageIndex.removeListener(cb4));

    final cb5 = () => _saved.putInt(_N.modelIndex, modelIndex.value);
    modelIndex.addListener(cb5);
    _removeListeners.add(() => modelIndex.removeListener(cb5));

    final cb6 = () => _saved.putInt(_N.sampleIndex, sampleIndex.value);
    sampleIndex.addListener(cb6);
    _removeListeners.add(() => sampleIndex.removeListener(cb6));

    final cb7 = () => _saved.putBool(_N.catchQryStatus, catchQryStatus.value);
    catchQryStatus.addListener(cb7);
    _removeListeners.add(() => catchQryStatus.removeListener(cb7));

    final cb8 = () => _saved.putString(_N.style, jsonEncode(style));
    style.addListener(cb8);
    _removeListeners.add(() => style.removeListener(cb8));
  }

  _restore() {
    unreadMessages.value = _saved.getInt(_N.unreadMessages) ?? unreadMessages.value;
    logExpanded.value = _saved.getBool(_N.logExpanded) ?? logExpanded.value;
    controlExpanded.value = _saved.getBool(_N.controlExpanded) ?? controlExpanded.value;
    pageIndex.value = _saved.getInt(_N.pageIndex) ?? pageIndex.value;
    modelIndex.value = _saved.getInt(_N.modelIndex) ?? modelIndex.value;
    sampleIndex.value = _saved.getInt(_N.sampleIndex) ?? sampleIndex.value;
    catchQryStatus.value = _saved.getBool(_N.catchQryStatus) ?? catchQryStatus.value;
    style.upgradeFromJson(_saved.getString(_N.style));

    _logScrollPosition = _saved.getDouble(_N.logScrollPosition) ?? _logScrollPosition;
    _modeTAV = _saved.getString(_N.modeTAV) ?? _modeTAV;
    _textTAV = _saved.getString(_N.textTAV) ?? _textTAV;
    _musicURI = _saved.getString(_N.musicURI) ?? _musicURI;
  }

  _MainStates(this.style, this._saved, bool restore) {
    if (_saved != null) {
      if (restore) _restore();
      _addListeners();
    }
  }

  void dispose() {
    // Думаю можно не разрушать пулы подписчиков а просто всех отписать
    unreadMessages.reset();
    for (var remove in _removeListeners) remove();
    _removeListeners.clear();
    _saved?.clear();
    debugPrint('DISPOSE VIEW');
  }
}

class InstanceViewState extends _MainStates {
  static const backIndent = 200;
  static const hideButtonAfter = Duration(seconds: 2);
  static const fadeOutButtonTime = Duration(milliseconds: 600);
  static const fadeInButtonTime = Duration(milliseconds: 200);

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

  InstanceViewState(style, state, {restore = false}) : super(style, state, restore);

  void reset() {
    for (var btn in buttons.values) btn.reset();
  }

  void dispose() {
    _stopAnimation();
    reset();
    super.dispose();
    assert(() {
      Timer(Duration(seconds: 2), () {
        for (var btn in buttons.values) assert(!btn.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!unreadMessages.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!backButton.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!listenerOnOff.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!musicStatus.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!volume.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!musicVolume.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!style.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!logExpanded.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!controlExpanded.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!pageIndex.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!modelIndex.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!sampleIndex.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!catchQryStatus.hasListeners); // ignore: invalid_use_of_protected_member
        debugPrint('InstanceViewState ---- OK!');
      });
      return true;
    }());
  }

  void scrollBack(ScrollController sc) =>
      sc.animateTo(sc.position.minScrollExtent, duration: Duration(milliseconds: 200), curve: Curves.easeOut);

  void scrollCallback(ScrollController sc) {
    if (!sc.hasClients || logScrollPosition == sc.offset) return;
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
