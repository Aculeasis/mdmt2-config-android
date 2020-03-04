import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/dialogs.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:mdmt2_config/src/settings/theme_settings.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/widgets.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final reconnectTile = ChangeValueNotifier();
    final settings = Provider.of<MiscSettings>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              _themeSelector(context),
              switchListTileTap(
                  activeColor: Theme.of(context).accentColor,
                  title: Text('Open at Run'),
                  subtitle: Text('Auto opening the server page at run'),
                  value: settings.openOnRunning,
                  onChanged: (newVal) => settings.openOnRunning = newVal),
              ValueListenableBuilder(
                  valueListenable: reconnectTile,
                  builder: (_, __, ___) => ListTile(
                        title: Text('Reconnect after reboot'),
                        subtitle: Text(settings.autoReconnectAfterReboot > 0
                            ? 'after ${settings.autoReconnectAfterReboot} seconds'
                            : 'disabled'),
                        onTap: () => uIntDialog(context, settings.autoReconnectAfterReboot, 'Delay [0: disabled]')
                            .then((value) {
                          if (value != null) {
                            settings.autoReconnectAfterReboot = value;
                            reconnectTile.notifyListeners();
                          }
                        }),
                      )),
            ],
          )),
    );
  }

  Widget _themeSelector(BuildContext context) {
    final theme = Provider.of<ThemeSettings>(context, listen: false);
    return ListTile(
      title: Text('Theme'),
      subtitle: Text('Selected: ${theme.theme}'),
      onTap: () => dialogSelectOne(context, ThemeSettings.list,
          title: 'Choose theme',
          selected: theme.theme,
          sets: {for (var item in ThemeSettings.list) item: item}).then((value) {
        debugPrint(' * Set theme: ${value.toString()}');
        theme.theme = value;
      }),
    );
  }
}
