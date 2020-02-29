import 'package:shared_preferences/shared_preferences.dart';

class _Keys {
  static const openOnRunning = 'ms_oor';
  static const autoReconnectAfterReboot = 'arar';
}

class MiscSettings {
  // Открывать запущенный сервер
  bool _openOnRunning = false;
  // Переподключаться после ребута, сек. 0 - отключено.
  int _autoReconnectAfterReboot = 10;
  static final MiscSettings _instance = MiscSettings._();

  factory MiscSettings() => _instance;

  MiscSettings._() {
    _loadAll();
  }

  get autoReconnectAfterReboot => _autoReconnectAfterReboot;
  set autoReconnectAfterReboot(int value) {
    if (value != _autoReconnectAfterReboot) {
      _autoReconnectAfterReboot = value;
      _saveInt(_Keys.autoReconnectAfterReboot, _autoReconnectAfterReboot);
    }
  }

  get openOnRunning => _openOnRunning;
  set openOnRunning(bool value) {
    if (value != _openOnRunning) {
      _openOnRunning = value;
      _saveBool(_Keys.openOnRunning, _openOnRunning);
    }
  }

  _saveBool(String key, bool value) async {
    final p = await SharedPreferences.getInstance();
    p.setBool(key, value);
  }

  _saveInt(String key, int value) async {
    final p = await SharedPreferences.getInstance();
    p.setInt(key, value);
  }

  _loadAll() async {
    final p = await SharedPreferences.getInstance();
    _openOnRunning = p.getBool(_Keys.openOnRunning) ?? _openOnRunning;
    _autoReconnectAfterReboot = p.getInt(_Keys.autoReconnectAfterReboot) ?? _autoReconnectAfterReboot;
  }
}
