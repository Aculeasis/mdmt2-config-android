import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/terminal/terminal_instance.dart';
import 'package:path/path.dart' show join;
import 'package:sqflite/sqflite.dart';

class _N {
  static const id = 'id';
  static const name = 'name';
  static const token = 'token';
  static const wsToken = 'wsToken';
  static const ip = 'ip';
  static const port = 'port';
  static const logger = 'logger';
  static const control = 'control';
  static const totpSalt = 'totpSalt';
  static const position = 'position';
}

class ServerData extends ChangeThrottledValueNotifier {
  int id;
  int position;
  TerminalInstance inst;

  String name, token, wsToken, ip;
  int _port;
  bool logger, control, totpSalt;
  ServerData(
      {this.name = '',
      this.token = '',
      this.wsToken = 'token_is_unset',
      this.ip = '127.0.0.1',
      int port = 7999,
      this.logger = true,
      this.control = false,
      this.totpSalt = false}) {
    this.port = port;
  }

  Map<String, dynamic> toMap() => {
        if (id != null) _N.id: id,
        _N.position: position != null ? position : throw ArgumentError.notNull('position'),
        _N.name: name != '' ? name : throw ArgumentError('name is empty'),
        _N.token: token,
        _N.wsToken: wsToken,
        _N.ip: ip,
        _N.port: port,
        _N.logger: logger ? 1 : 0,
        _N.control: control ? 1 : 0,
        _N.totpSalt: totpSalt ? 1 : 0,
      };

  ServerData.fromMap(Map<String, dynamic> map)
      : id = map[_N.id],
        position = map[_N.position],
        name = map[_N.name],
        token = map[_N.token],
        wsToken = map[_N.wsToken],
        ip = map[_N.ip],
        _port = map[_N.port],
        logger = map[_N.logger] == 1,
        control = map[_N.control] == 1,
        totpSalt = map[_N.totpSalt] == 1;

  int get port => _port;
  set port(int val) {
    if (val < 1 || val > 65535) throw ('Wrong port');
    _port = val;
  }

  String get sid {
    assert(id != null);
    return id.toString();
  }

  String get uri => '$ip:${_port.toString()}';
  String get title => '$name [$uri]';
  @override
  String toString() => '$position: $title';

  bool upgrade(ServerData o) {
    if (isEqual(o) || o.name == '') return false;
    _upgrade(o);
    return true;
  }

  void _upgrade(ServerData o) {
    name = o.name;
    token = o.token;
    wsToken = o.wsToken;
    ip = o.ip;
    port = o.port;
    logger = o.logger;
    control = o.control;
    totpSalt = o.totpSalt;
  }

  bool isEqual(ServerData o) {
    return name == o.name &&
        token == o.token &&
        wsToken == o.wsToken &&
        ip == o.ip &&
        port == o.port &&
        logger == o.logger &&
        control == o.control &&
        totpSalt == o.totpSalt;
  }

  ServerData clone() => ServerData().._upgrade(this);

  @override
  void reset() {
    super.reset();
    assert(() {
      Timer(Duration(milliseconds: 300), () {
        assert(!this.hasListeners);
        debugPrint('ServerData ---- OK!');
      });
      return true;
    }());
  }
}

class ServerDataDB {
  static const tableName = 'servers';
  static const filename = 'servers.db';
  static const version = 1;
  Database _db;
  Future open() async {
    final path = join(await getDatabasesPath(), filename);
    _db = await openDatabase(path, version: version, onCreate: _onCreate);

    debugPrint('$filename: ${await Directory(path).stat()}');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(createTableV1);
  }

  Future<ServerData> insert(ServerData server, int position) async {
    server.id = await _db.insert(tableName, (server..position = position).toMap());
    assert(server.id != null);
    return server;
  }

  Future<int> update(ServerData server, int position) async {
    final count = await _db
        .update(tableName, (server..position = position).toMap(), where: '${_N.id} = ?', whereArgs: [server.id]);
    assert(count == 1);
    return count;
  }

  Future<int> updateAll(List<ServerData> servers, {int start = 0, length}) async {
    length ??= servers.length;
    if (length - start == 0) {
      debugPrint(' * _saveAll nope');
      return 0;
    }
    final batch = _db.batch();
    for (int i = start; i < length; i++)
      batch.update(tableName, (servers[i]..position = i).toMap(), where: '${_N.id} = ?', whereArgs: [servers[i].id]);
    final count = (await batch.commit()).reduce((a, b) => a + b);
    debugPrint(' * _saveAll ${length - start}, saved: $count');
    assert(length - start == count);
    return count;
  }

  Future<int> delete(int id) async {
    final count = await _db.delete(tableName, where: '${_N.id} = ?', whereArgs: [id]);
    assert(count == 1);
    return count;
  }

  Future<int> deleteAll() async {
    return await _db.delete(tableName);
  }

  Future<List<ServerData>> getAll([bool loop = false]) async {
    final errors = <String>[];
    final result = (await _db.query(tableName)).map((e) => ServerData.fromMap(e)).toList()
      ..sort((a, b) {
        if (a.position == b.position) errors.add('$a<->$b');
        return a.position - b.position;
      });
    if (errors.isNotEmpty) {
      if (!loop) {
        debugPrint('Positions equal: ${errors.join(', ')}. Fix');
        await updateAll(result);
        return getAll(true);
      } else
        assert(false, 'Positions equal: ${errors.join(', ')}. wontfix!');
    }
    return result;
  }

  Future close() async => _db.close();

  static const createTableV1 = '''
    create table $tableName (
    ${_N.id} integer primary key autoincrement,
    ${_N.name} text not null unique,
    ${_N.token} text not null,
    ${_N.wsToken} text not null,
    ${_N.ip} text not null,
    ${_N.port} integer not null,
    ${_N.logger} integer not null,
    ${_N.control} integer not null,
    ${_N.totpSalt} ineger not null,
    ${_N.position} integer not null)
    ''';
}
