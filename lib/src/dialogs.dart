import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:mdmt2_config/src/screens/finder_page.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/upnp/terminal_info.dart';
import 'package:mdmt2_config/src/widgets.dart';
import 'package:native_state/native_state.dart';
import 'package:package_info/package_info.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:validators/validators.dart';

Future<ServerData> serverFormDialog(
        BuildContext context, ServerData _srv, Function(String) contains, SavedStateData saved) async =>
    showDialog<ServerData>(context: context, builder: (_) => _ServerForm(_srv, saved, contains));

class _ServerForm extends StatefulWidget {
  final ServerData srv;
  final SavedStateData saved;
  final Function(String) contains;

  _ServerForm(this.srv, this.saved, this.contains);
  @override
  _ServerFormState createState() => _ServerFormState();
}

class _ServerFormState extends State<_ServerForm> {
  final _key = GlobalKey<FormState>();
  Map<String, TextEditingController> _ctlStr;
  Map<String, ValueNotifier<bool>> _ctlBool;

  @override
  void initState() {
    super.initState();
    _ctlStr = {
      'name': widget.srv.name,
      'ip': widget.srv.ip,
      'port': widget.srv.port.toString(),
      'token': widget.srv.token,
      'wsToken': widget.srv.wsToken
    }.map((key, value) => MapEntry(key, TextEditingController(text: widget.saved?.getString(key) ?? value)));
    _ctlBool = {
      'totpSalt': widget.srv.totpSalt,
    }.map((key, value) => MapEntry(key, ValueNotifier<bool>(widget.saved?.getBool(key) ?? value)));

    if (widget.saved != null) {
      for (var key in _ctlStr.keys) _ctlStr[key].addListener(() => widget.saved.putString(key, _ctlStr[key].text));
      for (var key in _ctlBool.keys) _ctlBool[key].addListener(() => widget.saved.putBool(key, _ctlBool[key].value));
    }
    if (widget.saved?.getBool('_finder') == true) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _finder());
    }
  }

  @override
  void dispose() {
    for (var ctl in _ctlStr.values) ctl.dispose();
    for (var ctl in _ctlBool.values) ctl.dispose();
    widget.saved?.clear();
    super.dispose();
  }

  void _finder() {
    widget.saved?.putBool('_finder', true);
    Navigator.of(context).push(MaterialPageRoute(builder: (context) => FinderPage())).then((value) {
      widget.saved?.remove('_finder');
      if (value != null && value is TerminalInfo) {
        _ctlStr['ip'].text = value.ip;
        _ctlStr['port'].text = value.port.toString();
        if (_ctlStr['name'].text == '') _ctlStr['name'].text = '${value.ip}:${value.port}';
      }
    });
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        actions: <Widget>[
          if (widget.srv.name == '')
            RaisedButton(
              onPressed: _finder,
              child: Text('Find'),
            ),
          if (widget.srv.name == '')
            SizedBox(
              height: 1,
              width: 20,
            ),
          RaisedButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          RaisedButton(
            child: Text('Save'),
            onPressed: () {
              if (_key.currentState.validate()) {
                Navigator.of(context).pop(ServerData(
                    name: _ctlStr['name'].text,
                    ip: _ctlStr['ip'].text,
                    port: int.parse(_ctlStr['port'].text),
                    token: _ctlStr['token'].text,
                    wsToken: _ctlStr['wsToken'].text,
                    totpSalt: _ctlBool['totpSalt'].value));
              }
            },
          ),
        ],
        content: Form(
          key: _key,
          child: SingleChildScrollView(
            child: Column(
              children: <Widget>[
                TextFormField(
                    decoration: InputDecoration(labelText: 'Name'),
                    controller: _ctlStr['name'],
                    autovalidate: true,
                    maxLength: 20,
                    validator: (v) {
                      if (v.isEmpty) return 'Enter server name';
                      // Имя не изменилось, в режиме редактирования
                      if (widget.srv.name != "" && widget.srv.name == v) return null;
                      if (widget.contains(v)) return 'Alredy present';
                      return null;
                    }),
                TextFormField(
                  textInputAction: TextInputAction.done,
                  keyboardType: TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(labelText: 'IP'),
                  controller: _ctlStr['ip'],
                  autovalidate: true,
                  validator: (v) {
                    if (v.isEmpty) return 'Enter server IP';
                    if (!isIP(v)) return 'Invalid internet address';
                    return null;
                  },
                ),
                TextFormField(
                    textInputAction: TextInputAction.done,
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Port'),
                    controller: _ctlStr['port'],
                    autovalidate: true,
                    validator: (v) {
                      final port = int.tryParse(v);
                      if (port == null) return 'Port is a numeric';
                      if (port < 1 || port > 65535) return 'Port must be in 1..65535';
                      return null;
                    }),
                textFormFieldPassword(
                  context,
                  decoration: InputDecoration(labelText: 'Token'),
                  controller: _ctlStr['token'],
                  isVisible: false,
                  validator: (v) => v == '' ? 'Token must be not empty' : null,
                ),
                switchListTileTap(
                  _ctlBool['totpSalt'],
                  contentPadding: EdgeInsets.zero,
                  title: Text('TOTP Salt'),
                ),
                textFormFieldPassword(
                  context,
                  decoration: InputDecoration(labelText: 'ws_token'),
                  controller: _ctlStr['wsToken'],
                ),
              ],
            ),
          ),
        ),
      );
}

