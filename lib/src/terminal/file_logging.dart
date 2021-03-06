import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' show join;
import 'package:path_provider/path_provider.dart';

class LogsBox {
  static const logsDir = 'logs';
  String _path;
  Map<String, File> _files = <String, File>{};
  Set<String> _owned = <String>{};
  static final _instance = LogsBox._();
  LogsBox._();

  factory LogsBox() => _instance;

  filling() async {
    assert(_owned != null && _files != null);
    final path = Directory(join((await getTemporaryDirectory()).path, logsDir));
    try {
      await path.create(recursive: true);
    } catch (e) {
      debugPrint('*** Error make logdir: $e');
      return;
    }
    _path = path.path;
    for (var target in path.listSync()) {
      if (target is File) _files[target.path] = target;
    }
  }

  FileLog getFileLog(String name) {
    if (name == null || name == '' || _path == null) return null;
    final strPath = join(_path, name);
    if (_owned?.contains(strPath) == true) {
      debugPrint('*** Error file $strPath already used ***');
      return null;
    }
    final file = File(strPath);
    _files?.remove(strPath);
    _owned?.add(strPath);
    return FileLog(file);
  }

  dispose() async {
    assert(_owned != null && _files != null);
    for (var target in _files.values) {
      try {
        target.delete();
      } catch (e) {
        debugPrint('*** Error deleting ${target.path}: $e');
        continue;
      }
      debugPrint('* Remove ${target.path}');
    }
    if (_files.isNotEmpty) debugPrint('* Remove ${_files.length} old files');
    _files = null;
    _owned = null;
  }
}

class FileLog {
  final File _file;
  final _stream = StreamController<String>();
  StreamSubscription<String> _subscription;
  IOSink _ioSink;
  int _lineCount = 0;
  int maxLineCount = 1000;
  int maxDirty = 100;

  String get path => _file.path;

  FileLog(this._file) {
    _subscription = _stream.stream.listen((line) {
      assert(!_subscription.isPaused);
      if (line == null)
        _clearInput();
      else
        _writeLineInput(line);
    });
  }

  Stream<String> readAll() async* {
    assert(_ioSink == null && !_subscription.isPaused);
    _subscription.pause();
    if (!await _file.exists()) {
      _subscription.resume();
      return;
    }
    try {
      for (var line in await _file.readAsLines()) {
        if (line.isEmpty) continue;
        _lineCount++;
        yield line;
      }
    } finally {
      assert(_ioSink == null && _subscription.isPaused);
      _subscription.resume();
    }
  }

  void writeLine(String line) => line != null ? _stream.add(line) : null;

  void _writeLineInput(String line) async {
    if (_ioSink == null) _openIOSink();
    _ioSink.writeln(line);
    _lineCount++;
    if (_lineCount - maxLineCount > maxDirty) _truncate();
  }

  void clear() => _stream.add(null);

  _clearInput() async {
    _subscription.pause();
    await _closeIOSink();
    if (await __removeFile(_file)) _lineCount = 0;
    _subscription.resume();
  }

  void dispose({bool remove = true}) async {
    _subscription.pause();
    await _subscription.cancel();
    await _stream.close();
    await _closeIOSink();
    try {
      await _file.delete();
    } catch (e) {
      debugPrint('Delete error ${_file.path}: $e');
      return;
    }
    debugPrint('REMOVE ${_file.path}');
  }

  _openIOSink() {
    debugPrint(' * Open writeOnlyAppend $path');
    _ioSink = _file.openWrite(mode: FileMode.writeOnlyAppend);
  }

  _closeIOSink() async {
    try {
      await _ioSink?.close();
    } catch (e) {
      debugPrint('_closeIOSink error ${_file.path}: $e');
    }
    _ioSink = null;
  }

  _truncate() async {
    assert(!_subscription.isPaused);
    _subscription.pause();
    if (!await __truncate()) maxDirty = maxDirty * 2;
    _subscription.resume();
  }

  Future<bool> __truncate() async {
    int newLineCount = 0;
    int ignore = _lineCount - maxLineCount;
    assert(ignore > 0);
    debugPrint(' * File $path too big, remove $ignore lines...');

    final tmpFile = File('${_file.path}_tmp');
    IOSink sink;
    try {
      sink = tmpFile.openWrite();
    } catch (e) {
      debugPrint(' Error open ${tmpFile.path}: $e');
      return false;
    }

    await _closeIOSink();

    try {
      for (var line in await _file.readAsLines()) {
        if (ignore > 0) {
          ignore--;
          continue;
        }
        if (line.isEmpty) continue;
        newLineCount++;
        sink.writeln(line);
      }
    } catch (e) {
      debugPrint(' Error truncate:  $e');
      await __sinkClose(sink, tmpFile.path);
      await __removeFile(tmpFile);
      return false;
    }

    await __sinkClose(sink, tmpFile.path);
    try {
      await tmpFile.rename(_file.path);
    } catch (e) {
      debugPrint(' RenameError ${tmpFile.path} -> ${_file.path}:  $e');
      await __removeFile(tmpFile);
      return false;
    }
    if (newLineCount != maxLineCount) {
      debugPrint(' *** truncate get ambiguous result:'
          ' before=$_lineCount, after=$newLineCount, max=$maxLineCount. WTF?');
    }
    _lineCount = newLineCount;
    return true;
  }

  __sinkClose(IOSink sink, String path) async {
    try {
      await sink?.close();
    } catch (e) {
      debugPrint(' _truncate sink.close error $path: $e');
    }
  }

  Future<bool> __removeFile(File file) async {
    try {
      if (await file?.exists() == true) await file?.delete();
    } catch (e) {
      debugPrint(' Error remove file ${file.path}:  $e');
      return false;
    }
    return true;
  }
}
