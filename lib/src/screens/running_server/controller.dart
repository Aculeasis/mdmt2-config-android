import 'dart:async';

import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/dialogs.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/screens/running_server/api_view.dart';
import 'package:mdmt2_config/src/screens/running_server/backup_list.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/widgets.dart';

class ControllerView extends StatefulWidget {
  final TerminalControl control;
  final InstanceViewState view;
  final ServerData srv;
  final Function runCallback;

  ControllerView(this.control, this.view, this.srv, this.runCallback, {Key key}) : super(key: key);

  @override
  _ControllerViewState createState() => _ControllerViewState();
}

class _ControllerViewState extends State<ControllerView> {
  final _subscriptions = <String, StreamSubscription<void>>{};
  bool _isConnected;

  @override
  void dispose() {
    for (var subscription in _subscriptions.values) subscription.cancel();
    _subscriptions.clear();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _isConnected = widget.control.getStage == ConnectStage.work;
    _subscriptions['toads'] = widget.control.streamToads.listen((event) => seeOkToast(context, event));
    _subscriptions['connected'] = widget.control.stateStream.listen((_) {
      final isConnected = widget.control.getStage == ConnectStage.work;
      if (isConnected != _isConnected) {
        setState(() => _isConnected = isConnected);
      }
    });
  }

