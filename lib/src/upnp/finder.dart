import 'dart:async';

import 'package:flutter/material.dart';
import 'package:upnp/upnp.dart';
import 'package:mdmt2_config/src/upnp/terminal_info.dart';

part 'package:mdmt2_config/src/blocs/finder.dart';

class Finder extends _BLoC {
  static const ST = 'urn:schemas-upnp-org:service:mdmTerminal2';
  static const searchInterval = Duration(seconds: 15);
  static const autoResendInterval = Duration(seconds: 5);
  // _search может упасть с эксепшеном который нельзя отловить.
  // Если долго нет результата просто остановим поиск
  static const mayBeDeadInterval = Duration(seconds: 30);
  Timer _periodicResendTimer, _periodicSearchTimer, _mayBeDead;

  StreamSubscription _subscribe;
  final _discoverer = DeviceDiscoverer();

//  final _terminals = <TerminalInfo>[
//    TerminalInfo.direct(
//        '1111', '127.0.0.1', 1111, '1', 100, (DateTime.now().millisecondsSinceEpoch / 1000).round() + 1000),
//    TerminalInfo.direct(
//        '2222', '127.0.0.2', 2222, '2', 200, (DateTime.now().millisecondsSinceEpoch / 1000).round() - 2000),
//    TerminalInfo.direct(
//        '3333', '127.0.0.3', 3333, '3', 300, (DateTime.now().millisecondsSinceEpoch / 1000).round() - 500),
//  ];

  final _terminals = <TerminalInfo>[];

  void _startInput() async {
    _work = true;
    _subscribe = _discoverer.clients.listen((event) {
      _startMayBeDead();
      final timestamp = DateTime.now();
      event.getDevice().then((value) {
        final info = TerminalInfo(event, value, timestamp: timestamp);
        if (info != null) _newTerminalInfo(info);
      }).catchError((e) => debugPrint('*** getDevice error: $e'));
    });
    try {
      await _discoverer.start();
    } catch (e) {
      stop(error: e);
      return;
    }
    _startMayBeDead();
    _search();
    _periodicSearchTimer = Timer.periodic(searchInterval, (_) => _search());
    _startPeriodicSend();
  }

  void _startPeriodicSend() => _periodicResendTimer = Timer.periodic(autoResendInterval, (_) => send());

  void _startMayBeDead() {
    _mayBeDead?.cancel();
    _mayBeDead = Timer(mayBeDeadInterval, stop);
  }

  void _newTerminalInfo(TerminalInfo info) {
    //debugPrint('New info: $info');
    bool resend = true;
    final int index = _terminals.indexOf(info);
    if (index > -1) {
      resend = _terminals[index].upgrade(info);
    } else {
      _terminals.add(info);
    }
    if (resend) {
      _periodicResendTimer?.cancel();
      send();
      _startPeriodicSend();
    }
  }

  void _stopInput() {
    _work = false;
    _periodicResendTimer?.cancel();
    _periodicSearchTimer?.cancel();
    _mayBeDead?.cancel();
    _subscribe?.cancel();
    try {
      _discoverer.stop();
    } catch (e) {
      debugPrint('*** discoverer.stop: $e');
    }
  }

  void _sendDataOutput() =>
      __outputStream.add(_sort ? (_terminals.sublist(0)..sort((a, b) => b.timestampSec - a.timestampSec)) : _terminals);

  _search() {
    // FIXME Unhandled Exception: SocketException: Send failed (OS Error: Network is unreachable, errno = 101), address = 0.0.0.0, port = 0
    // не отловить :(
    _discoverer.search(ST);
  }

  void dispose() {
    _stopInput();
    super.dispose();
  }
}
