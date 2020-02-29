import 'dart:async';

import 'package:flutter/material.dart';

class ChangeValueNotifier extends ValueNotifier<bool> {
  ChangeValueNotifier({bool value = false}) : super(value);

  @override
  void notifyListeners() => super.notifyListeners();

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