  Future<void> _openPage(BuildContext context, String page) async {
    Widget target;
    if (page == 'backup') {
      target = BackupSelectsPage(widget.control, widget.view);
    } else if (page == 'info') {
      target = APIViewPage(widget.control, widget.view, widget.srv, widget.runCallback);
    } else {
      throw NullThrownError();
    }
    _subscriptions.remove('toads')?.cancel();
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => target));
    _subscriptions['toads'] = widget.control.streamToads.listen((event) => seeOkToast(context, event));
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: widget.control.reconnect.isActive,
      builder: (context, restarting, child) {
        if (!_isConnected && restarting)
          return Stack(
            fit: StackFit.expand,
            children: <Widget>[
              child,
              Align(
                alignment: Alignment.center,
                child: CircularProgressIndicator(),
              )
            ],
          );
        return child;
      },
      child: _main(context),
    );
  }

  Widget _main(BuildContext context) {
    return SingleChildScrollView(
      child: SafeArea(
          child: Container(
        margin: EdgeInsets.fromLTRB(5, 5, 5, 15),
        child: Column(
          children: <Widget>[
            divider('Status'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: terminalStatusLine(),
            ),
            divider('Creating models'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: creatingModels2Line(context),
            ),
            divider('TTS/ASK/VOICE'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 5),
              child: FieldForTAVLine(widget.view, (cmd, msg) => widget.control.executeMe(cmd, data: msg), _isConnected),
            ),
            divider('Music'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: musicLine(),
            ),
            divider('Maintenance'),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 15),
              child: maintenance2Line(),
            ),
          ],
        ),
      )),
    );
  }

  Widget maintenance2Line() {
    return Table(
      columnWidths: {for (int i = 1; i < 6; i += 2) i: FractionColumnWidth(0.02)},
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [maintenanceLine1(), maintenanceLine2()],
    );
  }

  TableRow maintenanceLine1() {
    return TableRow(children: [
      RaisedButton(
        padding: EdgeInsets.all(2),
        onPressed: _isConnected ? () => widget.control.executeMe('ping') : null,
        child: Text('Ping'),
      ),
      DummyWidget,
      ValueListenableBuilder(
          valueListenable: widget.view.buttons['terminal_stop'],
          builder: (_, busy, __) => RaisedButton(
                padding: EdgeInsets.all(2),
                onPressed: _isConnected && !busy
                    ? () => dialogYesNo(context, 'Reload server?', '', 'Reload', 'Cancel').then((value) {
                          if (value) widget.control.executeMe('maintenance.reload');
                        })
                    : null,
                child: Text('Reload'),
              )),
      DummyWidget,
      ValueListenableBuilder(
          valueListenable: widget.view.buttons['terminal_stop'],
          builder: (_, busy, __) => RaisedButton(
                padding: EdgeInsets.all(2),
                onPressed: _isConnected && !busy
                    ? () => dialogYesNo(context, 'Stop server?', '', 'Stop', 'Cancel').then((value) {
                          if (value) widget.control.executeMe('maintenance.stop');
                        })
                    : null,
                child: Text('Stop'),
              )),
      DummyWidget,
      _radioButton(widget.view.listenerOnOff, label: 'Listen', callBack: () => widget.control.executeMe('listener')),
    ]);
  }

  TableRow maintenanceLine2() {
    return TableRow(children: [
      ValueListenableBuilder(
          valueListenable: widget.view.buttons['manual_backup'],
          builder: (_, busy, __) => RaisedButton(
                padding: EdgeInsets.all(2),
                onPressed: _isConnected && !busy ? () => widget.control.executeMe('backup.manual') : null,
                child: Text('Backup'),
              )),
      DummyWidget,
      ValueListenableBuilder(
          valueListenable: widget.view.buttons['terminal_stop'],
          builder: (context, busy, __) => RaisedButton(
                padding: EdgeInsets.all(2),
                onPressed: _isConnected && !busy ? () => _openPage(context, 'backup') : null,
                child: Text('Restore*'),
              )),
      DummyWidget,
      RaisedButton(
        padding: EdgeInsets.all(2),
        onPressed: () => _openPage(context, 'info'),
        child: Text('API'),
      ),
      DummyWidget,
      _radioButton(widget.view.states['catchQryStatus'], label: 'QRY', callBack: () => widget.control.executeMe('qry')),
    ]);
  }

  Widget terminalStatusLine() {
    return Row(
      children: <Widget>[
        Text('Volume:'),
        Expanded(
            child: VolumeSlider(
          widget.view.volume,
          (newVal) => widget.control.executeMe('volume', data: newVal),
          enabled: _isConnected,
        )),
        talkStatus(),
        recordStatus()
      ],
    );
  }

  Widget talkStatus() {
    return ValueListenableBuilder(
        valueListenable: widget.view.buttons['talking'],
        builder: (_, value, __) {
          value &= _isConnected;
          return IconButton(
            constraints: BoxConstraints.tightFor(height: 26, width: 26),
            onPressed: value ? () {} : null,
            padding: EdgeInsets.zero,
            icon: Icon(value ? Icons.volume_up : Icons.volume_off),
          );
        });
  }

  Widget recordStatus() {
    return ValueListenableBuilder(
        valueListenable: widget.view.buttons['record'],
        builder: (_, value, __) {
          value &= _isConnected;
          return IconButton(
            constraints: BoxConstraints.tightFor(height: 26, width: 26),
            onPressed: value ? () {} : null,
            padding: EdgeInsets.zero,
            icon: Icon(value ? Icons.mic : Icons.mic_off),
          );
        });
  }

  Widget musicLine() {
    return ValueListenableBuilder<MusicStatus>(
        valueListenable: widget.view.musicStatus,
        builder: (_, status, __) {
          final enable = _isConnected && status != MusicStatus.error && status != MusicStatus.nope;
          String label;
          IconData icon;
          String cmd = 'pause';
          if (status == MusicStatus.play) {
            label = 'Puase';
            icon = Icons.pause;
          } else if (status == MusicStatus.pause) {
            label = 'Play';
            icon = Icons.play_arrow;
          } else if (status == MusicStatus.stop) {
            label = 'Replay';
            icon = Icons.replay;
            cmd = 'play';
          } else {
            icon = Icons.error;
            label = status.toString().split('.').last;
            label = label[0].toUpperCase() + label.substring(1);
          }
          final VisualDensity visualDensity = Theme.of(context).visualDensity;
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Container(
                constraints: visualDensity.effectiveConstraints(BoxConstraints(minWidth: 105.0)),
                child: RaisedButton.icon(
                    onPressed: enable ? () => widget.control.executeMe(cmd) : null,
                    icon: Icon(icon),
                    label: Text(label)),
              ),
              Expanded(
                child: VolumeSlider(
                  widget.view.musicVolume,
                  (newVal) => widget.control.executeMe('mvolume', data: newVal),
                  enabled: enable,
                ),
              ),
              Container(
                constraints: visualDensity.effectiveConstraints(BoxConstraints.tightFor(height: 36, width: 36)),
                child: RaisedButton(
                    onPressed: enable
                        ? () {
                            uriDialog(context, widget.view.states['musicURI'].value).then((value) {
                              if (value == null) return;
                              widget.view.states['musicURI'].value = value;
                              if (_isConnected) widget.control.executeMe('play', data: value);
                            });
                          }
                        : null,
                    child: Icon(Icons.replay),
                    padding: EdgeInsets.zero),
              )
            ],
          );
        });
  }

  Widget creatingModels2Line(BuildContext context) {
    return Table(
      columnWidths: {
        0: FractionColumnWidth(.18),
        2: FractionColumnWidth(.015),
        4: FractionColumnWidth(.16),
        5: FractionColumnWidth(.1)
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [makeModelLine(context), makeSampleLine()],
    );
  }

  TableRow makeModelLine(BuildContext context) {
    return TableRow(children: [
      Text('Model:'),
      ValueListenableBuilder(
          valueListenable: widget.view.buttons['model_compile'],
          builder: (_, busy, __) => RaisedButton(
              child: Text('Compile'),
              onPressed: _isConnected && !busy
                  ? () => widget.control.executeMe('rec', data: 'compile_${widget.view.states['modelIndex'].value}_0')
                  : null)),
      DummyWidget,
      RaisedButton(
          child: Text('Remove'),
          onPressed: _isConnected
              ? () => dialogYesNo(
                          context, 'Remove model #${widget.view.states['modelIndex'].value}?', '', 'Remove', 'Cancel')
                      .then((value) {
                    if (value) widget.control.executeMe('rec', data: 'del_${widget.view.states['modelIndex'].value}_0');
                  })
              : null),
      DummyWidget,
      dropdownButtonInt(widget.view.states['modelIndex'], 6)
    ]);
  }

  TableRow makeSampleLine() {
    String target() => '${widget.view.states['modelIndex'].value}_${widget.view.states['sampleIndex'].value}';
    return TableRow(children: [
      Text('Sample:'),
      ValueListenableBuilder(
          valueListenable: widget.view.buttons['sample_record'],
          builder: (_, busy, __) => RaisedButton(
              child: Text('Record'),
              onPressed:
                  _isConnected && !busy ? () => widget.control.executeMe('rec', data: 'rec_${target()}') : null)),
      DummyWidget,
      RaisedButton(
          child: Text('Play'),
          onPressed: _isConnected ? () => widget.control.executeMe('rec', data: 'play_${target()}') : null),
      DummyWidget,
      dropdownButtonInt(widget.view.states['sampleIndex'], 3),
    ]);
  }

  Widget _radioButton(ValueNotifier<bool> valueListenable, {Function callBack, String label}) {
    final themeOff = Theme.of(context);
    final themeOn = themeOff.copyWith(disabledColor: themeOff.toggleableActiveColor);
    return ValueListenableBuilder(
        valueListenable: valueListenable,
        child: Padding(
          padding: EdgeInsets.only(right: 10),
          child: Text(label),
        ),
        builder: (_, isCatch, child) => RaisedButton(
              padding: EdgeInsets.all(2),
              onPressed: _isConnected ? callBack : null,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  child,
                  SizedBox(
                    width: 10,
                    height: 10,
                    child: Theme(
                      data: isCatch ? themeOn : themeOff,
                      child: Radio<bool>(
                        value: isCatch,
                        groupValue: true,
                        onChanged: null,
                      ),
                    ),
                  )
                ],
              ),
            ));
  }
}

