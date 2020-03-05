part of 'package:mdmt2_config/src/servers/servers_controller.dart';

enum _tCMD {
  removeAll,
  upgrade,
  add,
  addAlways,
  remove,
  insertAlways,
  relocation,
  run,
  stop,
  clear,
  stopAll,
  clearAll,
  iOpen,
  iClose
}

class _CMD {
  final _tCMD cmd;
  final ServerData server1;
  final ServerData server2;
  final int index1;
  final int index2;
  final returnServerCallback serverCallback;
  _CMD(this.cmd, {this.index1, this.index2, this.server1, this.server2, this.serverCallback});
}

abstract class _BLoC extends ChangeNotifier {
  final __stream = StreamController<_CMD>();
  StreamSubscription __subscription;
  _BLoC() {
    __subscription = __stream.stream.listen((_CMD data) {
      switch (data.cmd) {
        case _tCMD.removeAll:
          _removeAllInput();
          break;
        case _tCMD.upgrade:
          _upgradeInput(data.server1, data.server2);
          break;
        case _tCMD.add:
          _addInput(data.server1);
          break;
        case _tCMD.addAlways:
          _addAlwaysInput(data.server1);
          break;
        case _tCMD.remove:
          _removeInput(data.server1, result: data.serverCallback);
          break;
        case _tCMD.insertAlways:
          _insertAlwaysInput(data.index1, data.server1);
          break;
        case _tCMD.relocation:
          _relocationInput(data.index1, data.index2);
          break;
        case _tCMD.clearAll:
          _clearAllInput();
          break;
        case _tCMD.stopAll:
          _stopAllInput();
          break;
        case _tCMD.stop:
          _stopInput(data.server1);
          break;
        case _tCMD.clear:
          _clearInput(data.server1);
          break;
        case _tCMD.run:
          _runInput(data.server1, result: data.serverCallback);
          break;
        case _tCMD.iOpen:
        case _tCMD.iClose:
          _openInput(data.server1, data.cmd == _tCMD.iOpen);
          break;
      }
    });
  }

  void _removeAllInput();

  void _upgradeInput(ServerData oldServer, ServerData server);

  bool _addInput(ServerData server);
  void _addAlwaysInput(ServerData server);
  void _removeInput(ServerData server, {returnServerCallback result});
  void _insertAlwaysInput(int index, ServerData server);
  void _relocationInput(int oldIndex, newIndex);

  void _clearAllInput();
  void _stopAllInput();
  bool _stopInput(ServerData server);
  void _clearInput(ServerData server);
  void _runInput(ServerData server, {returnServerCallback result});
  void _openInput(ServerData server, bool openClose);

  void dispose() {
    __subscription.cancel();
    __stream.close();
    super.dispose();
  }

  void removeAll() => __stream.sink.add(_CMD(_tCMD.removeAll));
  void upgrade(ServerData oldServer, ServerData server) =>
      __stream.sink.add(_CMD(_tCMD.upgrade, server1: oldServer, server2: server));
  void add(ServerData server) => __stream.sink.add(_CMD(_tCMD.add, server1: server));
  void addAlways(ServerData server) => __stream.sink.add(_CMD(_tCMD.addAlways, server1: server));
  void remove(ServerData server, {returnServerCallback result}) =>
      __stream.sink.add(_CMD(_tCMD.remove, server1: server, serverCallback: result));
  void insertAlways(int index, ServerData server) =>
      __stream.sink.add(_CMD(_tCMD.insertAlways, server1: server, index1: index));
  void relocation(int oldIndex, newIndex) =>
      __stream.sink.add(_CMD(_tCMD.relocation, index1: oldIndex, index2: newIndex));

  void clearAll() => __stream.add(_CMD(_tCMD.clearAll));
  void stopAll() => __stream.add(_CMD(_tCMD.stopAll));
  void stop(ServerData server) => __stream.add(_CMD(_tCMD.stop, server1: server));
  void clear(ServerData server) => __stream.add(_CMD(_tCMD.clear, server1: server));
  void run(ServerData server, {returnServerCallback result}) =>
      __stream.add(_CMD(_tCMD.run, server1: server, serverCallback: result));

  void open(ServerData server, bool openClose) =>
      __stream.add(_CMD(openClose ? _tCMD.iOpen : _tCMD.iClose, server1: server));
}

typedef returnServerCallback = void Function(ServerData server);
