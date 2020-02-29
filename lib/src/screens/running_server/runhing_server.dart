import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mdmt2_config/src/screens/running_server/controller.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/terminal/instances_controller.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';

class RunningServerPage extends StatefulWidget {
  final TerminalInstance instance;
  final LogStyle baseStyle;
  final ServerData server;

  RunningServerPage(this.instance, this.baseStyle, this.server, {Key key}) : super(key: key);

  @override
  _RunningServerPage createState() => _RunningServerPage();
}

class _RunningServerPage extends State<RunningServerPage> with SingleTickerProviderStateMixin {
  TabController _tabController;

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: widget.instance.view.pageIndex.value);
    _tabController.addListener(() {
      widget.instance.view.pageIndex.value = _tabController.index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: PreferredSize(
          preferredSize: Size.fromHeight(kToolbarHeight),
          child: AppBar(
            actions: _actions(),
            bottom: TabBar(controller: _tabController, tabs: <Widget>[
              Text('Log'),
              Text('Control'),
            ]),
          )),
      body: TabBarView(controller: _tabController, children: <Widget>[
        _oneTab(context),
        _twoTab(context),
      ]),
    );
  }

  _actions() {
    return [
      IconButton(
        icon: Icon(Icons.import_export),
        onPressed: () {
          final index = widget.instance.view.pageIndex.value;
          if (index == 0)
            widget.instance.view.logExpanded.value = !widget.instance.view.logExpanded.value;
          else if (index == 1) widget.instance.view.controlExpanded.value = !widget.instance.view.controlExpanded.value;
        },
      ),
    ];
  }

  Widget _oneTab(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          constraints: BoxConstraints.expand(),
          child: widget.instance?.log != null
              ? LogListView(widget.instance.log, widget.instance.view, widget.server)
              : _disabledBody(),
        ),
        ValueListenableBuilder(
            valueListenable: widget.instance.view.logExpanded,
            builder: (_, expanded, child) => expanded ? child : SizedBox(),
            child: Container(
              color: Colors.black.withOpacity(.5),
              child: widget.instance?.log != null ? _loggerSettings() : _disabledTop(),
            )),
      ],
    );
  }

  Widget _twoTab(BuildContext context) {
    return Column(
      children: <Widget>[
        ValueListenableBuilder(
          valueListenable: widget.instance.view.controlExpanded,
          builder: (_, expanded, child) => !expanded
              ? child
              : Expanded(
                  child: Container(
                  child:
                      widget.instance?.control != null ? _controllerSettings(widget.instance.control) : _disabledTop(),
                )),
          child: Expanded(
            child: widget.instance?.control != null
                ? ControllerView(widget.instance.control, widget.instance.view)
                : _disabledBody(),
          ),
        )
      ],
    );
  }

  Widget _loggerSettings() {
    return ValueListenableBuilder(
        valueListenable: widget.instance.view.style,
        builder: (context, _, __) => Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[_loggerSettings1(), _loggerSettings2(), Divider(), _loggerSettings3(), Divider()],
            ));
  }

  Widget _loggerSettings2() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceAround,
      verticalDirection: VerticalDirection.down,
      children: <Widget>[
        ValueListenableBuilder(
          valueListenable: widget.baseStyle,
          builder: (_, __, ___) => _loggerFlatButton(
              'Save',
              widget.instance.view.style.isEqual(widget.baseStyle)
                  ? null
                  : () {
                      widget.baseStyle
                        ..upgrade(widget.instance.view.style)
                        ..saveAll();
                    }),
        ),
        _loggerFlatButton(
            'Default',
            widget.instance.view.style.isEqual(LogStyle())
                ? null
                : () {
                    final def = LogStyle();
                    widget.instance.view.style.upgrade(def);
                  })
      ],
    );
  }

  Widget _loggerSettings3() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      verticalDirection: VerticalDirection.down,
      children: <Widget>[
        ValueListenableBuilder(
          valueListenable: widget.server.states.unreadMessages,
          builder: (_, __, ___) => _loggerFlatButton(
            'Clear log',
            widget.instance.log.isNotEmpty ? widget.instance.log.clear : null,
          ),
        )
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

  Widget _loggerSettings1() {
    String capitalize(LogLevel l) {
      final s = l.toString().split('.').last;
      return s[0].toUpperCase() + s.substring(1);
    }

    final style = widget.instance.view.style;
    return Row(children: [
      Expanded(
          child: PopupMenuButton(
              padding: EdgeInsets.zero,
              icon: _drawButton(
                context,
                'level: ${capitalize(style.lvl)}',
              ),
              itemBuilder: (context) => [
                    for (LogLevel l in LogLevel.values)
                      if (l != style.lvl)
                        PopupMenuItem(
                          child: Text(capitalize(l)),
                          value: l,
                        )
                  ],
              onSelected: (value) => style.lvl = value)),
      Expanded(
          child: PopupMenuButton(
              padding: EdgeInsets.zero,
              icon: _drawButton(context, 'font: ${style.fontSize}'),
              itemBuilder: (context) => [
                    for (int i = 2; i < 28; i += 4)
                      if (i != style.fontSize)
                        PopupMenuItem(
                          child: Text('$i'),
                          value: i,
                        )
                  ],
              onSelected: (value) => style.fontSize = value)),
      Expanded(
          child: PopupMenuButton(
              padding: EdgeInsets.zero,
              icon: _drawButton(context, 'time: ${style.timeFormat}'),
              itemBuilder: (context) => [
                    for (String l in timeFormats.keys)
                      if (l != style.timeFormat)
                        PopupMenuItem(
                          child: Text('$l'),
                          value: l,
                        )
                  ],
              onSelected: (value) => style.timeFormat = value)),
      Expanded(
          child: PopupMenuButton(
              padding: EdgeInsets.zero,
              icon: _drawButton(context, 'source: ${style.callLvl < LogStyle.callers.length ? style.callLvl : 'All'}'),
              itemBuilder: (context) => [
                    // С нуля
                    for (int i = 0; i < LogStyle.callers.length + 1; i++)
                      if (i != style.callLvl)
                        PopupMenuItem(
                          child: Text('${i < LogStyle.callers.length ? i : 'All'}'),
                          value: i,
                        )
                  ],
              onSelected: (value) => style.callLvl = value))
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
  final ServerData server;

  LogListView(this.log, this.view, this.server, {Key key}) : super(key: key);

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

    _logScroll = ScrollController(initialScrollOffset: widget.view.logScrollPosition, keepScrollOffset: false);
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.view.scrollCallback(_logScroll));
    _logScroll.addListener(() => widget.view.scrollCallback(_logScroll));
  }

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
                ValueListenableBuilder(
                    valueListenable: widget.view.style,
                    builder: (context, _, __) => ValueListenableBuilder(
                        valueListenable: widget.server.states.unreadMessages,
                        builder: (context, _, __) => Container(
                              margin: EdgeInsets.only(right: 5, left: 5, bottom: 10),
                              child: ListView.builder(
                                  controller: _logScroll,
                                  reverse: true,
                                  shrinkWrap: true,
                                  itemCount: widget.log.length,
                                  padding: EdgeInsets.zero,
                                  itemBuilder: (context, i) {
                                    if (i >= widget.log.length) return null;
                                    return _buildLogLineView(widget.view.style, widget.log[i]);
                                  }),
                            ))),
                Align(
                  alignment: Alignment.bottomRight,
                  child: ValueListenableBuilder<ButtonDisplaySignal>(
                    valueListenable: widget.view.backButton,
                    builder: (_, status, child) {
                      switch (status) {
                        case ButtonDisplaySignal.hide:
                          _animationController.reset();
                          return SizedBox();
                        case ButtonDisplaySignal.fadeIn:
                          _animationController.forward();
                          return child;
                        case ButtonDisplaySignal.fadeOut:
                          _animationController.reverse();
                          return child;
                      }
                      return SizedBox();
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
                )
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

Widget _disabledTop() {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: <Widget>[
      Divider(
        color: Colors.transparent,
      ),
      Center(child: Text('Disabled')),
      Divider(
        color: Colors.transparent,
      ),
    ],
  );
}

Widget _disabledBody({Color backgroundColor}) {
  return Container(
    color: backgroundColor,
    child: Center(
      child: Text('Disabled'),
    ),
  );
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
