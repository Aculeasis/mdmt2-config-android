import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:mdmt2_config/src/blocs/api_view.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart' hide Result;
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/widgets.dart';

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
  final _isConnected = ValueNotifier<bool>(false);
  ScrollController _logScroll;
  StreamSubscription<WorkingNotification> _stateStreamSubscription;

  @override
  void initState() {
    super.initState();
    _isConnected.value = widget.control.getStage == ConnectStage.work;
    _stateStreamSubscription =
        widget.control.stateStream.listen((_) => _isConnected.value = widget.control.getStage == ConnectStage.work);
    _logScroll =
        ScrollController(initialScrollOffset: widget.view.apiViewState.logScrollPosition, keepScrollOffset: false);
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
    _isConnected.dispose();
    _logScroll?.dispose();
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
            return _refresh(_viewText('${snapshot.error}'));
          }
          if (!_isConnected.value && snapshot.data == null) return _refresh(_viewText('Disconnected'));
          if (snapshot.data == null || snapshot.data?.mode == ResultMode.await) {
            return Stack(
              fit: StackFit.expand,
              children: <Widget>[
                (snapshot.data?.data?.isEmpty ?? true) ? DummyWidget : _viewData(snapshot.data?.data),
                _awaitBody(context)
              ],
            );
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
            controller: _logScroll,
            itemCount: list.length,
            itemBuilder: (_, i) {
              if (i >= list.length) return null;
              final title = list[i];
              final body = data[title];
              return ValueListenableBuilder(
                  valueListenable: widget.view.apiViewState.getTileNotify(title),
                  builder: (_, expanded, __) {
                    return ExpansionTile(
                      initiallyExpanded: expanded,
                      title: Text('$title ${body == null ? ' *' : ''}'),
                      onExpansionChanged: (open) {
                        if (_isConnected.value || body != null) widget.view.apiViewState.setTileState(title, open);
                        if (open && body == null) _bLoC.getAPIInfo(title);
                      },
                      children: [if (body == null) _apiInfoEmpty(empty) else ..._apiInfo(body)],
                    );
                  });
            }));
  }

  Widget _apiInfoEmpty(Widget empty) {
    return ValueListenableBuilder(
        valueListenable: _isConnected,
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
