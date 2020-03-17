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
  static const totpSalt = 'totpSalt';
  static const position = 'position';
}

class _S {
  static const log = 'log';
  static const qry = 'qry';
}

class ServerData extends ChangeThrottledValueNotifier {
  final ValueNotifier<bool> log;
  final ValueNotifier<bool> qry;

  int id;
  int position;
  TerminalInstance inst;

  String name, token, wsToken, ip;
  int _port;
  bool totpSalt;
  ServerData(
      {this.name = '',
      this.token = '',
      this.wsToken = 'token_is_unset',
      this.ip = '127.0.0.1',
      int port = 7999,
      this.totpSalt = false})
      : log = ValueNotifier<bool>(true),
        qry = ValueNotifier<bool>(false) {
    this.port = port;
  }

  bool get allowToRun => inst == null || (!inst.reconnect.isRun && !inst.work);

  Map<String, dynamic> toMap() => {
        if (id != null) _N.id: id,
        _N.position: position != null ? position : throw ArgumentError.notNull('position'),
        _N.name: name != '' ? name : throw ArgumentError('name is empty'),
        _N.token: token,
        _N.wsToken: wsToken,
        _N.ip: ip,
        _N.port: port,
        _N.totpSalt: totpSalt ? 1 : 0,
      };

  Map<String, dynamic> toStateMap() => {
        _N.id: id != null ? id : throw ArgumentError.notNull('id'),
        _S.log: log.value ? 1 : 0,
        _S.qry: qry.value ? 1 : 0,
      };

  ServerData.fromMap(Map<String, dynamic> map)
      : id = map[_N.id],
        position = map[_N.position],
        name = map[_N.name],
        token = map[_N.token],
        wsToken = map[_N.wsToken],
        ip = map[_N.ip],
        _port = map[_N.port],
        totpSalt = map[_N.totpSalt] == 1,
        log = ValueNotifier<bool>((map[_S.log] ?? 1) == 1),
        qry = ValueNotifier<bool>((map[_S.qry] ?? 0) == 1);

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

  void _upgrade(ServerData o, {isClone = false}) {
    name = o.name;
    token = o.token;
    wsToken = o.wsToken;
    ip = o.ip;
    port = o.port;
    if (isClone) {
      log.value = o.log.value;
      qry.value = o.qry.value;
    }
    totpSalt = o.totpSalt;
  }

  bool isEqual(ServerData o) {
    return name == o.name &&
        token == o.token &&
        wsToken == o.wsToken &&
        ip == o.ip &&
        port == o.port &&
        totpSalt == o.totpSalt;
  }

  ServerData clone() => ServerData().._upgrade(this, isClone: true);

  @override
  void reset() {
    super.reset();
    assert(() {
      Timer(Duration(milliseconds: 300), () {
        assert(!this.hasListeners);
        assert(!log.hasListeners);
        assert(!qry.hasListeners);
        debugPrint('ServerData ---- OK!');
      });
      return true;
    }());
  }
}

class ServerDataDB {
  static const _table = 'servers';
  static const _sTable = 'servers_state';
  static const filename = 'servers.db';
  static const version = 2;
  Database _db;
  Future open() async {
    final path = join(await getDatabasesPath(), filename);
    _db = await openDatabase(path, version: version, onCreate: _onCreate, onUpgrade: _onUpgrade);

    debugPrint('$filename: ${await Directory(path).stat()}');
  }

  static Future<void> _onCreate(Database db, int version) async {
    await db.execute(createServersTable);
    await db.execute(createServersStateTable);
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    debugPrint('Upgrade DB from $oldVersion to $newVersion...');
    oldVersion++;
    if (oldVersion == 2) {
      final tmpTable = '${_table}_tmp';
      final selectCol =
          "${_N.id}, ${_N.name}, ${_N.token}, ${_N.wsToken}, ${_N.ip}, ${_N.port}, ${_N.totpSalt}, ${_N.position}";

      await db.execute(createServersTable.replaceFirst(_table, tmpTable));
      await db.execute('INSERT INTO $tmpTable SELECT $selectCol FROM $_table');
      await db.execute('DROP TABLE IF EXISTS $_table');
      await db.execute('ALTER TABLE $tmpTable RENAME TO $_table');
      await db.execute(createServersStateTable);
    }
    if (oldVersion >= newVersion) {
      await db.setVersion(newVersion);
      debugPrint('Upgrade DB has completed.');
      return;
    } else {
      await _onUpgrade(db, oldVersion, newVersion);
    }
  }

  Future<ServerData> insert(ServerData server, int position) async {
    server.id = await _db.insert(_table, (server..position = position).toMap());
    assert(server.id != null);
    await insertState(server);
    return server;
  }

  Future<ServerData> insertState(ServerData server) async {
    final id = await _db.insert(_sTable, server.toStateMap());
    assert(id == server.id);
    return server;
  }

  Future<int> update(ServerData server, int position) async {
    final count =
        await _db.update(_table, (server..position = position).toMap(), where: '${_N.id} = ?', whereArgs: [server.id]);
    assert(count == 1);
    return count;
  }

  Future<int> updateState(ServerData server) async {
    int count = await _db.update(_sTable, server.toStateMap(), where: '${_N.id} = ?', whereArgs: [server.id]);
    assert(count < 2);
    if (count == 0) {
      insertState(server);
      count++;
    }
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
      batch.update(_table, (servers[i]..position = i).toMap(), where: '${_N.id} = ?', whereArgs: [servers[i].id]);
    final count = (await batch.commit()).reduce((a, b) => a + b);
    debugPrint(' * _saveAll ${length - start}, saved: $count');
    assert(length - start == count);
    return count;
  }

  Future<int> delete(int id) async {
    await _db.delete(_sTable, where: '${_N.id} = ?', whereArgs: [id]);
    final count = await _db.delete(_table, where: '${_N.id} = ?', whereArgs: [id]);
    assert(count == 1);
    return count;
  }

  Future<int> deleteAll() async {
    await _db.delete(_sTable);
    return await _db.delete(_table);
  }

  Future<List<ServerData>> getAll([bool loop = false]) async {
    final errors = <String>[];
    final result = (await _db.rawQuery(multiSelectRaw)).map((e) => ServerData.fromMap(e)).toList()
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

  static const multiSelectRaw = '''
      select $_table.*, $_sTable.${_S.log}, $_sTable.${_S.qry} 
      from $_table left outer join $_sTable on $_table.${_N.id} == $_sTable.${_N.id}
      ''';

  static const createServersTable = '''
    create table $_table (
    ${_N.id} integer primary key autoincrement,
    ${_N.name} text not null unique,
    ${_N.token} text not null,
    ${_N.wsToken} text not null,
    ${_N.ip} text not null,
    ${_N.port} integer not null,
    ${_N.totpSalt} ineger not null,
    ${_N.position} integer not null)
    ''';
  static const createServersStateTable = '''
    create table $_sTable (
    ${_N.id} integer primary key,
    ${_S.log} ineger not null,
    ${_S.qry} integer not null)
    ''';
}
