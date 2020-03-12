import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/native_states.dart';
import 'package:mdmt2_config/src/screens/home.dart';
import 'package:mdmt2_config/src/servers/servers_controller.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:provider/provider.dart';

void main() {
  const bool isProduction = bool.fromEnvironment('dart.vm.product');
  if (isProduction) {
    debugPrint = (String message, {int wrapWidth}) {};
  }
  runApp(
    MultiProvider(
      providers: [
        // Синглтон
        ChangeNotifierProvider<MiscSettings>(
          create: (_) => MiscSettings(),
          lazy: false,
        ),
        ChangeNotifierProvider<NativeStates>(
          create: (_) => NativeStates(),
          lazy: false,
        ),
        ChangeNotifierProvider<ServersController>(
          create: (context) =>
              ServersController(Provider.of<NativeStates>(context, listen: false).child('_servers_controller')),
          lazy: true,
        ),
      ],
      child: Consumer2<MiscSettings, NativeStates>(
          builder: (_, misc, states, __) => misc.isLoaded && states.isLoaded ? MyApp(misc, states) : DummyWidget),
    ),
  );
}

class MyApp extends StatefulWidget {
  final MiscSettings misc;
  final NativeStates states;
  MyApp(this.misc, this.states);

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  RootPage _page;

  @override
  void initState() {
    super.initState();
    _page = _setRootPage(widget.states);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
        valueListenable: widget.misc.theme,
        builder: (_, __, ___) => MaterialApp(
              theme: widget.misc.lightTheme,
              darkTheme: widget.misc.darkTheme,
              home: _page != null ? FakeHomePage(_page, _destroyFake) : HomePage(),
            ));
  }

  RootPage _setRootPage(NativeStates states) {
    // Если отрендерить HomePage а уже из нее восстановить экран, то это выглядит некрасиво.
    // Поэтому, если есть подходящий экран для восстановления будет открыта FakeHomePage
    // FakeHomePage откроет нужный экран, а когда он закроется занулит _page, кинет уведомление и дерево виджетов
    // перестроится как обычно
    // Ужасный изврат (
    final page = states.pageRestore(peek: true);
    if (!page.isEmpty && (page.type == 'settings' || page.type == 'instance')) {
      states.pageRestore();
      return page;
    }
    return null;
  }

  void _destroyFake() {
    _page = null;
    // ignore: invalid_use_of_visible_for_testing_member, invalid_use_of_protected_member
    widget.states.notifyListeners();
  }
}