Future<bool> dialogYesNo(BuildContext context, String title, msg, yes, no) {
  return showDialog(
      context: context,
      builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(msg),
            actions: <Widget>[
              FlatButton(onPressed: () => Navigator.of(context).pop(false), child: Text(no)),
              FlatButton(onPressed: () => Navigator.of(context).pop(true), child: Text(yes))
            ],
          ));
}

void showAbout(BuildContext context) async {
  const HomeURL = 'https://github.com/Aculeasis/mdmt2-config-android';
  final packageInfo = await PackageInfo.fromPlatform();
  EdgeInsets buttonPadding = ButtonTheme.of(context).padding;
  buttonPadding = buttonPadding.copyWith(left: .0);

  showAboutDialog(
      context: context,
      applicationIcon: FlutterLogo(),
      applicationName: packageInfo.appName,
      applicationLegalese: 'Aculeasis',
      applicationVersion: 'Version ${packageInfo.version}+${packageInfo.buildNumber}',
      children: [
        Container(
          alignment: Alignment.topLeft,
          padding: EdgeInsets.only(left: IconTheme.of(context).size + 24.0, right: 24.0, top: 24),
          child: FlatButton.icon(
              padding: buttonPadding,
              onPressed: () async {
                if (await canLaunch(HomeURL)) await launch(HomeURL);
              },
              icon: Icon(FontAwesomeIcons.github),
              label: Text(
                'Open GitHub',
                textAlign: TextAlign.center,
              )),
        ),
      ]);
}

Future<String> uriDialog(BuildContext context, String oldURI) async {
  final _controller = TextEditingController(text: oldURI);
  final key = GlobalKey<FormState>();
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      actions: <Widget>[
        RaisedButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        RaisedButton(
          child: Text('Send'),
          onPressed: () {
            Navigator.of(context).pop(_controller.text);
          },
        ),
      ],
      content: Form(
        key: key,
        child: TextFormField(
          decoration: InputDecoration(labelText: 'URI'),
          controller: _controller,
        ),
      ),
    ),
  );
}

Future<int> uIntDialog(BuildContext context, ValueNotifier<int> notify, String label) async {
  final _controller = TextEditingController(text: notify.value.toString());
  final key = GlobalKey<FormState>();
  return showDialog<int>(
    context: context,
    builder: (context) => AlertDialog(
      actions: <Widget>[
        RaisedButton(
          child: Text('Cancel'),
          onPressed: () => Navigator.of(context).pop(),
        ),
        RaisedButton(
          child: Text('Set'),
          onPressed: () {
            if (key.currentState.validate()) {
              notify.value = int.tryParse(_controller.text);
              Navigator.of(context).pop(notify.value);
            }
          },
        ),
      ],
      content: Form(
        key: key,
        child: TextFormField(
          textInputAction: TextInputAction.done,
          keyboardType: TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(labelText: label),
          controller: _controller,
          validator: (value) {
            final intValue = int.tryParse(value);
            if (intValue == null) return 'Must be unsigned integer';
            if (intValue < 0) return 'Must be greater than -1';
            return null;
          },
        ),
      ),
    ),
  );
}

Future<T> dialogSelectOne<T>(BuildContext context, List<String> items,
    {Map<String, T> sets, String title, T selected}) async {
  final children = items
      .map((text) => RadioListTile(
          value: sets != null ? sets[text] : null,
          groupValue: selected,
          title: Text(text),
          onChanged: (value) => value == null ? null : Navigator.of(context).pop(value == selected ? null : value)))
      .toList();
  return showDialog(
      context: context,
      builder: (context) => AlertDialog(
            contentPadding: EdgeInsets.symmetric(horizontal: 10),
            title: title != null ? Text(title) : null,
            content: Container(
                width: 0,
                child: ListView(
                  children: children,
                  shrinkWrap: true,
                )),
            actions: <Widget>[FlatButton(onPressed: () => Navigator.of(context).pop(), child: Text('Cancel'))],
          ));
}

Widget textFormFieldPassword(BuildContext context,
    {TextEditingController controller,
    bool isVisible = false,
    InputDecoration decoration,
    FormFieldValidator<String> validator}) {
  final _isVisible = ValueNotifier<bool>(isVisible);
  final iconTheme = IconTheme.of(context);
  Color iconColor;
  iconColor = iconTheme.color;
  iconColor = iconTheme.color.withOpacity(iconColor.opacity * .5);
  decoration = (decoration ?? InputDecoration())
      .copyWith(contentPadding: EdgeInsets.only(right: iconTheme.size * 2, top: 10, bottom: 10));
  return ValueListenableBuilder<bool>(
      valueListenable: _isVisible,
      builder: (_, isVisible, __) => Stack(
            alignment: Alignment.centerRight,
            children: <Widget>[
              TextFormField(
                controller: controller,
                obscureText: !isVisible,
                decoration: decoration,
                autovalidate: true,
                validator: (v) {
                  if (v.contains(' ')) return 'Don\'t use spaces!';
                  return validator == null ? null : validator(v);
                },
              ),
              IconButton(
                  color: iconColor,
                  icon: Icon(
                    isVisible ? Icons.visibility_off : Icons.visibility,
                  ),
                  onPressed: () => _isVisible.value = !isVisible),
            ],
          ));
}