class VolumeSlider extends StatefulWidget {
  final ValueNotifier<int> position;
  final void Function(int) onChange;
  final bool enabled;

  VolumeSlider(this.position, this.onChange, {this.enabled = false, Key key}) : super(key: key);

  @override
  _VolumeSliderState createState() => _VolumeSliderState();
}

class _VolumeSliderState extends State<VolumeSlider> {
  // Отправляем с задержкой т.е. слайдер глючный и может выдать изменение сразу после начала использования
  static const throttleToSend = Duration(milliseconds: 200);
  Timer toSendTimer;
  double position;

  @override
  void initState() {
    super.initState();
    _rebuild();
    widget.position.addListener(_rebuild);
  }

  @override
  void dispose() {
    toSendTimer?.cancel();
    widget.position.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() {
    setState(() {
      position = widget.position.value.toDouble();
      if (position < 0)
        position = 0;
      else if (position > 100) position = 100;
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.enabled && widget.position.value >= 0 && widget.position.value <= 100;
    return Slider(
      value: position,
      onChanged: enabled
          ? (newValue) {
              toSendTimer?.cancel();
              if ((position - newValue).abs() < 1.0) return;
              setState(() => position = newValue);
            }
          : null,
      max: 100,
      min: 0,
      divisions: 100,
      label: '${position.round()}',
      onChangeStart: (_) => toSendTimer?.cancel(),
      onChangeEnd: (newValue) {
        toSendTimer?.cancel();
        if ((position - widget.position.value).abs() < 1.0) return;
        toSendTimer = Timer(throttleToSend, () {
          widget.onChange(newValue.truncate());
        });
      },
    );
  }
}

Widget divider(String text, {rightFlex = 10}) => Padding(
      padding: EdgeInsets.only(top: 15, bottom: 5),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Divider(),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              text,
            ),
          ),
          Expanded(flex: rightFlex, child: Divider())
        ],
      ),
    );

