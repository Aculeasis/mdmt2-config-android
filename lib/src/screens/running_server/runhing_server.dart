import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/material.dart' hide CheckedPopupMenuItem;
import 'package:intl/intl.dart';
import 'package:mdmt2_config/copypastes/CheckedPopupMenuItem.dart' show CheckedPopupMenuItem;
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/screens/running_server/controller.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';
import 'package:mdmt2_config/src/terminal/terminal_instance.dart';
import 'package:mdmt2_config/src/widgets.dart';

class RunningServerPage extends StatefulWidget {
  final ServerData srv;
  final LogStyle baseStyle;
  final Function runCallback;

  RunningServerPage(this.srv, this.baseStyle, this.runCallback, {Key key}) : super(key: key);

  @override
  _RunningServerPage createState() => _RunningServerPage();
}

class _RunningServerPage extends State<RunningServerPage> with SingleTickerProviderStateMixin {
  static const WideScreenWidth = 700;
  static const MaxRightSideWidth = 400;

  TabController _tabController;

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  @override
  void initState() {
    super.initState();
    final view = widget.srv.inst.view;
    _tabController = TabController(length: 2, vsync: this, initialIndex: view.states['pageIndex'].value)
      ..addListener(() => view.states['pageIndex'].value = _tabController.index);
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    return MiscSettings().forWides.value && width >= WideScreenWidth
        ? _wideBody(context, width.truncate())
        : _body(context);
  }

