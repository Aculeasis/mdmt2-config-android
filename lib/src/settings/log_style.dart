import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

const timeFormats = {
  'Full': 'yyyy.MM.dd HH:mm:ss.SSS',
  'Compact': 'yy.MM.dd HH:mm:ss',
  'Minimal': 'HH:mm:ss',
  'None': null,
};

class _Keys {
  static const lvl = 'style_lvl';
  static const fontSize = 'style_fontSize';
  static const timeFormat = 'style_timeFormat';
  static const callLvl = 'style_callLvl';
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

  void loadAll() {
    SharedPreferences.getInstance().then((p) {
      _noNotify = true;
      final _lvl = p.getInt(_Keys.lvl);
      if (_lvl != null && _lvl > -1 && _lvl < LogLevel.values.length) lvl = LogLevel.values[_lvl];

      fontSize = p.getInt(_Keys.fontSize) ?? fontSize;

      final _timeFormat = p.getString(_Keys.timeFormat);
      if (timeFormats.containsKey(_timeFormat)) timeFormat = _timeFormat;

      callLvl = p.getInt(_Keys.callLvl) ?? callLvl;
      _noNotify = false;
    });
  }

  saveAll() async {
    await SharedPreferences.getInstance()
      ..setInt(_Keys.lvl, lvl.index)
      ..setInt(_Keys.fontSize, fontSize)
      ..setString(_Keys.timeFormat, timeFormat)
      ..setInt(_Keys.callLvl, callLvl);
  }
}
