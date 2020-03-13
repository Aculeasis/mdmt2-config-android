import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mdmt2_config/src/blocs/api_view.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/widgets.dart';
import 'package:uuid/uuid.dart';

class APIViewPage extends StatefulWidget {
  final TerminalControl control;
  final InstanceViewState view;

  APIViewPage(this.control, this.view, {Key key}) : super(key: key);

  @override
  _APIViewPageState createState() => _APIViewPageState();
}

class _APIViewPageState extends State<APIViewPage> {
  ApiViewBLoC _bLoC;
  StreamSubscription<String> _subscription;
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  final _tileKeys = <String, PageStorageKey<String>>{};
  final _isConnected = ValueNotifier<bool>(false);
  bool _clearMeLater = false;
  final _uuid = Uuid();

  @override
  void initState() {
    super.initState();
    _bLoC = ApiViewBLoC(widget.control, widget.view);
    _isConnected.value = _bLoC.isConnected;
    WidgetsBinding.instance.addPostFrameCallback((_) => _subscription = widget.control.streamToads.listen((event) {
          debugPrint(event);
          return seeOkToast(null, event, scaffold: _scaffoldKey.currentState);
        }));
    _bLoC.start();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _bLoC?.dispose();
    _isConnected.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      key: _scaffoldKey,
      body: SafeArea(child: _body()),
    );
  }

  Widget _body() {
    return StreamBuilder<Result>(
        stream: _bLoC.result,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            _tileKeys.clear();
            return _refresh(_viewText('${snapshot.error}'));
          }
          if (!_bLoC.isConnected && snapshot.data == null) return _refresh(_viewText('Disconnected'));
          if (snapshot.data == null || snapshot.data?.mode == ResultMode.await) {
            _clearMeLater = _clearMeLater || snapshot.data?.mode == ResultMode.await;
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                (snapshot.data?.data?.isEmpty ?? true) ? DummyWidget : _viewData(snapshot.data?.data),
                _awaitBody(context)
              ],
            );
          }
          if (_clearMeLater) {
            _clearMeLater = false;
            _tileKeys.clear();
          }
          return _refresh(_viewData(snapshot.data?.data));
        });
  }

  Widget _refresh(Widget child) => RefreshIndicator(child: child, onRefresh: () async => _bLoC.getAPIList());

  Widget _viewData(Map<String, EntryInfo> data) {
    data ??= {};
    final list = data.keys.toList(growable: false);
    final empty = Container(
      padding: EdgeInsets.symmetric(horizontal: 30),
      alignment: Alignment.center,
      height: 20,
      child: Container(
        height: 1,
        child: LinearProgressIndicator(),
      ),
    );
    return Scrollbar(
        child: ListView.builder(
            itemCount: list.length,
            itemBuilder: (_, i) {
              if (i >= list.length) return null;
              final title = list[i];
              final body = data[title];
              return ExpansionTile(
                key: (_tileKeys[title] = _tileKeys[title] ?? PageStorageKey<String>(_uuid.v4())),
                title: Text(title),
                onExpansionChanged: (open) {
                  _isConnected.value = _bLoC.isConnected;
                  if (open && body == null) _bLoC.getAPIInfo(title);
                },
                children: [if (body == null) _apiInfoEmpty(empty) else ..._apiInfo(body)],
              );
            }));
  }

  Widget _apiInfoEmpty(Widget empty) {
    final not = ValueNotifier<bool>(false);
    return ValueListenableBuilder(
        valueListenable: not,
        builder: (_, isConnected, __) => isConnected
            ? empty
            : Container(
                padding: const EdgeInsets.only(left: 10, right: 10, bottom: 20),
                alignment: Alignment.centerLeft,
                child: Text.rich(TextSpan(text: 'Disconnected', style: TextStyle(color: Colors.red))),
              ));
  }

  List<Widget> _apiInfo(EntryInfo info) {
    const padding = const EdgeInsets.only(left: 10, right: 10, bottom: 20);
    return [
      Container(
        padding: padding,
        alignment: Alignment.centerLeft,
        child: info.isError ? Text.rich(TextSpan(text: info.msg, style: TextStyle(color: Colors.red))) : Text(info.msg),
      ),
      if (info.flags.isNotEmpty)
        Container(
          padding: padding,
          alignment: Alignment.centerRight,
          child: Text.rich(TextSpan(text: info.flags.join(', '), style: TextStyle(color: Colors.green))),
        )
    ];
  }

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

  Widget _awaitBody(BuildContext context) {
    return Stack(
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
    );
  }
}
