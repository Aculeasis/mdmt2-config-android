import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/themes_data.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _N {
  static const openOnRunning = 'ms_oor';
  static const autoReconnectAfterReboot = 'ms_arar';
  static const saveAppState = 'ms_sas';
  static const theme = 'app_theme';
}

class MiscSettings extends ChangeNotifier {
  bool isLoaded = false;
  // Открывать запущенный сервер
  final openOnRunning = ValueNotifier<bool>(false);
  // Переподключаться после ребута, сек. 0 - отключено.
  final autoReconnectAfterReboot = ValueNotifier<int>(10);
  // Сохранять состояния инстансов на случай OOM.
  // Для применения нужно пересоздать инсты, логи хранятся в файлах (/cache/log/)
  final saveAppState = ValueNotifier<bool>(true);
  // Тема
  final theme = ValueNotifier<String>('Dark');
  // Задержка всяких обновлений для уменьшения частоты перерисовки виджетов
  final throttleTime = Duration(milliseconds: 60);

  static final MiscSettings _instance = MiscSettings._();

  factory MiscSettings() => _instance;

  MiscSettings._() {
    _loadAll();
  }

  ThemeData get lightTheme => ThemesData.lightTheme(theme.value);
  ThemeData get darkTheme => ThemesData.darkTheme(theme.value);

  _loadAll() async {
    final p = await SharedPreferences.getInstance();
    openOnRunning.value = p.getBool(_N.openOnRunning) ?? openOnRunning.value;
    autoReconnectAfterReboot.value = p.getInt(_N.autoReconnectAfterReboot) ?? autoReconnectAfterReboot.value;
    saveAppState.value = p.getBool(_N.saveAppState) ?? saveAppState.value;
    theme.value = p.get(_N.theme) ?? theme.value;

    openOnRunning.addListener(() => p.setBool(_N.openOnRunning, openOnRunning.value));
    autoReconnectAfterReboot.addListener(() => p.setInt(_N.autoReconnectAfterReboot, autoReconnectAfterReboot.value));
    saveAppState.addListener(() => p.setBool(_N.saveAppState, saveAppState.value));
    theme.addListener(() => p.setString(_N.theme, theme.value));

    isLoaded = true;
    notifyListeners();
  }
}
