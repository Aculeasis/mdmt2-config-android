import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mdmt2_config/src/screens/running_server/controller.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/settings/log_style.dart';
import 'package:mdmt2_config/src/terminal/instance_view_state.dart';
import 'package:mdmt2_config/src/terminal/log.dart';
import 'package:mdmt2_config/src/terminal/terminal_control.dart';

class RunningServerPage extends StatefulWidget {
  final ServerData srv;
  final LogStyle baseStyle;

  RunningServerPage(this.srv, this.baseStyle, {Key key}) : super(key: key);

  @override
  _RunningServerPage createState() => _RunningServerPage();
}

class _RunningServerPage extends State<RunningServerPage> with SingleTickerProviderStateMixin {
  TabController _tabController;

  @override
  void dispose() {
    super.dispose();
    _tabController.dispose();
    widget.srv.inst.lock -= 1;
  }

  @override
  void initState() {
    widget.srv.inst.lock += 1;
    super.initState();
    int initialIndex = widget.srv.inst.view.pageIndex.value;
    if (initialIndex == 0 && widget.srv.inst.logger == null)
      initialIndex = 1;
    else if (initialIndex == 1 && widget.srv.inst.control == null) initialIndex = 0;
    _tabController = TabController(length: 2, vsync: this, initialIndex: initialIndex);
    _tabController.addListener(() {
      widget.srv.inst.view.pageIndex.value = _tabController.index;
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
          final index = widget.srv.inst.view.pageIndex.value;
          if (index == 0)
            widget.srv.inst.view.logExpanded.value = !widget.srv.inst.view.logExpanded.value;
          else if (index == 1) widget.srv.inst.view.controlExpanded.value = !widget.srv.inst.view.controlExpanded.value;
        },
      ),
    ];
  }

  Widget _oneTab(BuildContext context) {
    return Stack(
      children: <Widget>[
        Container(
          constraints: BoxConstraints.expand(),
          child: widget.srv.inst?.log != null
              ? LogListView(widget.srv.inst.log, widget.srv.inst.view, widget.srv.states.unreadMessages)
              : _disabledBody(),
        ),
        ValueListenableBuilder(
            valueListenable: widget.srv.inst.view.logExpanded,
            builder: (_, expanded, child) => expanded ? child : SizedBox(),
            child: Container(
              color: Colors.black.withOpacity(.5),
              child: widget.srv.inst?.log != null ? _loggerSettings() : _disabledTop(),
            )),
      ],
    );
  }

  Widget _twoTab(BuildContext context) {
    return Column(
      children: <Widget>[
        ValueListenableBuilder(
          valueListenable: widget.srv.inst.view.controlExpanded,
          builder: (_, expanded, child) => !expanded
              ? child
              : Expanded(
                  child: Container(
                  child:
                      widget.srv.inst?.control != null ? _controllerSettings(widget.srv.inst.control) : _disabledTop(),
                )),
          child: Expanded(
            child: widget.srv.inst?.control != null
                ? ControllerView(widget.srv.inst.control, widget.srv.inst.view)
                : _disabledBody(),
          ),
        )
      ],
    );
  }

  Widget _loggerSettings() {
    return ValueListenableBuilder(
        valueListenable: widget.srv.inst.view.style,
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
              widget.srv.inst.view.style.isEqual(widget.baseStyle)
                  ? null
                  : () {
                      widget.baseStyle
                        ..upgrade(widget.srv.inst.view.style)
                        ..saveAll();
                    }),
        ),
        _loggerFlatButton(
            'Default',
            widget.srv.inst.view.style.isEqual(LogStyle())
                ? null
                : () {
                    final def = LogStyle();
                    widget.srv.inst.view.style.upgrade(def);
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
          valueListenable: widget.srv.states.unreadMessages,
          builder: (_, __, ___) => _loggerFlatButton(
            'Clear log',
            widget.srv.inst.log.isNotEmpty ? widget.srv.inst.log.clear : null,
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

    final style = widget.srv.inst.view.style;
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
  final ValueNotifier<int> unreadMessages;

  LogListView(this.log, this.view, this.unreadMessages, {Key key}) : super(key: key);

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
                        valueListenable: widget.unreadMessages,
                        builder: (context, _, __) => Container(
                              padding: EdgeInsets.symmetric(horizontal: 5),
                              child: ListView.builder(
                                  controller: _logScroll,
                                  reverse: true,
                                  shrinkWrap: true,
                                  itemCount: widget.log.length,
                                  padding: EdgeInsets.zero,
                                  itemBuilder: (context, i) {
                                    if (i >= widget.log.length) return null;
                                    final line = _buildLogLineView(widget.view.style, widget.log[i]);
                                    return i == 0
                                        ? Padding(
                                            padding: EdgeInsets.only(bottom: 15),
                                            child: line,
                                          )
                                        : line;
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