Widget dropdownButtonInt(ValueNotifier<int> value, int count) {
  return ValueListenableBuilder(
      valueListenable: value,
      builder: (_, _value, __) => DropdownButton<int>(
          autofocus: true,
          isExpanded: true,
          isDense: true,
          value: _value,
          items: [
            for (int i = 1; i <= count; i++)
              DropdownMenuItem(
                child: Text('$i'),
                value: i,
              )
          ],
          onChanged: (newVal) => value.value = newVal));
}

class FieldForTAVLine extends StatefulWidget {
  final InstanceViewState state;
  final Function(String cmd, String msg) onSend;
  final bool isConnected;
  FieldForTAVLine(this.state, this.onSend, this.isConnected);
  @override
  _FieldForTAVLineState createState() => _FieldForTAVLineState();
}

class _FieldForTAVLineState extends State<FieldForTAVLine> {
  TextEditingController _controller;
  ValueNotifier<String> _modeTAV;
  ValueNotifier<String> _textTAV;

  @override
  void initState() {
    super.initState();
    _modeTAV = widget.state.states['modeTAV'];
    _textTAV = widget.state.states['textTAV'];
    _controller = TextEditingController(text: _textTAV.value);
    _controller.addListener(() {
      if (_controller.text == _textTAV.value) return;
      final reBuild = _modeTAV.value != 'VOICE' && (_controller.text == '' || _textTAV.value == '');
      _textTAV.value = _controller.text;
      if (reBuild) setState(() {});
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  _send() {
    widget.onSend(_modeTAV.value, _textTAV.value);
    if (_modeTAV.value != 'VOICE') _controller.text = '';
  }

  @override
  Widget build(BuildContext context) {
    final toSend = !widget.isConnected || (_modeTAV.value != 'VOICE' && _textTAV.value == '') ? null : _send;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
            decoration: BoxDecoration(
              border: Border(
                  bottom: BorderSide(
                color: Color(0xFFBDBDBD),
                width: 0.0,
              )),
            ),
            child: Padding(
              padding: EdgeInsets.only(left: 5),
              child: DropdownButton<String>(
                underline: DummyWidget,
                items: <String>['TTS', 'ASK', 'VOICE'].map<DropdownMenuItem<String>>((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value.length < 5 ? '  $value' : value),
                  );
                }).toList(),
                value: _modeTAV.value,
                onChanged: (val) => setState(() => _modeTAV.value = val),
              ),
            )),
        Expanded(
          child: TextField(
            textInputAction: TextInputAction.send,
            maxLines: 1,
            onEditingComplete: toSend,
            autofocus: false,
            controller: _controller,
            enabled: _modeTAV.value != 'VOICE' && widget.isConnected,
          ),
        ),
        IconButton(
          onPressed: toSend,
          icon: Icon(toSend != null ? Icons.send : Icons.do_not_disturb_on),
        )
      ],
    );
  }
}
