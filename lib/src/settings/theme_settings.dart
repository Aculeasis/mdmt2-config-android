import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _lightTheme = ThemeData.light().copyWith(
    snackBarTheme:
        ThemeData.light().snackBarTheme.copyWith(backgroundColor: ColorScheme.light().onSurface.withOpacity(.6)));

final _darkTheme = ThemeData.dark().copyWith(
    snackBarTheme:
        ThemeData.dark().snackBarTheme.copyWith(backgroundColor: ColorScheme.dark().onSurface.withOpacity(.6)));

ThemeData _buildAmoledTheme() => _darkTheme.copyWith(
      toggleableActiveColor: Colors.purple[700],
      dividerColor: Colors.deepOrange,
      highlightColor: Colors.indigo.withOpacity(0.5),
      cardColor: Colors.grey[900],
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      primaryColor: Colors.black,
      accentColor: Colors.redAccent,
      dialogBackgroundColor: Colors.grey[900],
      backgroundColor: Colors.black,
      buttonTheme: _darkTheme.buttonTheme.copyWith(buttonColor: Colors.redAccent, textTheme: ButtonTextTheme.primary),
    );

ThemeData _buildAmoledTheme2() => _darkTheme.copyWith(
      toggleableActiveColor: Colors.teal[400],
      dividerColor: Colors.deepOrange[100],
      highlightColor: Colors.indigo[100].withOpacity(0.5),
      cardColor: Colors.grey[900],
      scaffoldBackgroundColor: Colors.black,
      canvasColor: Colors.black,
      primaryColor: Colors.black,
      accentColor: Colors.purple[200],
      dialogBackgroundColor: Colors.grey[900],
      backgroundColor: Colors.black,
      buttonTheme: _darkTheme.buttonTheme.copyWith(buttonColor: Colors.red[100], textTheme: ButtonTextTheme.primary),
    );

class ThemeSettings extends ChangeNotifier {
  static const _app_theme = 'app_theme';
  static final _themesMap = {
    'System': null,
    'Light': _lightTheme,
    'Dark': _darkTheme,
    'Amoled': _buildAmoledTheme(),
    'Amoled2': _buildAmoledTheme2(),
    'Pink': ThemeData(primarySwatch: Colors.pink),
  };
  String _theme = 'Dark';
  bool isLoaded = false;

  ThemeSettings() {
    _loadTheme();
  }

  set theme(String newTheme) {
    if (_setTheme(newTheme)) notifyListeners();
  }

  bool _setTheme(String newTheme) {
    if (_theme != newTheme && _themesMap.containsKey(newTheme)) {
      _theme = newTheme;
      _saveTheme();
      return true;
    }
    return false;
  }

  String get theme => _theme ?? 'System';
  ThemeData get lightTheme => _themesMap[_theme] ?? _themesMap['Light'];
  ThemeData get darkTheme => _themesMap[_theme] ?? _themesMap['Dark'];

  _loadTheme() async {
    SharedPreferences perf = await SharedPreferences.getInstance();
    _setTheme(perf.getString(_app_theme));
    isLoaded = true;
    notifyListeners();
  }

  _saveTheme() async {
    final p = await SharedPreferences.getInstance();
    p.setString(_app_theme, _theme);
  }

  static Iterable<String> get list => _themesMap.keys.toList();
}
