part of 'package:mdmt2_config/src/servers/servers_controller.dart';

enum _tCMD { removeAll, upgrade, add, addAlways, remove, insertAlways, relocation }

class _CMD {
  final _tCMD cmd;
  final ServerData server1;
  final ServerData server2;
  final int index1;
  final int index2;
  _CMD(this.cmd, {this.index1, this.index2, this.server1, this.server2});
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
          _removeInput(data.server1);
          break;
        case _tCMD.insertAlways:
          _insertAlwaysInput(data.index1, data.server1);
          break;
        case _tCMD.relocation:
          _relocationInput(data.index1, data.index2);
          break;
      }
    });
  }

  void _removeAllInput();
  void _upgradeInput(ServerData oldServer, ServerData server);
  bool _addInput(ServerData server);
  void _addAlwaysInput(ServerData server);
  void _removeInput(ServerData server);
  void _insertAlwaysInput(int index, ServerData server);
  void _relocationInput(int oldIndex, newIndex);

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
  void remove(ServerData server) => __stream.sink.add(_CMD(_tCMD.remove, server1: server));
  void insertAlways(int index, ServerData server) =>
      __stream.sink.add(_CMD(_tCMD.insertAlways, server1: server, index1: index));
  void relocation(int oldIndex, newIndex) =>
      __stream.sink.add(_CMD(_tCMD.relocation, index1: oldIndex, index2: newIndex));
}
