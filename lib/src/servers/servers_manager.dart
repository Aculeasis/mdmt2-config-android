part of 'package:mdmt2_config/src/servers/servers_controller.dart';

abstract class ServersManager extends _BLoC {
  final _db = ServerDataDB();
  final _array = ServersArray();
  bool isLoaded = false;

  ServersManager() {
    _restore();
  }

  int get length => _array.length;
  ServerData byName(String name) => _array.byName(name);
  bool contains(String name) => _array.contains(name);
  int indexOf(String name) => _array.indexOf(name);
  Iterable<ServerData> get loop => _array.iterable;

  @override
  void dispose() {
    _db.close();
    _array.clear();
    super.dispose();
  }

  bool _removeInstance(ServerData server, {bool callDispose = true, bool notify = true});

  bool _instanceMayRemoved(ServerData server) => server?.inst == null || !server.inst.work;

  Future<void> _removeAllInput() async {
    for (var server in _array.iterable) if (!_instanceMayRemoved(server)) return;

    final counts = await _db.deleteAll();
    assert(counts == _array.length);
    if (_array.isNotEmpty) {
      for (var server in _array.iterable) {
        server.reset();
        _removeInstance(server, notify: false);
      }
      _array.clear();
      notifyListeners();
    }
  }

  Future<void> _upgradeInput(ServerData oldServer, ServerData server) async {
    final index = _array.upgrade(oldServer, server);
    if (index != null) {
      server.reset();
      await _db.update(oldServer, index);
      oldServer.notifyListeners();
    }
  }

  Future<bool> _addInput(ServerData server, {reset = true}) async {
    final index = _array.add(server);
    if (index == null) {
      if (reset) server?.reset();
      return false;
    }
    await _db.insert(server, index);
    notifyListeners();
    return true;
  }

  Future<void> _addAlwaysInput(ServerData server) async {
    if ((server?.name ?? '') == '') return;
    if (!await _addInput(server, reset: false)) {
      server.name = _newUniqueName(server.name);
      await _addInput(server);
    }
  }

  Future<void> _removeInput(ServerData server, {returnServerCallback result}) async {
    if (server == null || !_instanceMayRemoved(server)) return;
    _removeInstance(server, notify: false);
    final index = _array.remove(server);
    assert(index != null);
    if (index != null) {
      await _db.delete(server.id);
      await _db.updateAll(_array.iterable, start: index);
      server
        ..reset()
        ..id = null;
      if (result != null) result(server);
    }
    notifyListeners();
  }

  Future<void> _insertAlwaysInput(int index, ServerData server) async {
    if ((server?.name ?? '') == '') return;
    final index2 = _array.insert(index, server) ?? _array.insert(index, server..name = _newUniqueName(server.name));
    assert(index2 != null);
    if (index2 != null) {
      await _db.insert(server, index2);
      await _db.updateAll(_array.iterable, start: index2 + 1);
      notifyListeners();
    }
  }

  String _newUniqueName(String oldName) {
    for (int p = 1; p < 9999999; p++) {
      final newName = '$oldName-$p';
      if (!_array.contains(newName)) return newName;
    }
    throw new Exception('NEVER!');
  }

  Future<void> _relocationInput(int oldIndex, newIndex) async {
    final swap = _array.swap(oldIndex, newIndex);
    if (swap == null) return;
    debugPrint('* start=${swap.start}, length=${swap.length}');
    notifyListeners();
    await _db.updateAll(_array.iterable, start: swap.start, length: swap.length);
  }

  Future<void> _restore() async {
    await _db.open();
    await _loadAll();
    await _greatResurrector();
    isLoaded = true;
    notifyListeners();
  }

  _greatResurrector();

  Future<void> _loadAll() async {
    _array.build(await _db.getAll());
    assert(() {
      for (int i = 0; i < _array.length; i++) assert(_array[i].position == i);
      return true;
    }());
    debugPrint(' * LoadAll ${_array.length}');
  }
}
