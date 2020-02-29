import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/screens/home.dart';
import 'package:mdmt2_config/src/servers/servers_controller.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:mdmt2_config/src/settings/theme_settings.dart';
import 'package:mdmt2_config/src/terminal/instances_controller.dart';
import 'package:provider/provider.dart';

void main() {
  const bool isProduction = bool.fromEnvironment('dart.vm.product');
  if (isProduction) {
    debugPrint = (String message, {int wrapWidth}) {};
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeSettings>(
          create: (_) => ThemeSettings(),
          lazy: false,
        ),
        ChangeNotifierProvider<ServersController>(
          create: (_) => ServersController(),
          lazy: false,
        ),
        Provider<InstancesController>(
          create: (_) => InstancesController(),
          dispose: (_, val) => val.dispose(),
        ),
        // Синглтон
        Provider<MiscSettings>(
          create: (_) => MiscSettings(),
          lazy: false,
        )
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeSettings>(
        child: Container(),
        builder: (context, theme, child) => theme.isLoaded
            ? MaterialApp(
                theme: theme.lightTheme,
                darkTheme: theme.darkTheme,
                home: MainServersPage(),
              )
            : child);
  }
}
