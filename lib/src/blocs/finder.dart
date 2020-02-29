part of 'package:mdmt2_config/src/upnp/finder.dart';

enum _tCMD { start, stop, sortOn, sortOff, send }

enum FinderStage { wait, processing, work }

class _CMD {
  final _tCMD cmd;
  final dynamic error;
  _CMD(this.cmd, {this.error});
}

abstract class _BLoC {
  bool _sort = false;
  bool _work = false;
  final __inputCMD = StreamController<_CMD>();
  FinderStage _stage = FinderStage.wait;
  StreamSubscription __subscription;

  final __outputStream = StreamController<List<TerminalInfo>>();
  final __outputStatusStream = StreamController<FinderStage>();

  Stream<List<TerminalInfo>> get data => __outputStream.stream;
  Stream<FinderStage> get status => __outputStatusStream.stream;

  _BLoC() {
    __subscription = __inputCMD.stream.listen((event) {
      if (event.cmd == _tCMD.sortOn || event.cmd == _tCMD.sortOff) {
        final sort = event.cmd == _tCMD.sortOn ? true : false;
        if (sort != _sort) {
          _sort = sort;
          _sendDataOutput();
        }
        return;
      } else if (event.cmd == _tCMD.send) {
        _sendDataOutput();
        return;
      }

      if (_stage == FinderStage.processing) return;
      _stage = FinderStage.processing;

      __outputStatusStream.add(_stage);
      switch (event.cmd) {
        case _tCMD.start:
          if (_work) _stopInput();
          _startInput();
          _stage = FinderStage.work;
          __outputStatusStream.add(_stage);
          break;
        case _tCMD.stop:
          _stopInput();
          _stage = FinderStage.wait;
          if (event.error == null)
            __outputStatusStream.add(_stage);
          else
            __outputStatusStream.addError(event.error);
          break;
        default:
          break;
      }
    });
  }

  void dispose() {
    __subscription.cancel();
    __inputCMD.close();
    __outputStream.close();
    __outputStatusStream.close();
  }

  void _startInput();
  void _stopInput();
  void _sendDataOutput();

  void start() => __inputCMD.add(_CMD(_tCMD.start));
  void stop({dynamic error}) => __inputCMD.add(_CMD(_tCMD.stop, error: error));
  void send() => __inputCMD.add(_CMD(_tCMD.send));
  set sort(bool value) => __inputCMD.add(_CMD(value ? _tCMD.sortOn : _tCMD.sortOff));
  bool get sort => _sort;
}
