import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mdmt2_config/src/blocs/api_view.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart' hide Result;
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/widgets.dart';

class APIViewPage extends StatefulWidget {
  final TerminalControl control;
  final InstanceViewState view;
  final ServerData srv;
  final Function runCallback;

  APIViewPage(this.control, this.view, this.srv, this.runCallback, {Key key}) : super(key: key);

  @override
  _APIViewPageState createState() => _APIViewPageState();
}

class _APIViewPageState extends State<APIViewPage> {
  final infoPadding = const EdgeInsets.only(left: 10, right: 10, bottom: 20);
  final awaitTile = _awaitTile();

  ApiViewBLoC _bLoC;
  StreamSubscription<String> _subscription;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  bool _isConnected;
  ScrollController _logScroll;
  StreamSubscription<WorkingNotification> _stateStreamSubscription;

  @override
  void initState() {
    super.initState();
    _isConnected = widget.control.getStage == ConnectStage.work;
    _stateStreamSubscription = widget.control.stateStream.listen((_) {
      if ((widget.control.getStage == ConnectStage.work) != _isConnected) {
        setState(() => _isConnected = !_isConnected);
        if (_isConnected) _bLoC.refresh();
      }
    });
    _logScroll = ScrollController(keepScrollOffset: false);
    _bLoC = ApiViewBLoC(widget.control, widget.view)..start();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _subscription = widget.control.streamToads.listen((event) {
        debugPrint(event);
        return seeOkToast(null, event, scaffold: _scaffoldKey.currentState);
      });
      _logScroll.addListener(() {
        if (_logScroll.hasClients) widget.view.apiViewState.logScrollPosition = _logScroll.offset;
      });
    });
  }

  @override
  void dispose() {
    _stateStreamSubscription?.cancel();
    _subscription?.cancel();
    _bLoC?.dispose();
    _logScroll?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: reRunButton(widget.srv, widget.runCallback),
        ),
        key: _scaffoldKey,
        body: SafeArea(child: _body()),
      );

  Widget _body() => StreamBuilder<Result>(
      stream: _bLoC.result,
      builder: (context, snapshot) {
        if (snapshot.data?.mode == ResultMode.refresh) {
          _bLoC.start();
          return DummyWidget;
        }
        if (snapshot.hasError) return _refresh(_viewText('${snapshot.error}'));
        if (!_isConnected && snapshot.data == null) return _refresh(_viewText('Disconnected'));
        if (snapshot.data == null || snapshot.data.mode == ResultMode.await)
          return _awaitBody(context, snapshot.data?.data);
        return _refresh(_viewData(snapshot.data.data));
      });

  Widget _refresh(Widget child) => RefreshIndicator(child: child, onRefresh: () async => _bLoC.getAPIList());

  Widget _viewData(Map<String, EntryInfo> data) {
    WidgetsBinding.instance.addPostFrameCallback(
        (_) => _logScroll.hasClients ? _logScroll.jumpTo(widget.view.apiViewState.logScrollPosition) : null);
    data ??= {};
    final list = data.keys.toList(growable: false);
    return Scrollbar(
        child: ListView.builder(
            controller: _logScroll,
            itemCount: list.length,
            itemBuilder: (_, i) {
              if (i >= list.length) return null;
              final title = list[i];
              final body = data[title];
              return ValueListenableBuilder(
                  valueListenable: widget.view.apiViewState.getTileNotify(title),
                  builder: (_, expanded, __) => ExpansionTile(
                        initiallyExpanded: expanded,
                        title: Text('$title ${body == null ? ' *' : ''}'),
                        onExpansionChanged: (open) {
                          widget.view.apiViewState.setTileState(title, open);
                          if (open && body == null) _bLoC.getAPIInfo(title);
                        },
                        children: _apiInfo(body),
                      ));
            }));
  }

  List<Widget> _apiInfo(EntryInfo info) => [
        if (info == null) _apiInfoMsgEmpty() else _apiInfoMsg(info),
        if (info?.flags?.isNotEmpty == true)
          Container(
            padding: infoPadding,
            alignment: Alignment.centerRight,
            child: Text.rich(TextSpan(text: info.flags.join(', '), style: TextStyle(color: Colors.green))),
          )
      ];

  Widget _apiInfoMsgEmpty() => _isConnected ? awaitTile : _apiInfoMsg(EntryInfo('Disconnected', null, isError: true));

  Widget _apiInfoMsg(EntryInfo info) => Container(
        padding: infoPadding,
        alignment: Alignment.centerLeft,
        child: info.isError ? Text.rich(TextSpan(text: info.msg, style: TextStyle(color: Colors.red))) : Text(info.msg),
      );

  Widget _viewText(String text) => Stack(
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

  Widget _awaitBody(BuildContext context, Map<String, EntryInfo> data) => Stack(
        fit: StackFit.expand,
        children: <Widget>[
          (data?.isEmpty ?? true) ? DummyWidget : _viewData(data),
          Stack(
            children: <Widget>[
              Container(
                color: Theme.of(context).canvasColor.withOpacity(.4),
                constraints: BoxConstraints.expand(),
              ),
              Align(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[CircularProgressIndicator(), Text(''), Text('Loading...')],
                ),
              )
            ],
          )
        ],
      );

  static Widget _awaitTile() => Container(
        padding: EdgeInsets.symmetric(horizontal: 30),
        alignment: Alignment.center,
        height: 20,
        child: Container(
          height: 1,
          child: LinearProgressIndicator(),
        ),
      );
}
