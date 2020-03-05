import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _N {
  static const openOnRunning = 'ms_oor';
  static const autoReconnectAfterReboot = 'ms_arar';
  static const saveAppState = 'ms_sas';
}

class MiscSettings {
  // Открывать запущенный сервер
  bool _openOnRunning = false;
  // Переподключаться после ребута, сек. 0 - отключено.
  int _autoReconnectAfterReboot = 10;
  // Сохранять состояния инстансов на случай OOM.
  // Для применения нужно пересоздать инсты, логи хранятся в файлах (/cache/log/)
  bool _saveAppState = true;
  // Задержка всяких обновлений для уменьшения частоты перерисовки виджетов
  final throttleTime = Duration(milliseconds: 60);

  static final MiscSettings _instance = MiscSettings._();

  factory MiscSettings() => _instance;

  MiscSettings._() {
    _loadAll();
  }

  int get autoReconnectAfterReboot => _autoReconnectAfterReboot;
  set autoReconnectAfterReboot(int value) {
    if (value != _autoReconnectAfterReboot) {
      _autoReconnectAfterReboot = value;
      _saveInt(_N.autoReconnectAfterReboot, _autoReconnectAfterReboot);
    }
  }

  bool get openOnRunning => _openOnRunning;
  set openOnRunning(bool value) {
    if (value != _openOnRunning) {
      _openOnRunning = value;
      _saveBool(_N.openOnRunning, _openOnRunning);
    }
  }

  bool get saveAppState => _saveAppState;
  set saveAppState(bool value) {
    if (value != _saveAppState) {
      _saveAppState = value;
      _saveBool(_N.saveAppState, _saveAppState);
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
    _openOnRunning = p.getBool(_N.openOnRunning) ?? _openOnRunning;
    _autoReconnectAfterReboot = p.getInt(_N.autoReconnectAfterReboot) ?? _autoReconnectAfterReboot;
    _saveAppState = p.getBool(_N.saveAppState) ?? _saveAppState;
  }
}
