import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/dialogs.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:mdmt2_config/src/themes_data.dart';
import 'package:mdmt2_config/src/widgets.dart';
import 'package:provider/provider.dart';

class SettingsPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final misc = Provider.of<MiscSettings>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text('Settings'),
      ),
      body: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            children: <Widget>[
              _themeSelector(context, misc.theme),
              switchListTileTap(
                misc.openOnRunning,
                title: Text('Open at Run'),
                subtitle: Text('Auto opening the server page at run'),
              ),
              ValueListenableBuilder(
                  valueListenable: misc.autoReconnectAfterReboot,
                  builder: (_, value, ___) => ListTile(
                        title: Text('Reconnect after reboot'),
                        subtitle: Text(value > 0 ? 'after $value seconds' : 'disabled'),
                        onTap: () => uIntDialog(context, misc.autoReconnectAfterReboot, 'Delay [0: disabled]'),
                      )),
              switchListTileTap(
                misc.saveAppState,
                title: Text('Restore APP state after OOM'),
                subtitle: Text('Clear all instances after change this setting'),
              ),
            ],
          )),
    );
  }

  Widget _themeSelector(BuildContext context, ValueNotifier<String> theme) {
    return ListTile(
      title: Text('Theme'),
      subtitle: Text('Selected: ${theme.value}'),
      onTap: () => dialogSelectOne(context, ThemesData.list,
          title: 'Choose theme',
          selected: theme.value,
          sets: {for (var item in ThemesData.list) item: item}).then((value) => theme.value = value ?? theme.value),
    );
  }
}
