import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:shared_preferences/shared_preferences.dart';

const timeFormats = {
  'Full': 'yyyy.MM.dd HH:mm:ss.SSS',
  'Compact': 'yy.MM.dd HH:mm:ss',
  'Minimal': 'HH:mm:ss',
  'None': null,
};

const _defaultLogStyle = 'def_log_slyle';

class _N {
  static const fontSize = '2';
  static const timeFormat = '3';
  static const callLvl = '4';
  static const logLevels = '5';
}

class LogStyle extends ChangeValueNotifier {
  // все двоичные маски: 1, 10, 100 итд
  static final List<int> masks = LogLevel.values.map((e) => 1 << e.index).toList(growable: false);
  // все биты логлевела: 111111
  int _logLevels = (1 << LogLevel.values.length) - 1;
  bool _noNotify = false;
  String _timeFormat = 'Compact';
  int _callLvl = 3;
  TextStyle _base = TextStyle(color: Colors.white, fontSize: 14);

  static const Color backgroundColor = Colors.black;
  static final msg = {
    LogLevel.debug: TextStyle(color: Colors.grey),
    LogLevel.info: TextStyle(color: Colors.green),
    LogLevel.warn: TextStyle(color: Colors.yellow),
    LogLevel.error: TextStyle(color: Colors.red),
    LogLevel.critical: TextStyle(color: Colors.purpleAccent),
    LogLevel.system: TextStyle(color: Colors.blue),
  };
  static final callers = {
    0: TextStyle(color: Colors.cyan, fontWeight: FontWeight.w600),
    1: TextStyle(color: Colors.cyan[800], fontWeight: FontWeight.w300),
    2: TextStyle(color: Colors.cyan[900], fontWeight: FontWeight.w300),
  };
  static const TextStyle time = TextStyle(color: Colors.white70);

  int get logLevels => _logLevels;
  String get timeFormat => _timeFormat;
  int get fontSize => _base.fontSize.floor();
  TextStyle get base => _base;
  int get callLvl => _callLvl;

  bool containsLvl(LogLevel lvl) => _logLevels & masks[lvl.index] == masks[lvl.index];
  bool addLvl(LogLevel lvl) => _setLogLevels(_logLevels | masks[lvl.index]);
  bool delLvl(LogLevel lvl) => _setLogLevels(_logLevels & ~masks[lvl.index]);

  bool _setLogLevels(int value) {
    if (value == _logLevels) return false;
    _logLevels = value;
    notifyListeners();
    return true;
  }

  set timeFormat(String val) {
    if (val == _timeFormat) return;
    _timeFormat = val;
    notifyListeners();
  }

  set fontSize(int size) {
    if (size == fontSize || size < 1) return;
    _base = _base.copyWith(fontSize: size.floorToDouble());
    notifyListeners();
  }

  set callLvl(int s) {
    if (s != _callLvl && s > -1 && s <= callers.length) {
      _callLvl = s;
      notifyListeners();
    }
  }

  LogStyle();

  LogStyle.fromJson(Map<String, dynamic> json) {
    _logLevels = json[_N.logLevels] ?? _logLevels;
    fontSize = json[_N.fontSize] ?? fontSize;
    timeFormat = json[_N.timeFormat] ?? timeFormat;
    callLvl = json[_N.callLvl] ?? callLvl;
  }

  Map<String, dynamic> toJson() => {
        _N.logLevels: _logLevels,
        _N.fontSize: fontSize,
        _N.timeFormat: timeFormat,
        _N.callLvl: callLvl,
      };

  bool upgrade(LogStyle o) {
    if (isEqual(o)) return false;
    _upgrade(o);
    notifyListeners();
    return true;
  }

  void _upgrade(LogStyle o) {
    _noNotify = true;
    _logLevels = o.logLevels;
    fontSize = o.fontSize;
    timeFormat = o.timeFormat;
    callLvl = o.callLvl;
    _noNotify = false;
  }

  @override
  void notifyListeners() {
    if (!_noNotify) super.notifyListeners();
  }

  bool isEqual(LogStyle o) =>
      _logLevels == o.logLevels && fontSize == o.fontSize && timeFormat == o.timeFormat && callLvl == o.callLvl;

  LogStyle clone() => LogStyle().._upgrade(this);

  void upgradeFromJson(String json) {
    if (json == null) return;
    LogStyle result;
    try {
      result = LogStyle.fromJson(jsonDecode(json));
    } catch (e) {
      debugPrint(' * upgradeFromJson error: $e');
      return;
    }
    _upgrade(result);
  }

  void loadAsBaseStyle() async => upgradeFromJson((await SharedPreferences.getInstance()).getString(_defaultLogStyle));

  saveAsBaseStyle() async {
    await SharedPreferences.getInstance()
      ..setString(_defaultLogStyle, jsonEncode(this));
  }
}
