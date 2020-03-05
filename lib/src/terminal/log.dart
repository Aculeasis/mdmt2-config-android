import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/terminal/file_logging.dart';
import 'package:native_state/native_state.dart';

enum LogLevel { debug, info, warn, error, critical, system }

final _logLvlMap = {
  'DEBUG': LogLevel.debug,
  'INFO ': LogLevel.info,
  'WARN ': LogLevel.warn,
  'ERROR': LogLevel.error,
  'CRIT ': LogLevel.critical,
  'REMOTE': LogLevel.system,
};

final Map<LogLevel, String> _mapLvlLog = _logLvlMap.map((key, value) => MapEntry(value, key));

class LogLine {
  final List<String> callers;
  final String msg;
  final LogLevel lvl;
  final DateTime time;
  LogLine(callers, this.msg, this.lvl, this.time) : this.callers = callers ?? [];

  LogLine.fromJson(Map<String, dynamic> json)
      : callers = List<String>.from(json['callers']) ?? [],
        msg = json['msg'],
        lvl = _logLvlMap[json['lvl']],
        time = timeToDateTime(json['time']);

  Map<String, dynamic> toJson() => {
        'callers': callers,
        'msg': msg,
        'lvl': _mapLvlLog[lvl],
        'time': dateTimeToTime(time),
      };

  static DateTime timeToDateTime(double time) => DateTime.fromMillisecondsSinceEpoch((time * 1000).toInt());
  static double dateTimeToTime(DateTime time) => time.toUtc().millisecondsSinceEpoch / 1000;
}

class Log {
  final SavedStateData _saved;
  FileLog _fileLog;
  final UnreadMessages _unreadMessages;
  final LogStyle _style;
  static const maxLength = 1000;
  final _log = ListQueue<LogLine>();
  final _actualLog = ListQueue<LogLine>();
  bool isRestored = false;

  LogLevel _lvl;

  Log(this._style, this._unreadMessages, this._saved, bool restore) {
    _lvl = _style.lvl;
    _style.addListener(_setLvl);
    _fileLog = LogsBox().getFileLog(_saved?.getString('name'));
    if (_fileLog != null) {
      _saved.putBool('flag', true);
      _fileLog.maxLineCount = maxLength;
      _fileLog.maxDirty = (maxLength / 10).truncate();
      if (restore)
        _restore();
      else
        isRestored = true;
    } else
      isRestored = true;
  }

  _restore() {
    int counts = 0;
    _fileLog.readAll().listen((line) {
      addFromJson(line, isRestore: true);
      counts++;
    }, onError: (e) {
      _restoreFinished(counts);
      debugPrint(' * Restore log error ${_fileLog.path}: $e');
    }, onDone: () => _restoreFinished(counts));
  }

  _restoreFinished(int counts) {
    debugPrint(' * Restore $counts logline from ${_fileLog.path}');
    isRestored = true;
    _unreadMessages.notifyListeners();
  }

  void dispose() {
    debugPrint('DISPOSE LOG');
    _style.removeListener(_setLvl);
    _unreadMessages.messagesRead();
    _saved?.clear();
    _fileLog?.dispose();
  }

  LogLine operator [](int index) => _actualLog.elementAt(index);
  int get length => _actualLog.length;
  bool get isNotEmpty => _actualLog.length > 0;

  void clear() {
    if (!isNotEmpty) return;
    _log.clear();
    _actualLog.clear();
    _fileLog?.clear();
    _unreadMessages.messagesClear();
  }

  _setLvl() {
    if (_style.lvl != _lvl) {
      _lvl = _style.lvl;
      _rebuildActual();
    }
  }

  bool _addActual(LogLine line, bool isRestore) {
    if (line.lvl.index < _lvl.index) return false;
    if (_actualLog.length >= maxLength) _actualLog.removeLast();
    _actualLog.addFirst(line);
    if (!isRestore) _unreadMessages.messagesNew();
    return true;
  }

  bool _add(LogLine line, {isRestore = false}) {
    if (_log.length >= maxLength) _log.removeLast();
    _log.addFirst(line);
    return _addActual(line, isRestore);
  }

  bool addFromJson(dynamic line, {isRestore = false}) {
    LogLine logLine;
    try {
      logLine = LogLine.fromJson(jsonDecode(line));
      if (!isRestore) _fileLog?.writeLine(line);
    } catch (e) {
      logLine = LogLine(null, 'Recive broken logline "$line": $e', LogLevel.system, DateTime.now());
      if (!isRestore) _fileLog?.writeLine(jsonEncode(logLine));
    }
    return _add(logLine, isRestore: isRestore);
  }

  bool addSystem(String msg, {List<String> callers}) {
    final logLine = LogLine(callers, msg, LogLevel.system, DateTime.now());
    _fileLog?.writeLine(jsonEncode(logLine));
    return _add(logLine);
  }

  _rebuildActual() => _actualLog
    ..clear()
    ..addAll(_log.where((element) => element.lvl.index >= _lvl.index));
}
