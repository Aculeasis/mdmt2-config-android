import 'package:flutter/material.dart';

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
