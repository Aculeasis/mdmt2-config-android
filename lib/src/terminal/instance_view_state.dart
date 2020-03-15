import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:native_state/native_state.dart';

enum ButtonDisplaySignal { fadeIn, hide, fadeOut }
enum MusicStatus { play, pause, stop, nope, error }

class _N {
  static const unreadMessages = '1';
  static const style = '2';
}

class EntryInfo {
  final String msg;
  final List<String> flags;
  final bool isError;
  EntryInfo(String msg, List<String> flags, {this.isError = false})
      : this.msg = msg ?? 'Empty',
        this.flags = flags ?? List(0);
  @override
  bool operator ==(other) => other is EntryInfo && msg == other.msg && flags == other.flags && isError == other.isError;
  @override
  int get hashCode => '${msg.hashCode}${flags.hashCode}$isError'.hashCode;

  EntryInfo.fromJson(Map<String, dynamic> json)
      : msg = json['msg'] != null ? (json['msg'] as String).split('\n').map((e) => e.trim()).join('\n') : 'Empty',
        flags = json['flags'] != null ? List<String>.from(json['flags'], growable: false) : List(0),
        isError = false;
}

class APIViewState {
  // Кэш ответов на info:...
  final data = <String, EntryInfo>{};
  // Открыты\закрыты
  final _tilesStates = <String, ValueNotifier<bool>>{};
  double logScrollPosition = .0;

  void makeFromList(List<String> list) {
    data.clear();
    _tilesStates.clear();
    for (var entry in list) data[entry] = null;
  }

  void removeEmptyTiles() => _tilesStates.keys
      .where((element) => data[element] == null)
      .toList(growable: false)
      .forEach((element) => _tilesStates.remove(element));

  bool putInfo(String method, EntryInfo info) {
    if (data.containsKey(method) && data[method] != info) {
      data[method] = info;
      return true;
    }
    return false;
  }

  void setTileState(String method, bool state) => getTileNotify(method, state).value = state;
  ValueNotifier<bool> getTileNotify(String method, [state = false]) =>
      (_tilesStates[method] = _tilesStates[method] ?? ValueNotifier<bool>(state));
}

class _MainStates {
  final _removeListeners = <Function>[];
  final SavedStateData _saved;
  // Стиль инста
  final LogStyle style;
  // Счетчик + уведомления о изменении сообщений в логе
  final unreadMessages = UnreadMessages(0);

  final Map<String, ValueNotifier> states = {
    // Настройки логгера открыты
    'logExpanded': ValueNotifier<bool>(false),
    // Настройки контроллера открыты
    'controlExpanded': ValueNotifier<bool>(false),
    // Открытый таб (логгер или контроллер)
    'pageIndex': ValueNotifier<int>(0),
    // model
    'modelIndex': ValueNotifier<int>(1),
    'sampleIndex': ValueNotifier<int>(1),
    // Перехват сообщения для сервера (command.php?qry=)
    'catchQryStatus': ValueNotifier<bool>(false),
    // Позиция скрола логгера
    'logScrollPosition': ValueNotifier<double>(.0),
    // TTS, ask, voice
    'modeTAV': ValueNotifier<String>('TTS'),
    'textTAV': ValueNotifier<String>('Hello world!'),
    // play:uri
    'musicURI': ValueNotifier<String>(''),
  };

  _addListener(String key, ValueNotifier notifier) {
    Function cb = () => null;
    if (notifier is LogStyle) {
      cb = () => _saved?.putString(key, jsonEncode(notifier));
    } else if (notifier is ValueNotifier<String>) {
      cb = () => _saved?.putString(key, notifier.value);
    } else if (notifier is ValueNotifier<int>) {
      cb = () => _saved?.putInt(key, notifier.value);
    } else if (notifier is ValueNotifier<bool>) {
      cb = () => _saved?.putBool(key, notifier.value);
    } else if (notifier is ValueNotifier<double>) {
      cb = () => _saved?.putDouble(key, notifier.value);
    } else {
      assert(() {
        throw 'FIXME! Unknown type of key "$key"';
      }());
    }
    notifier.addListener(cb);
    _removeListeners.add(() => notifier.removeListener(cb));
  }

  _restoreNotifier(String key, ValueNotifier notifier) {
    if (notifier is LogStyle) {
      notifier.upgradeFromJson(_saved.getString(key));
    } else if (notifier is ValueNotifier<String>) {
      notifier.value = _saved.getString(key) ?? notifier.value;
    } else if (notifier is ValueNotifier<int>) {
      notifier.value = _saved.getInt(key) ?? notifier.value;
    } else if (notifier is ValueNotifier<bool>) {
      notifier.value = _saved.getBool(key) ?? notifier.value;
    } else if (notifier is ValueNotifier<double>) {
      notifier.value = _saved.getDouble(key) ?? notifier.value;
    } else {
      assert(() {
        throw 'FIXME! Unknown type of key "$key"';
      }());
    }
  }

  _addListeners() {
    _saved.putBool('flag', true);
    _addListener(_N.style, style);
    _addListener(_N.unreadMessages, unreadMessages);
    states.forEach((key, value) => _addListener(key, value));
  }

  _restore() {
    _restoreNotifier(_N.style, style);
    _restoreNotifier(_N.unreadMessages, unreadMessages);
    states.forEach((key, value) => _restoreNotifier(key, value));
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

  final apiViewState = APIViewState();

  InstanceViewState(style, state, {restore = false}) : super(style, state, restore);

  void reset() {
    for (var btn in buttons.values) btn.reset();
    listenerOnOff.value = false;
    volume.value = -1;
    musicVolume.value = -1;
    musicStatus.value = MusicStatus.error;
  }

  void dispose() {
    _stopAnimation();
    reset();
    super.dispose();
    assert(() {
      Timer(Duration(seconds: 2), () {
        for (var btn in buttons.values) assert(!btn.hasListeners); // ignore: invalid_use_of_protected_member
        for (var state in states.values) assert(!state.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!unreadMessages.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!backButton.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!listenerOnOff.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!musicStatus.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!volume.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!musicVolume.hasListeners); // ignore: invalid_use_of_protected_member
        assert(!style.hasListeners); // ignore: invalid_use_of_protected_member
        debugPrint('InstanceViewState ---- OK!');
      });
      return true;
    }());
  }

  void scrollBack(ScrollController sc) =>
      sc.animateTo(sc.position.minScrollExtent, duration: Duration(milliseconds: 200), curve: Curves.easeOut);

  void scrollCallback(ScrollController sc) {
    if (!sc.hasClients || states['logScrollPosition'].value == sc.offset) return;
    states['logScrollPosition'].value = sc.offset;
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
