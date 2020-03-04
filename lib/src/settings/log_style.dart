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
  static const lvl = '1';
  static const fontSize = '2';
  static const timeFormat = '3';
  static const callLvl = '4';
}

class LogStyle extends ChangeValueNotifier {
  bool _noNotify = false;
  LogLevel _lvl = LogLevel.debug;
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
    LogLevel.system: TextStyle(color: Colors.orange[900]),
  };
  static final callers = {
    0: TextStyle(color: Colors.cyan, fontWeight: FontWeight.w600),
    1: TextStyle(color: Colors.cyan[800], fontWeight: FontWeight.w300),
    2: TextStyle(color: Colors.cyan[900], fontWeight: FontWeight.w300),
  };
  static const TextStyle time = TextStyle(color: Colors.white70);

  LogLevel get lvl => _lvl;
  String get timeFormat => _timeFormat;
  int get fontSize => _base.fontSize.floor();
  TextStyle get base => _base;
  int get callLvl => _callLvl;

  set lvl(LogLevel val) {
    if (val == _lvl) return;
    _lvl = val;
    notifyListeners();
  }

  set timeFormat(String val) {
    if (val == _timeFormat) return;
    _timeFormat = val;
    notifyListeners();
  }

  set fontSize(int size) {
    if (size == fontSize) return;
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
    lvl = LogLevel.values[json[_N.lvl]] ?? lvl;
    fontSize = json[_N.fontSize] ?? fontSize;
    timeFormat = json[_N.timeFormat] ?? timeFormat;
    callLvl = json[_N.callLvl] ?? callLvl;
  }

  Map<String, dynamic> toJson() => {
        _N.lvl: lvl.index,
        _N.fontSize: fontSize,
        _N.timeFormat: timeFormat,
        _N.callLvl: callLvl,
      };

  bool upgrade(LogStyle o) {
    if (isEqual(o)) return false;
    _noNotify = true;
    _upgrade(o);
    _noNotify = false;
    notifyListeners();
    return true;
  }

  void _upgrade(LogStyle o) {
    lvl = o.lvl;
    fontSize = o.fontSize;
    timeFormat = o.timeFormat;
    callLvl = o.callLvl;
  }

  @override
  void notifyListeners() {
    if (!_noNotify) super.notifyListeners();
  }

  bool isEqual(LogStyle o) =>
      lvl == o.lvl && fontSize == o.fontSize && timeFormat == o.timeFormat && callLvl == o.callLvl;

  LogStyle clone() => LogStyle().._upgrade(this);

  void loadAsBaseStyle() {
    SharedPreferences.getInstance().then((p) {
      final data = p.getString(_defaultLogStyle);
      if (data == null) return;
      LogStyle result;
      try {
        result = LogStyle.fromJson(jsonDecode(data));
      } catch (e) {
        debugPrint(' * loadAsBaseStyle error: $e');
        return;
      }
      _noNotify = true;
      _upgrade(result);
      _noNotify = false;
    });
  }

  saveAsBaseStyle() async {
    await SharedPreferences.getInstance()
      ..setString(_defaultLogStyle, jsonEncode(this));
  }
}
