part of 'package:mdmt2_config/src/servers/servers_controller.dart';

abstract class ServersManager extends _BLoC {
  static final serverDataCount = '_srvs__count';
  bool isLoaded = false;
  // Данные серверов, порядок важен
  final _servers = <ServerData>[];
  // Индексы, для быстрого поиска по имени.
  final _indices = <String, int>{};

  int get length => _servers.length;
  ServerData operator [](int index) => _servers[index];
  Iterable<ServerData> get loop => _servers;
  bool containsByObj(ServerData element) => contains(element.name);
  bool contains(String name) => _indices.containsKey(name);
  int indexOf(String name) => _indices[name] ?? -1;
  ServerData byName(String name) {
    final index = indexOf(name);
    return index != -1 ? _servers[index] : null;
  }

  ServersManager() {
    _restore();
  }

  @override
  void dispose() {
    super.dispose();
  }

  bool _removeInstance(ServerData server, {bool callDispose = true, bool notify = true});

  bool _instanceMayRemoved(ServerData server) => server?.inst == null || !server.inst.work;

  void _removeAllInput() {
    for (var server in _servers) if (!_instanceMayRemoved(server)) return;

    _removeAll();
    _indices.clear();
    if (_servers.isNotEmpty) {
      for (var server in _servers) {
        server.reset();
        _removeInstance(server, notify: false);
      }
      _servers.clear();
      notifyListeners();
    }
  }

  void _upgradeInput(ServerData oldServer, ServerData server) {
    final oldName = oldServer?.name;
    final index = indexOf(oldName);
    if (server == null || index == -1 || !_servers[index].upgrade(server..reset())) return;
    if (oldName != server.name) {
      _indices.remove(oldName);
      _rebuildIndex(start: index, length: index + 1);
    }
    _servers[index].saveServerData(index);
  }

  bool _addInput(ServerData server, {reset = true}) {
    if (server.name != '' && !contains(server.name)) {
      _add(server);
      _saveAll(start: _servers.length - 1);
      notifyListeners();
      return true;
    }
    if (reset) server.reset();
    return false;
  }

  void _addAlwaysInput(ServerData server) {
    if (!_addInput(server, reset: false)) {
      server.name = _newUniqueName(server.name);
      _addInput(server);
    }
  }

  void _add(ServerData server, {bool rebuild = true}) {
    _servers.add(server);
    if (rebuild) _rebuildIndex(start: _servers.length - 1);
  }

  void _removeInput(ServerData server, {returnServerCallback result}) {
    final name = server?.name;
    final index = indexOf(name);
    if (index > -1 && index < _servers.length && _instanceMayRemoved(server)) {
      server.reset();
      _removeInstance(server, notify: false);
      _removeByIndex(index);
      if (_servers.isNotEmpty) {
        removeServerData(_servers.length).then((_) => _saveAll(start: index));
      } else
        _removeAll(length: 1);
      if (result != null) result(server);
      notifyListeners();
    }
  }

  void _rebuildIndex({int start = 0, length}) {
    length ??= _servers.length;
    for (int i = start; i < length; i++) _indices[_servers[i].name] = i;
    assert(_indices.length == _servers.length);
  }

  void _removeByIndex(int index, {bool rebuild = true}) {
    _indices.remove(_servers[index].name);
    _servers.removeAt(index);
    if (rebuild) _rebuildIndex(start: index);
  }

  bool _insetIn(int index, ServerData server) {
    if (!contains(server.name) && server.name != '') {
      _insert(index, server);
      _saveAll(start: index);
      notifyListeners();
      return true;
    }
    return false;
  }

  void _insertAlwaysInput(int index, ServerData server) {
    if (index < 0) {
      index = 0;
    } else if (index > length) {
      index = length;
    }
    if (!_insetIn(index, server)) {
      server.name = _newUniqueName(server.name);
      _insetIn(index, server);
    }
  }

  String _newUniqueName(String oldName) {
    for (int p = 1; p < 9999999; p++) {
      final newName = '$oldName-$p';
      if (!contains(newName)) return newName;
    }
    throw new Exception('NEVER!');
  }

  void _insert(int index, ServerData server, {bool rebuild = true}) {
    _servers.insert(index, server);
    if (rebuild) _rebuildIndex(start: index);
  }

  void _relocationInput(int oldIndex, newIndex) {
    newIndex = newIndex >= _servers.length ? _servers.length - 1 : newIndex;
    if (_servers.length < 2 || oldIndex >= _servers.length || oldIndex < 0 || newIndex < 0 || oldIndex == newIndex)
      return;
    final item = _servers[oldIndex];
    // Не перестраиваем индексы, сделаем это потом
    _removeByIndex(oldIndex, rebuild: false);
    if (newIndex >= _servers.length)
      _add(item, rebuild: false);
    else
      _insert(newIndex, item, rebuild: false);

    int start = newIndex, length = oldIndex + 1;
    if (newIndex > oldIndex) {
      start = oldIndex;
      length = newIndex + 1;
    }
    debugPrint('* start=$start, length=$length');
    _rebuildIndex(start: start, length: length);
    _saveAll(start: start, length: length);
    notifyListeners();
  }

  _saveAll({int start = 0, length}) async {
    final p = await SharedPreferences.getInstance();
    if (length == null) {
      length = _servers.length;
      p.setInt(serverDataCount, length);
    }
    for (int i = start; i < length; i++) await _servers[i].saveServerData(i);
    debugPrint(' * _saveAll ${length - start}');
  }

  _restore() async {
    await _loadAll();
    await _greatResurrector();
    isLoaded = true;
    notifyListeners();
  }

  _greatResurrector();

  _loadAll() async {
    final p = await SharedPreferences.getInstance();
    final length = p.getInt(serverDataCount) ?? 0;
    for (int i = 0; i < length; i++) {
      ServerData value = await loadServerData(i);
      if (value != null && !contains(value.name)) {
        _servers.add(value);
        _indices[value.name] = _servers.length - 1;
      } else
        debugPrint(' **** LoadAll error on load $i');
    }
    if (_servers.length != length) _saveAll();
    debugPrint(' * LoadAll $length');
  }

  _removeAll({int start = 0, length}) async {
    final p = await SharedPreferences.getInstance();
    length ??= _servers.length;
    final newLength = _servers.length - (length - start);
    for (int i = start; i < length; i++) removeServerData(i);
    if (newLength > 0)
      await p.setInt(serverDataCount, newLength);
    else
      await p.remove(serverDataCount);
    debugPrint(' * _removeAll ${length - start}, new $newLength');
  }
}