  Widget _body(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: AppBar(
            titleSpacing: 0,
            title: reRunButton(widget.srv, widget.runCallback),
            actions: [_actions(widget.srv.inst.view)],
            bottom: TabBar(controller: _tabController, tabs: <Widget>[
              Text('Log'),
              Text('Control'),
            ]),
          )),
      body: TabBarView(controller: _tabController, children: <Widget>[
        _oneTab(context, widget.srv.inst),
        _twoTab(context, widget.srv.inst),
      ]),
    );
  }

  Widget _wideBody(BuildContext context, int width) {
    int rightFlex = width ~/ 2;
    rightFlex = rightFlex > MaxRightSideWidth ? MaxRightSideWidth : rightFlex;
    final leftFlex = width - rightFlex;
    debugPrint('left: $leftFlex, right: $rightFlex');
    final instance = widget.srv.inst;
    return Scaffold(
      body: ValueListenableBuilder(
        valueListenable: instance.view.states['pageIndex'],
        builder: (context, index, _) => Row(
          children: <Widget>[
            Expanded(flex: leftFlex, child: _leftSide(context, instance, index)),
            if (index == 1) Expanded(flex: rightFlex, child: _rightSide(context, instance))
          ],
        ),
      ),
    );
  }

  Widget _leftSide(BuildContext context, TerminalInstance instance, int index) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: reRunButton(widget.srv, widget.runCallback),
        actions: [
          IconButton(
              icon: Icon(index == 0 ? Icons.chevron_left : Icons.chevron_right),
              onPressed: () => _tabController.index = index == 0 ? 1 : 0),
          _actions(instance.view, index: 0)
        ],
      ),
      body: _oneTab(context, instance),
    );
  }

  Widget _rightSide(BuildContext context, TerminalInstance instance) {
    return Scaffold(
      appBar: AppBar(
        leading: DummyWidget,
        actions: [_actions(instance.view, index: 1)],
      ),
      body: _twoTab(context, instance),
    );
  }

  Widget _actions(InstanceViewState view, {int index}) {
    return IconButton(
      icon: Icon(Icons.import_export),
      onPressed: () {
        if ((index ?? view.states['pageIndex'].value) == 0)
          view.states['logExpanded'].value = !view.states['logExpanded'].value;
        else if (view.states['pageIndex'].value == 1)
          view.states['controlExpanded'].value = !view.states['controlExpanded'].value;
      },
    );
  }

  Widget _oneTab(BuildContext context, TerminalInstance instance) {
    if (instance == null) return DummyWidget;
    return Stack(
      children: <Widget>[
        Container(
          constraints: BoxConstraints.expand(),
          child: LogListView(instance.log, instance.view),
        ),
        ValueListenableBuilder(
            valueListenable: instance.view.states['logExpanded'],
            builder: (_, expanded, child) => expanded ? child : DummyWidget,
            child: Container(
              color: Colors.black.withOpacity(.5),
              child: _loggerSettings(instance.view, instance.log),
            )),
      ],
    );
  }

  Widget _twoTab(BuildContext context, TerminalInstance instance) {
    if (instance == null) return DummyWidget;
    return Stack(
      children: <Widget>[
        Container(
          constraints: BoxConstraints.expand(),
          child: ControllerView(instance.control, instance.view, widget.srv, widget.runCallback),
        ),
        ValueListenableBuilder(
            valueListenable: instance.view.states['controlExpanded'],
            builder: (_, expanded, child) => expanded ? child : DummyWidget,
            child: Container(
              color: Colors.black.withOpacity(.8),
              child: _controllerSettings(instance.control),
            )),
      ],
    );
  }

  Widget _loggerSettings(InstanceViewState view, Log log) {
    return ValueListenableBuilder(
        valueListenable: view.style,
        builder: (context, _, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                _loggerSettings1(view.style),
                _loggerSettings2(view.style),
                Divider(),
                _loggerSettings3(log),
                Divider()
              ],
            ));
  }

  Widget _loggerSettings2(LogStyle viewStyle) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      verticalDirection: VerticalDirection.down,
      children: <Widget>[
        ValueListenableBuilder(
          valueListenable: widget.baseStyle,
          builder: (_, __, ___) => _loggerFlatButton(
              'Save',
              viewStyle.isEqual(widget.baseStyle)
                  ? null
                  : () {
                      widget.baseStyle
                        ..upgrade(viewStyle)
                        ..saveAsBaseStyle();
                    }),
        ),
        ValueListenableBuilder(
            valueListenable: widget.baseStyle,
            builder: (_, __, ___) => _loggerFlatButton(
                'Reset', widget.baseStyle.isEqual(viewStyle) ? null : () => viewStyle.upgrade(widget.baseStyle))),
        _loggerFlatButton(
            'Default',
            viewStyle.isEqual(LogStyle())
                ? null
                : () {
                    final def = LogStyle();
                    viewStyle.upgrade(def);
                  })
      ],
    );
  }

  Widget _loggerSettings3(Log log) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      verticalDirection: VerticalDirection.down,
      children: <Widget>[
        StreamBuilder<ListQueue<LogLine>>(
            stream: log.actualLog,
            builder: (_, event) => _loggerFlatButton(
                  'Clear log',
                  event.data?.isNotEmpty == true ? log?.clear : null,
                )),
      ],
    );
  }

  Widget _loggerFlatButton(String text, Function onPress) {
    return FlatButton(
      padding: EdgeInsets.zero,
      color: Colors.deepPurpleAccent.withOpacity(.5),
      textColor: Colors.white,
      disabledTextColor: Colors.grey,
      onPressed: onPress,
      child: Text(text),
    );
  }

  Widget _loggerSettings1(LogStyle viewStyle) {
    Widget logLvlText(LogLevel l) {
      final s = l.toString().split('.').last;
      final head = s[0].toUpperCase();
      final body = s.substring(1);
      return Text.rich(TextSpan(children: [TextSpan(text: head, style: LogStyle.msg[l]), TextSpan(text: body)]));
    }

    String makeLvlLine() {
      String result = [
        for (var lvl in LogLevel.values) if (viewStyle.containsLvl(lvl)) lvl.toString().split('.').last[0].toUpperCase()
      ].join();
      if (result.isEmpty)
        result = 'Nope';
      else if (result.length == LogLevel.values.length) result = 'All';
      return result;
    }

    return Row(children: [
      Expanded(
          child: PopupMenuButton(
        padding: EdgeInsets.zero,
        icon: _drawButton(context, 'level: ${makeLvlLine()}'),
        itemBuilder: (_) => [
          for (var l in LogLevel.values)
            CheckedPopupMenuItem(
              child: logLvlText(l),
              checked: viewStyle.containsLvl(l),
              onTap: (value) => value ? viewStyle.addLvl(l) : viewStyle.delLvl(l),
            )
        ],
      )),
      Expanded(
          child: PopupMenuButton(
              padding: EdgeInsets.zero,
              icon: _drawButton(context, 'font: ${viewStyle.fontSize}'),
              itemBuilder: (context) => [
                    for (int i = 2; i < 28; i += 4)
                      if (i != viewStyle.fontSize)
                        PopupMenuItem(
                          child: Text('$i'),
                          value: i,
                        )
                  ],
              onSelected: (value) => viewStyle.fontSize = value)),
      Expanded(
          child: PopupMenuButton(
              padding: EdgeInsets.zero,
              icon: _drawButton(context, 'time: ${viewStyle.timeFormat}'),
              itemBuilder: (context) => [
                    for (String l in timeFormats.keys)
                      if (l != viewStyle.timeFormat)
                        PopupMenuItem(
                          child: Text('$l'),
                          value: l,
                        )
                  ],
              onSelected: (value) => viewStyle.timeFormat = value)),
      Expanded(
          child: PopupMenuButton(
              padding: EdgeInsets.zero,
              icon: _drawButton(
                  context, 'source: ${viewStyle.callLvl < LogStyle.callers.length ? viewStyle.callLvl : 'All'}'),
              itemBuilder: (context) => [
                    // С нуля
                    for (int i = 0; i < LogStyle.callers.length + 1; i++)
                      if (i != viewStyle.callLvl)
                        PopupMenuItem(
                          child: Text('${i < LogStyle.callers.length ? i : 'All'}'),
                          value: i,
                        )
                  ],
              onSelected: (value) => viewStyle.callLvl = value))
    ]);
  }

  Widget _controllerSettings(TerminalControl control) {
    return Center(
      child: Text('WIP'),
    );
  }
}

