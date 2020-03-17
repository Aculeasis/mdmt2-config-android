part of 'package:mdmt2_config/src/servers/servers_controller.dart';

enum _tCMD {
  removeAll,
  upgrade,
  add,
  addAlways,
  remove,
  insertAlways,
  relocation,
  change,
  run,
  stop,
  clear,
  stopAll,
  clearAll
}

class _CMD {
  final _tCMD cmd;
  final List<dynamic> d;
  dynamic operator [](int index) => d[index];
  _CMD(this.cmd, {this.d});
}

abstract class _BLoC extends ChangeNotifier {
  final __stream = StreamController<_CMD>();
  StreamSubscription __subscription;
  _BLoC() {
    __subscription = __stream.stream.listen((_CMD data) async {
      __subscription.pause();
      try {
        await __input(data);
      } finally {
        __subscription.resume();
      }
    });
  }

  __input(_CMD data) async {
    switch (data.cmd) {
      case _tCMD.removeAll:
        await _removeAllInput();
        break;
      case _tCMD.upgrade:
        await _upgradeInput(data[0], data[1]);
        break;
      case _tCMD.add:
        await _addInput(data[0]);
        break;
      case _tCMD.addAlways:
        await _addAlwaysInput(data[0]);
        break;
      case _tCMD.remove:
        await _removeInput(data[0], result: data[1]);
        break;
      case _tCMD.insertAlways:
        await _insertAlwaysInput(data[0], data[1]);
        break;
      case _tCMD.relocation:
        await _relocationInput(data[0], data[1]);
        break;
      case _tCMD.change:
        await _changeInput(data[0], log: data[1], qry: data[2]);
        break;
      case _tCMD.clearAll:
        _clearAllInput();
        break;
      case _tCMD.stopAll:
        _stopAllInput();
        break;
      case _tCMD.stop:
        _stopInput(data[0]);
        break;
      case _tCMD.clear:
        _clearInput(data[0]);
        break;
      case _tCMD.run:
        _runInput(data[0], result: data[1]);
        break;
    }
  }

  Future<void> _removeAllInput();
  Future<void> _upgradeInput(ServerData oldServer, ServerData server);
  Future<bool> _addInput(ServerData server);
  Future<void> _addAlwaysInput(ServerData server);
  Future<void> _removeInput(ServerData server, {returnServerCallback result});
  Future<void> _insertAlwaysInput(int index, ServerData server);
  Future<void> _relocationInput(int oldIndex, newIndex);
  Future<void> _changeInput(ServerData server, {bool log, bool qry});

  void _clearAllInput();
  void _stopAllInput();
  bool _stopInput(ServerData server);
  void _clearInput(ServerData server);
  void _runInput(ServerData server, {returnServerCallback result});

  void dispose() {
    __subscription.cancel();
    __stream.close();
    super.dispose();
  }

  void removeAll() => __stream.add(_CMD(_tCMD.removeAll));
  void upgrade(ServerData oldServer, ServerData server) => __stream.add(_CMD(_tCMD.upgrade, d: [oldServer, server]));
  void add(ServerData server) => __stream.add(_CMD(_tCMD.add, d: [server]));
  void addAlways(ServerData server) => __stream.add(_CMD(_tCMD.addAlways, d: [server]));
  void remove(ServerData server, {returnServerCallback result}) =>
      __stream.add(_CMD(_tCMD.remove, d: [server, result]));
  void insertAlways(int index, ServerData server) => __stream.add(_CMD(_tCMD.insertAlways, d: [index, server]));
  void relocation(int oldIndex, newIndex) => __stream.add(_CMD(_tCMD.relocation, d: [oldIndex, newIndex]));
  void change(ServerData server, {bool log, bool qry}) => __stream.add(_CMD(_tCMD.change, d: [server, log, qry]));

  void clearAll() => __stream.add(_CMD(_tCMD.clearAll));
  void stopAll() => __stream.add(_CMD(_tCMD.stopAll));
  void stop(ServerData server) => __stream.add(_CMD(_tCMD.stop, d: [server]));
  void clear(ServerData server) => __stream.add(_CMD(_tCMD.clear, d: [server]));
  void run(ServerData server, {returnServerCallback result}) => __stream.add(_CMD(_tCMD.run, d: [server, result]));
}

typedef returnServerCallback = void Function(ServerData server);
typedef changeFnCallback = void Function(ServerData server, {bool log, bool qry});
