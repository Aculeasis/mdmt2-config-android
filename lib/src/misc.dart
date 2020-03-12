import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';

const DummyWidget = const SizedBox();

class _ValueNotifier<T> extends ValueNotifier<T> {
  _ValueNotifier(T value) : super(value);

  @override
  void notifyListeners() => super.notifyListeners();
}

class ThrottledValueNotifier<T> extends _ValueNotifier<T> {
  final Duration interval;
  bool _forceNotify = false;
  Timer _timer;
  T _value;

  ThrottledValueNotifier(T value, {Duration interval})
      : this.interval = interval ?? MiscSettings().throttleTime,
        this._value = value,
        super(value);

  void _runTimer() {
    if (_timer == null) {
      _timer = Timer(interval, () {
        _timer = null;
        if (_value != super.value) {
          _forceNotify = false;
          super.value = _value;
        } else if (_forceNotify) {
          _forceNotify = false;
          super.notifyListeners();
        }
      });
    }
  }

  @override
  void dispose() {
    reset();
    super.dispose();
  }

  void reset() {
    _timer?.cancel();
    _timer = null;
    _forceNotify = false;
    _value = super.value;
  }

  @override
  set value(T newValue) {
    if (newValue != _value) {
      _value = newValue;
      _runTimer();
    }
  }

  @override
  T get value => _value;

  @override
  void notifyListeners() {
    _forceNotify = true;
    _runTimer();
  }
}

class UnreadMessages extends ThrottledValueNotifier<int> {
  UnreadMessages(value) : super(value);

  void messagesNew() => value += 1;
  void messagesRead() => value = 0;
  void messagesClear() {
    if (value != 0)
      messagesRead();
    else
      notifyListeners();
  }
}

class ChangeValueNotifier extends _ValueNotifier<bool> {
  ChangeValueNotifier({bool value = false}) : super(value);
}

class ChangeThrottledValueNotifier extends ThrottledValueNotifier<bool> {
  ChangeThrottledValueNotifier({bool value = false, delay}) : super(value, interval: delay);
}

class ResettableBoolNotifier extends ValueNotifier<bool> {
  final Duration delay;
  final bool def;
  Timer _timer;

  ResettableBoolNotifier(this.delay, {this.def = false}) : super(def);

  @override
  set value(bool newValue) {
    if (newValue != def) {
      _timer?.cancel();
      _timer = Timer(delay, () {
        _timer = null;
        super.value = def;
      });
    } else if (value == def && _timer != null) {
      _timer.cancel();
      _timer = null;
    }
    super.value = newValue;
  }

  void reset() => value = def;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