class LogListView extends StatefulWidget {
  final Log log;
  final InstanceViewState view;

  LogListView(this.log, this.view, {Key key}) : super(key: key);

  @override
  _LogListViewState createState() => _LogListViewState();
}

class _LogListViewState extends State<LogListView> with SingleTickerProviderStateMixin {
  ScrollController _logScroll;
  AnimationController _animationController;
  Animation<double> _animation;

  @override
  void dispose() {
    _logScroll.dispose();
    _animationController.stop(canceled: true);
    _animationController.dispose();
    widget.view.backButton.value = ButtonDisplaySignal.hide;
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
        vsync: this,
        duration: InstanceViewState.fadeInButtonTime,
        reverseDuration: InstanceViewState.fadeOutButtonTime);
    _animation = CurvedAnimation(parent: _animationController, curve: Curves.linear, reverseCurve: Curves.linear);

    _logScroll =
        ScrollController(initialScrollOffset: widget.view.states['logScrollPosition'].value, keepScrollOffset: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.view.scrollCallback(_logScroll));
    _logScroll.addListener(() => widget.view.scrollCallback(_logScroll));
  }

  Widget _newDayLine(Widget line, DateTime time) {
    final multiplier = widget.view.style.base.fontSize / 14;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Container(
          alignment: Alignment.center,
          child: Container(
            margin: EdgeInsets.only(top: 25 * multiplier, bottom: 10 * multiplier),
            padding: EdgeInsets.symmetric(horizontal: 14 * multiplier, vertical: 7 * multiplier),
            decoration: BoxDecoration(
                border: Border.all(),
                borderRadius: BorderRadius.circular(30),
                color: Theme.of(context).highlightColor.withOpacity(.3)),
            child: Text(
              DateFormat('MMMM d').format(time),
              style: widget.view.style.base,
              textScaleFactor: 1.2,
            ),
          ),
        ),
        line
      ],
    );
  }

  bool _timeUp(DateTime oldT, DateTime newT) {
    if (newT.year != oldT.year) return newT.year > oldT.year;
    if (newT.month != oldT.month) return newT.month > oldT.month;
    if (newT.day != oldT.day) return newT.day > oldT.day;
    return false;
  }

  Widget _logBody(ListQueue<LogLine> data) => ListView.builder(
      controller: _logScroll,
      reverse: true,
      shrinkWrap: true,
      itemCount: data.length,
      padding: EdgeInsets.zero,
      itemBuilder: (context, i) {
        if (i >= data.length) return null;
        final target = data.elementAt(i);
        Widget line = _buildLogLineView(widget.view.style, target);
        if (i + 1 == data.length || _timeUp(data.elementAt(i + 1).time, target.time))
          line = _newDayLine(line, target.time);
        return i == 0
            ? Padding(
                padding: EdgeInsets.only(bottom: 15),
                child: line,
              )
            : line;
      });

  Widget _backButton() => Align(
        alignment: Alignment.bottomRight,
        child: ValueListenableBuilder<ButtonDisplaySignal>(
          valueListenable: widget.view.backButton,
          builder: (_, status, child) {
            switch (status) {
              case ButtonDisplaySignal.hide:
                _animationController.reset();
                return DummyWidget;
              case ButtonDisplaySignal.fadeIn:
                _animationController.forward();
                return child;
              case ButtonDisplaySignal.fadeOut:
                _animationController.reverse();
                return child;
            }
            return DummyWidget;
          },
          child: Padding(
            padding: EdgeInsets.all(10),
            child: FadeTransition(
                opacity: _animation,
                child: FloatingActionButton(
                  backgroundColor: Theme.of(context).highlightColor,
                  foregroundColor: LogStyle.backgroundColor.withOpacity(.75),
                  onPressed: () => widget.view.scrollBack(_logScroll),
                  child: Transform.rotate(
                    angle: math.pi,
                    child: Icon(Icons.navigation),
                  ),
                )),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      color: LogStyle.backgroundColor,
      child: SafeArea(
        child: Scrollbar(
            controller: _logScroll,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 5),
                  child: StreamBuilder<ListQueue<LogLine>>(
                      stream: widget.log?.actualLog,
                      builder: (_, event) => event.connectionState == ConnectionState.active && event.data != null
                          ? ValueListenableBuilder(
                              valueListenable: widget.view.style, builder: (_, __, ___) => _logBody(event.data))
                          : DummyWidget),
                ),
                _backButton()
              ],
            )),
      ),
    );
  }

  Widget _buildLogLineView(LogStyle style, LogLine line) {
    final calls = <TextSpan>[
      for (int p = 0; p < line.callers.length && (style.callLvl == 3 || p < style.callLvl); p++)
        TextSpan(text: line.callers[p], style: LogStyle.callers[p] ?? LogStyle.callers[LogStyle.callers.length - 1]),
    ];
    //FIXME: Баг, бесконечно обновляется.
    //return SelectableText.rich(
    return RichText(
      text: TextSpan(style: style.base, children: <TextSpan>[
        if (style.timeFormat != 'None') ...[
          TextSpan(text: DateFormat(timeFormats[style.timeFormat]).format(line.time), style: LogStyle.time),
          TextSpan(text: ' '),
        ],
        ...[
          for (int i = 0; i < calls.length; i++) ...[calls[i], TextSpan(text: i < calls.length - 1 ? '->' : ': ')]
        ],
        TextSpan(text: line.msg, style: LogStyle.msg[line.lvl])
      ]),
    );
  }
}

Widget _drawButton(BuildContext context, String text) {
  return Container(
    padding: EdgeInsets.all(2),
    child: Text(
      text,
      style: TextStyle(color: Colors.white),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    ),
    decoration: BoxDecoration(border: Border(bottom: BorderSide(color: Colors.deepPurpleAccent, width: 3))),
  );
}
