import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:native_state/native_state.dart';

class RootPage {
  final String type;
  final String name;
  RootPage(this.type, this.name);

  static RootPage get empty => RootPage(null, null);

  factory RootPage.fromString(String str) {
    if (str == null) return empty;
    final index = str.indexOf(':');
    if (index < 1 || index == str.length - 1) return empty;
    return RootPage(str.substring(0, index), str.substring(index + 1));
  }

  get isEmpty => type == null || name == null;

  @override
  String toString() => '$type:$name';
}

class NativeStates extends ChangeNotifier {
  static const _rootOpened = 'root_page';
  MiscSettings _misc;
  RootPage _rootPage;
  SavedStateData _data;

  NativeStates(this._misc) {
    _load();
  }

  bool get isLoaded => _data != null;

  SavedStateData child(String name, {bySetting = false}) {
    if (bySetting && !_misc.saveAppState.value) return null;
    return _data.child(name);
  }

  Future<void> pageOpen(RootPage page) => _data.putString(_rootOpened, page.toString());

  Future<bool> pageClose() => _data.remove(_rootOpened);

  RootPage pageRestore({bool peek = false}) {
    if (_rootPage.isEmpty || peek) return _rootPage;
    final _result = _rootPage;
    _rootPage = RootPage.empty;
    return _result;
  }

  _load() async {
    _data = await SavedStateData.restore();
    _rootPage = _misc.saveAppState.value ? RootPage.fromString(_data.getString(_rootOpened)) : RootPage.empty;
    notifyListeners();
  }

  @override
  void dispose() {
    _data?.clear();
    super.dispose();
  }
}
