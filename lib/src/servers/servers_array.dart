import 'package:mdmt2_config/src/servers/server_data.dart';

class ServerArraySwap {
  final int start;
  final int length;
  ServerArraySwap(this.start, this.length);
}

class ServersArray {
  // Данные серверов, порядок важен
  final _servers = <ServerData>[];
  // Индексы, для быстрого поиска по имени.
  final _indices = <String, int>{};

  int get length {
    assert(_servers.length == _indices.length);
    return _servers.length;
  }

  bool get isNotEmpty => length > 0;
  bool get isEmpty => !isNotEmpty;
  ServerData operator [](int index) => _servers[index];
  Iterable<ServerData> get iterable => _servers;
  bool containsByObj(ServerData element) => contains(element.name);
  bool contains(String name) => _indices.containsKey(name);
  int indexOf(String name) => _indices[name] ?? -1;
  ServerData byName(String name) {
    final index = indexOf(name);
    return index != -1 ? _servers[index] : null;
  }

  void clear() {
    assert(_indices.length == _servers.length);
    _indices.clear();
    _servers.clear();
  }

  int upgrade(ServerData oldServer, ServerData server) {
    if ((server?.name ?? '') == '' || oldServer == null) return null;
    final oldName = oldServer.name;
    final index = indexOf(oldName);
    if (index == -1 ||
        (oldName != server.name && contains(server.name)) ||
        _servers[index] != oldServer ||
        !_servers[index].upgrade(server)) return null;
    if (oldName != server.name) {
      _indices.remove(oldName);
      _rebuildIndex(start: index, length: index + 1);
    }
    assert(_indices.length == _servers.length);
    return index;
  }

  int add(ServerData server) {
    if ((server?.name ?? '') == '' || contains(server.name)) return null;
    return _add(server);
  }

  int remove(ServerData server) {
    if ((server?.name ?? '') == '') return null;
    final name = server.name;
    final index = indexOf(name);
    assert(index < _servers.length);
    if (index < 0) return null;
    _removeByIndex(index);
    assert(_indices.length == _servers.length);
    return index;
  }

  int insert(int index, ServerData server) {
    if ((server?.name ?? '') == '' || contains(server.name)) return null;
    if (index < 0) {
      index = 0;
    } else if (index > length) {
      index = length;
    }
    _insert(index, server);
    assert(_indices.length == _servers.length);
    return index;
  }

  ServerArraySwap swap(int oldIndex, newIndex) {
    newIndex = newIndex >= _servers.length ? _servers.length - 1 : newIndex;
    if (_servers.length < 2 || oldIndex >= _servers.length || oldIndex < 0 || newIndex < 0 || oldIndex == newIndex)
      return null;
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
    _rebuildIndex(start: start, length: length);
    assert(_indices.length == _servers.length);
    return ServerArraySwap(start, length);
  }

  void build(Iterable<ServerData> iterable) {
    clear();
    _servers.addAll(iterable);
    _indices.addAll(Map.fromEntries([for (var value in _servers) MapEntry(value.name, value.position)]));
  }

  int _add(ServerData server, {bool rebuild = true}) {
    _servers.add(server);
    final index = _servers.length - 1;
    if (rebuild) _rebuildIndex(start: index);
    return index;
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

  void _insert(int index, ServerData server, {bool rebuild = true}) {
    _servers.insert(index, server);
    if (rebuild) _rebuildIndex(start: index);
  }
}
