part of 'package:mdmt2_config/src/terminal/instances_controller.dart';

enum _tCMD { run, stop, remove, clear, stopAll, clearAll }

class _CMD {
  final _tCMD cmd;
  final ServerData target;
  final returnInstanceCallback runCallback;
  _CMD(this.cmd, {this.target, this.runCallback});
}

abstract class _BLoC {
  final __stream = StreamController<_CMD>();
  StreamSubscription __subscription;
  _BLoC() {
    __subscription = __stream.stream.listen((_CMD data) {
      switch (data.cmd) {
        case _tCMD.run:
          _runInput(data.target, result: data.runCallback);
          break;
        case _tCMD.stop:
          _stopInput(data.target);
          break;
        case _tCMD.clear:
          _clearInput(data.target);
          break;
        case _tCMD.remove:
          _removeInput(data.target);
          break;
        case _tCMD.stopAll:
          _stopAllInput();
          break;
        case _tCMD.clearAll:
          _clearAllInput();
          break;
      }
    });
  }

  void _clearAllInput();
  void _stopAllInput();
  bool _removeInput(ServerData server, {bool callDispose = true});
  bool _stopInput(ServerData server);
  void _clearInput(ServerData server);
  void _runInput(ServerData server, {returnInstanceCallback result});

  void dispose() {
    __subscription.cancel();
    __stream.close();
  }

  void clearAll() => __stream.add(_CMD(_tCMD.clearAll));
  void stopAll() => __stream.add(_CMD(_tCMD.stopAll));
  void remove(ServerData server) => __stream.add(_CMD(_tCMD.remove, target: server));
  void stop(ServerData server) => __stream.add(_CMD(_tCMD.stop, target: server));
  void clear(ServerData server) => __stream.add(_CMD(_tCMD.clear, target: server));
  void run(ServerData server, {returnInstanceCallback result}) =>
      __stream.add(_CMD(_tCMD.run, target: server, runCallback: result));
}
