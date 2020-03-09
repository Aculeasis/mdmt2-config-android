import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/terminal/file_logging.dart';
import 'package:native_state/native_state.dart';
import 'package:rxdart/rxdart.dart';

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
  static const maxLength = 1000;
  static const logFlag = 'log_state_restore';
  final SavedStateData _saved;
  FileLog _fileLog;
  final UnreadMessages _unreadMessages;
  final LogStyle _style;
  final _log = ListQueue<LogLine>();
  final _actualLog = ListQueue<LogLine>();
  final _actualStream = BehaviorSubject<ListQueue<LogLine>>();
  final _requestsStream = StreamController<String>();
  final _addLogLineStream = StreamController<dynamic>();

  LogLevel _lvl;

  Stream<ListQueue<LogLine>> get actualLog => _actualStream.stream;

  Log(this._style, this._unreadMessages, this._saved, String uuid) {
    _lvl = _style.lvl;
    _style.addListener(_setLvl);
    _addLogLineStream.stream.listen((dynamic line) {
      if (line is LogLine) {
        _fileLog?.writeLine(jsonEncode(line));
        _add(line);
      } else {
        _addFromJson(line);
      }
    });
    _requestsStream.stream.listen((cmd) {
      if (cmd == 'clear') {
        _clearInput();
      } else {
        debugPrint('"$cmd"? WTF?');
      }
    });
    if (_saved == null) {
      return;
    }
    final restore = _saved.getBool(logFlag) == true;
    _fileLog = LogsBox().getFileLog(uuid);
    if (_fileLog != null) {
      _saved.putBool(logFlag, true);
      _fileLog.maxLineCount = maxLength;
      _fileLog.maxDirty = (maxLength / 10).truncate();
      if (restore) _restore();
    }
  }

  _restore() {
    int counts = 0;
    _fileLog.readAll().listen((line) {
      _addFromJson(line, isRestore: true);
      counts++;
    }, onError: (e) {
      _restoreFinished(counts);
      debugPrint(' * Restore log error ${_fileLog.path}: $e');
    }, onDone: () => _restoreFinished(counts));
  }

  _restoreFinished(int counts) {
    debugPrint(' * Restore $counts logline from ${_fileLog.path}');
    if (_actualLog.isNotEmpty) _actualStream.add(_actualLog);
  }

  void dispose() {
    _addLogLineStream.close();
    _requestsStream.close();
    _actualStream.close();
    _style.removeListener(_setLvl);
    _unreadMessages.messagesRead();
    _saved?.remove(logFlag);
    _fileLog?.dispose();
    debugPrint('DISPOSE LOG');
  }

  bool get isNotEmpty => _actualLog.length > 0;

  void _clearInput() {
    if (!isNotEmpty) return;
    _log.clear();
    _actualLog.clear();
    _fileLog?.clear();
    _unreadMessages.messagesClear();
    _actualStream.add(_actualLog);
  }

  void clear() => _requestsStream.add('clear');
  void addFromJson(dynamic line) => _addLogLineStream.add(line);
  void addSystem(String msg, {List<String> callers}) =>
      _addLogLineStream.add(LogLine(callers, msg, LogLevel.system, DateTime.now()));

  _setLvl() {
    if (_style.lvl != _lvl) {
      _lvl = _style.lvl;
      _rebuildActual();
      _actualStream.add(_actualLog);
    }
  }

  bool _addActual(LogLine line, bool isRestore) {
    if (line.lvl.index < _lvl.index) return false;
    if (_actualLog.length >= maxLength) _actualLog.removeLast();
    _actualLog.addFirst(line);
    if (!isRestore) {
      _unreadMessages.messagesNew();
      _actualStream.add(_actualLog);
    }
    return true;
  }

  bool _add(LogLine line, {isRestore = false}) {
    if (_log.length >= maxLength) _log.removeLast();
    _log.addFirst(line);
    return _addActual(line, isRestore);
  }

  bool _addFromJson(dynamic line, {isRestore = false}) {
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

  _rebuildActual() => _actualLog
    ..clear()
    ..addAll(_log.where((element) => element.lvl.index >= _lvl.index));
}
