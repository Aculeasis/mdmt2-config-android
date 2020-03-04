import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/terminal/terminal_instance.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Name {
  static const _prefix = 'srv_d';
  static String index(int index) => '${_prefix}_$index';
}

class _N {
  static const name = '1';
  static const token = '2';
  static const wsToken = '3';
  static const ip = '4';
  static const port = '5';
  static const logger = '6';
  static const control = '7';
  static const totpSalt = '8';
}

Future<ServerData> loadServerData(int index) async {
  SharedPreferences p = await SharedPreferences.getInstance();
  final name = _Name.index(index);
  ServerData result;
  try {
    result = ServerData.fromJson(jsonDecode(p.getString(name)));
  } catch (e) {
    debugPrint(' * Error loading ServerData $index: $e');
    return null;
  }
  if (result.name == null ||
      result.name == '' ||
      result.token == null ||
      result.wsToken == null ||
      result.ip == null ||
      result.port == null ||
      result.logger == null ||
      result.control == null ||
      result.totpSalt == null) {
    debugPrint(' * Wrong ServerData $index');
    return null;
  }
  return result;
}

Future<void> removeServerData(int index) async {
  await SharedPreferences.getInstance()
    ..remove(_Name.index(index));
  debugPrint(' * remove id $index');
}

class ServerData extends ChangeThrottledValueNotifier {
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

  ServerData.fromJson(Map<String, dynamic> json)
      : name = json[_N.name],
        token = json[_N.token],
        wsToken = json[_N.wsToken],
        ip = json[_N.ip],
        _port = json[_N.port],
        logger = json[_N.logger],
        control = json[_N.control],
        totpSalt = json[_N.totpSalt];

  Map<String, dynamic> toJson() => {
        _N.name: name,
        _N.token: token,
        _N.wsToken: wsToken,
        _N.ip: ip,
        _N.port: port,
        _N.logger: logger,
        _N.control: control,
        _N.totpSalt: totpSalt
      };

  Future<void> saveServerData(int index) async {
    await SharedPreferences.getInstance()
      ..setString(_Name.index(index), jsonEncode(this));
  }

  int get port => _port;
  set port(int val) {
    if (val < 1 || val > 65535) throw ('Wrong port');
    _port = val;
  }

  String get uri => '$ip:${_port.toString()}';
  String get title => '$name [$uri]';

  bool upgrade(ServerData o) {
    if (isEqual(o) || o.name == '') return false;
    _upgrade(o);
    notifyListeners();
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
}
