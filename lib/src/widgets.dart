import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';

Widget switchListTileTap(
  ValueNotifier<bool> notify, {
  Color activeColor,
  EdgeInsetsGeometry contentPadding,
  Widget title,
  Widget subtitle,
}) {
  return ValueListenableBuilder<bool>(
      valueListenable: notify,
      builder: (_, value, __) => SwitchListTile(
          activeColor: activeColor,
          contentPadding: contentPadding,
          title: title,
          subtitle: subtitle,
          value: value,
          onChanged: (newVal) => notify.value = newVal));
}

seeOkToast(BuildContext context, String msg, {ScaffoldState scaffold}) {
  scaffold ??= Scaffold.of(context);
  scaffold.hideCurrentSnackBar();
  scaffold.showSnackBar(SnackBar(
    behavior: SnackBarBehavior.floating,
    content: Text(msg, textAlign: TextAlign.center),
    action: SnackBarAction(
      label: 'Ok',
      onPressed: () => scaffold.hideCurrentSnackBar(),
    ),
  ));
}

Widget reRunButton(ServerData server, Function runCallback) {
  return ValueListenableBuilder(
      valueListenable: server,
      builder: (_, __, ___) {
        return IconButton(
            icon: Icon(Icons.settings_backup_restore), onPressed: server.allowToRun ? runCallback : null);
      });
}
