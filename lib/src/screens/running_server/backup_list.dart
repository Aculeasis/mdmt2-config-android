import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:intl/intl.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/widgets.dart';

class _Controller {
  final InstanceViewState _view;
  final TerminalControl _control;
  StreamSubscription _subscription;

  final _timeout = Duration(seconds: 20);

  final updateCircle = ValueNotifier<bool>(true);
  final enableBackupManual = ValueNotifier<bool>(false);
  final enableRestore = ValueNotifier<bool>(false);
  final filename = ValueNotifier<String>('');
  final timeoutSignal = ChangeValueNotifier();

  bool _allowUpdate = false;
  bool isTimeout = false;
  bool isConnected = true;
  Timer _timer;

  _Controller(this._view, this._control) {
    updateCircle.addListener(() {
      _enableBackupManualSet();
      _enableUpdateSet();
      _enableRestoreSet();
    });
    filename.addListener(() {
      _enableRestoreSet();
    });
  }

  void _enableBackupManualSet() => enableBackupManual.value = isConnected &&
      !updateCircle.value &&
      !_view.buttons['terminal_stop'].value &&
      !_view.buttons['manual_backup'].value;

  void _enableUpdateSet() => _allowUpdate = isConnected && !updateCircle.value && !_view.buttons['terminal_stop'].value;

  void _enableRestoreSet() => enableRestore.value =
      isConnected && !updateCircle.value && filename.value != '' && !_view.buttons['terminal_stop'].value;

  void _terminalStop() {
    _enableBackupManualSet();
    _enableUpdateSet();
    _enableRestoreSet();
  }

  void _update() {
    _timer?.cancel();
    _control.executeMe('backup.list');
    updateCircle.value = true;
    isTimeout = false;
    _timer = Timer(_timeout, () {
      isTimeout = true;
      timeoutSignal.notifyListeners();
      updateCircle.value = false;
    });
  }

  void timerCancel() {
    _timer?.cancel();
    //FIXME: setState() or markNeedsBuild() called during build.
    WidgetsBinding.instance.addPostFrameCallback((_) => updateCircle.value = false);
  }

  void callRestore() => _control.executeMe('backup.restore', data: filename.value);
  void callBackup() => _control.executeMe('backup.manual');

  Future<void> refresh() async {
    if (!_allowUpdate) return;
    filename.value = '';
    _update();
    return null;
  }

  setFilename(String newFilename) {
    if (isConnected) filename.value = newFilename;
  }

  void initState() {
    _subscription = _control.stateStream.listen((_) {
      isConnected = _control.getStage == ConnectStage.controller;
      _enableBackupManualSet();
      _enableUpdateSet();
      _enableRestoreSet();
    });
    _view.buttons['terminal_stop'].addListener(_terminalStop);
    _view.buttons['manual_backup'].addListener(_enableBackupManualSet);
    _update();
  }

  void dispose() {
    _subscription?.cancel();
    _view.buttons['manual_backup'].removeListener(_enableBackupManualSet);
    _view.buttons['terminal_stop'].removeListener(_terminalStop);
    updateCircle.dispose();
    filename.dispose();
    _timer?.cancel();
  }
}

class BackupSelectsPage extends StatefulWidget {
  final TerminalControl control;
  final InstanceViewState view;

  BackupSelectsPage(this.control, this.view, {Key key}) : super(key: key);

  @override
  _BackupSelectsPageState createState() => _BackupSelectsPageState();
}

class _BackupSelectsPageState extends State<BackupSelectsPage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  StreamSubscription _subscription;
  _Controller controller;

  @override
  void initState() {
    super.initState();
    controller = _Controller(widget.view, widget.control);
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscription = widget.control.streamToads.listen((event) {
          debugPrint(event);
          return seeOkToast(null, event, scaffold: _scaffoldKey.currentState);
        }));
    controller.initState();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    controller.dispose();
    super.dispose();
  }

  Widget _buttonsBottom() => Container(
      width: MediaQuery.of(context).size.width,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          ValueListenableBuilder(
              valueListenable: controller.enableBackupManual,
              builder: (_, enabled, __) {
                return FlatButton(child: Text('Backup'), onPressed: enabled ? controller.callBackup : null);
              }),
          _buttonCancelRestore()
        ],
      ));

  Widget _buttonCancelRestore() => ButtonBar(
        children: <Widget>[
          FlatButton(
            child: Text('Cancel'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ValueListenableBuilder(
              valueListenable: controller.enableRestore,
              builder: (_, enabled, __) => FlatButton(
                    child: Text('Restore'),
                    onPressed: enabled
                        ? () {
                            controller.callRestore();
                            Navigator.of(context).pop();
                          }
                        : null,
                  ))
        ],
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      key: _scaffoldKey,
      persistentFooterButtons: <Widget>[_buttonsBottom()],
      appBar: AppBar(
        leading: SizedBox(),
        title: Text('Backups'),
      ),
      body: _body(),
    ));
  }

  Widget _body() {
    final emptyBox = SizedBox();
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        StreamBuilder(
            initialData: null,
            stream: widget.control.streamBackupList,
            builder: (_, AsyncSnapshot<List<BackupLine>> snapshot) => ValueListenableBuilder(
                valueListenable: controller.timeoutSignal,
                builder: (_, __, ___) => RefreshIndicator(
                      child: _view(snapshot),
                      onRefresh: controller.refresh,
                      notificationPredicate: (v) => controller.isConnected && v.depth == 0,
                    ))),
        ValueListenableBuilder(
          valueListenable: controller.updateCircle,
          builder: (_, isUpdated, child) => isUpdated ? child : emptyBox,
          child: _await(context),
        )
      ],
    );
  }

  Widget _view(AsyncSnapshot<List<BackupLine>> snapshot) {
    if (controller.isTimeout) return _text('Timeout');
    if (snapshot.connectionState == ConnectionState.waiting) return _text('Loading...');

    if (snapshot.hasError) {
      controller.timerCancel();
      return _text('${snapshot.error}');
    }
    if (snapshot.connectionState == ConnectionState.active) {
      controller.timerCancel();
      return snapshot.data == null ? _text('Transfer error') : _list(snapshot.data);
    }
    controller.timerCancel();
    return _text('Internal error: ${snapshot.connectionState}');
  }

  Widget _await(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Container(
            color: Theme.of(context).canvasColor.withOpacity(.4),
            constraints: BoxConstraints.expand(),
            child: Text('')),
        Align(
          alignment: Alignment.bottomCenter,
          child: LinearProgressIndicator(),
        )
      ],
    );
  }

  Widget _text(String text) {
    return Stack(
      fit: StackFit.expand,
      children: <Widget>[
        Center(
          child: Text(
            text,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        ListView()
      ],
    );
  }

  Widget _list(List<BackupLine> backups) {
    return ValueListenableBuilder(
      valueListenable: controller.filename,
      builder: (_, selected, __) => ListView.builder(
          itemCount: backups.length,
          shrinkWrap: true,
          itemBuilder: (_, index) {
            if (index >= backups.length) return null;
            return RadioListTile<String>(
                value: backups[index].filename,
                title: Text(DateFormat('yyyy.MM.dd HH:mm:ss.SSS').format(backups[index].time)),
                subtitle: Text(backups[index].filename),
                groupValue: selected,
                onChanged: controller.isConnected ? controller.setFilename : (_) {});
          }),
    );
  }
}
