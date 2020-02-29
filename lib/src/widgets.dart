import 'package:flutter/material.dart';

Widget switchListTileTap(
    {Color activeColor,
    EdgeInsetsGeometry contentPadding,
    Widget title,
    Widget subtitle,
    bool value = false,
    Function(bool) onChanged}) {
  final _value = ValueNotifier<bool>(value);
  return ValueListenableBuilder<bool>(
      valueListenable: _value,
      builder: (_, value, __) => SwitchListTile(
          activeColor: activeColor,
          contentPadding: contentPadding,
          title: title,
          subtitle: subtitle,
          value: value,
          onChanged: (newVal) {
            _value.value = newVal;
            if (onChanged != null) onChanged(newVal);
          }));
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
