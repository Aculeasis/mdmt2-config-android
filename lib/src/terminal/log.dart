import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';

enum LogLevel { debug, info, warn, error, critical, system }

final _logLvlMap = {
  'DEBUG': LogLevel.debug,
  'INFO ': LogLevel.info,
  'WARN ': LogLevel.warn,
  'ERROR': LogLevel.error,
  'CRIT ': LogLevel.critical,
  'REMOTE': LogLevel.system,
};

class LogLine {
  final List<String> callers;
  final String msg;
  final LogLevel lvl;
  final DateTime time;
  LogLine(this.callers, this.msg, this.lvl, this.time);

  LogLine.fromJson(Map<String, dynamic> json)
      : callers = List<String>.from(json['callers']),
        msg = json['msg'],
        lvl = _logLvlMap[json['lvl']],
        time = timeToDateTime(json['time']);

  static DateTime timeToDateTime(double time) => DateTime.fromMillisecondsSinceEpoch((time * 1000).toInt());
}

class Log {
  final ServerDataStates _serverStates;
  final LogStyle _style;
  static const maxLength = 1000;
  final _log = ListQueue<LogLine>();
  final _actualLog = ListQueue<LogLine>();

  LogLevel _lvl;

  Log(this._style, this._serverStates) {
    _lvl = _style.lvl;
    _style.addListener(_setLvl);
  }

  void dispose() {
    debugPrint('DISPOSE LOG');
    _style.removeListener(_setLvl);
    _serverStates.messagesRead();
  }

  LogLine operator [](int index) => _actualLog.elementAt(index);
  int get length => _actualLog.length;
  //LogLevel get lvl => _lvl;
  bool get isNotEmpty => _actualLog.length > 0;

  void clear() {
    if (!isNotEmpty) return;
    _log.clear();
    _actualLog.clear();
    _serverStates.messagesClear();
  }

  _setLvl() {
    if (_style.lvl != _lvl) {
      _lvl = _style.lvl;
      _rebuildActual();
    }
  }

  bool _addActual(LogLine line) {
    if (line.lvl.index < _lvl.index) return false;
    if (_actualLog.length >= maxLength) _actualLog.removeLast();
    _actualLog.addFirst(line);
    _serverStates.messagesNew();
    return true;
  }

  bool _add(LogLine line) {
    if (_log.length >= maxLength) _log.removeLast();
    _log.addFirst(line);
    return _addActual(line);
  }

  bool addFromJson(dynamic line) {
    LogLine logLine;
    try {
      logLine = LogLine.fromJson(jsonDecode(line));
    } catch (e) {
      logLine = LogLine(null, 'Recive broken logline "$line": $e', LogLevel.system, DateTime.now());
    }
    return _add(logLine);
  }

  bool addSystem(String msg, {List<String> callers}) => _add(LogLine(callers, msg, LogLevel.system, DateTime.now()));

  _rebuildActual() => _actualLog
    ..clear()
    ..addAll(_log.where((element) => element.lvl.index >= _lvl.index));
}
