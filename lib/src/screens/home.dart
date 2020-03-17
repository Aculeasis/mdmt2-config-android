import 'dart:async';

import 'package:flutter/cupertino.dart' as cupertino show CupertinoPageRoute;
import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/dialogs.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/native_states.dart';
import 'package:mdmt2_config/src/screens/running_server/runhing_server.dart';
import 'package:mdmt2_config/src/screens/settings.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/servers/servers_controller.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:provider/provider.dart';

enum ServerMenu { connect, edit, remove, view, stop, clone, clear }
enum MainMenu { addServer, removeAll, settings, About, stopAll, clearAll }

class HomePage extends StatelessWidget {
  void _undoToast(BuildContext context, String msg, Function() undo) {
    final scaffold = Scaffold.of(context);
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center),
      action: SnackBarAction(label: 'Undo!', onPressed: undo),
    ));
  }

  void _pageRestore(BuildContext context, ServersController servers) {
    final page = Provider.of<NativeStates>(context, listen: false).pageRestore();
    if (page.isEmpty) return;
    Function(void) target;
    if (page.type == 'add_server') {
      target = (_) => _openAddServerDialog(context, servers);
    } else if (page.type == 'edit_server') {
      target = (_) => _openEditServerDialog(context, servers.byName(page.name), servers);
    }
    if (target != null) WidgetsBinding.instance.addPostFrameCallback(target);
  }

  Future<void> _openAddServerDialog(BuildContext context, ServersController servers) async {
    final states = Provider.of<NativeStates>(context, listen: false);
    states.pageOpen(RootPage('add_server', 'add_server'));
    final value = await serverFormDialog(
        context, ServerData(), servers.contains, states.child('_server_dialog', bySetting: true));
    states.pageClose();
    if (value != null) servers.add(value);
  }

  Future<void> _openEditServerDialog(BuildContext context, ServerData server, ServersController servers) async {
    if (server == null) return;
    final states = Provider.of<NativeStates>(context, listen: false);
    states.pageOpen(RootPage('edit_server', server.name));
    final value =
        await serverFormDialog(context, server, servers.contains, states.child('_server_dialog', bySetting: true));
    states.pageClose();
    if (value != null) servers.upgrade(server, value);
  }

  Widget _buildServersView(BuildContext context, ServersController servers) {
    return ReorderableListView(
      padding: EdgeInsets.only(top: 10),
      children: <Widget>[
        if (servers.length > 0)
          for (var server in servers.loop)
            ValueListenableBuilder(
                key: ObjectKey(server),
                valueListenable: server,
                builder: (context, __, _) => _buildRow(context, servers, server))
        else
          ListTile(
            key: UniqueKey(),
            leading: Icon(Icons.add),
            trailing: Icon(Icons.add),
            title: Text(
              'Add new server',
              textAlign: TextAlign.center,
            ),
            onTap: () => _openAddServerDialog(context, servers),
          )
      ],
      onReorder: (oldIndex, newIndex) {
        debugPrint('* old=$oldIndex, new=$newIndex');
        servers.relocation(oldIndex, newIndex);
      },
    );
  }

  Widget _buildRow(BuildContext context, ServersController servers, ServerData server) {
    void openPageCallback(ServerData _server) {
      if (Provider.of<MiscSettings>(context, listen: false).openOnRunning.value)
        _openInstancePage(context, _server, servers);
    }

    return ListTile(
      leading: _serverIcon(context, server),
      title: Text('${server.name}', maxLines: 1),
      onTap: () => server.inst != null ? _openInstancePage(context, server, servers) : null,
      subtitle: Text(server.inst?.subtitle ?? '', maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          if (server.allowToRun)
            PopupMenuItem(
              child: Row(
                children: <Widget>[
                  Icon(server.inst == null ? Icons.cast_connected : Icons.settings_backup_restore),
                  VerticalDivider(),
                  Text(server.inst == null ? 'Connect' : 'Reconnect')
                ],
              ),
              value: ServerMenu.connect,
            ),
          if (server.inst != null)
            PopupMenuItem(
              child: Row(
                children: <Widget>[Icon(Icons.open_in_new), VerticalDivider(), Text('View')],
              ),
              value: ServerMenu.view,
            ),
          if (server.inst?.work == true)
            PopupMenuItem(
              child: Row(
                children: <Widget>[Icon(Icons.stop), VerticalDivider(), Text('Stop')],
              ),
              value: ServerMenu.stop,
            ),
          if (server.inst?.work == false)
            PopupMenuItem(
              child: Row(
                children: <Widget>[Icon(Icons.clear), VerticalDivider(), Text('Clear')],
              ),
              value: ServerMenu.clear,
            ),
          if (server.allowToRun)
            PopupMenuItem(
              child: Row(
                children: <Widget>[Icon(Icons.edit), VerticalDivider(), Text('Edit')],
              ),
              value: ServerMenu.edit,
            ),
          PopupMenuItem(
            child: Row(
              children: <Widget>[Icon(Icons.content_copy), VerticalDivider(), Text('Clone')],
            ),
            value: ServerMenu.clone,
          ),
          if (server.allowToRun)
            PopupMenuItem(
              child: Row(
                children: <Widget>[Icon(Icons.remove_circle_outline), VerticalDivider(), Text('Delete')],
              ),
              value: ServerMenu.remove,
            ),
        ],
        icon: Icon(Icons.more_vert),
        onSelected: (value) {
          switch (value) {
            case ServerMenu.connect: // connect && reconnect
              servers.run(server, result: openPageCallback);
              debugPrint('-- Run ${server.name}');
              break;
            case ServerMenu.view:
              _openInstancePage(context, server, servers);
              break;
            case ServerMenu.edit:
              _openEditServerDialog(context, server, servers);
              break;
            case ServerMenu.remove:
              final index = servers.indexOf(server.name);
              servers.remove(server,
                  result: (_server) =>
                      _undoToast(context, 'Removed "${_server.name}"', () => servers.insertAlways(index, _server)));
              break;
            case ServerMenu.stop:
              servers.stop(server);
              break;
            case ServerMenu.clone:
              servers.addAlways(server.clone());
              break;
            case ServerMenu.clear:
              servers.clear(server);
              break;
          }
        },
      ),
    );
  }

  Widget _serverIcon(BuildContext context, ServerData server) {
    Color color;
    final size = Theme.of(context).iconTheme.size ?? 24;
    if (server.inst == null)
      color = null;
    else if (server.inst.work)
      color = Colors.green;
    else if (server.inst.hasCriticalError)
      color = Colors.red;
    else
      color = Colors.cyan;

    final icon = Icon(
      Icons.pets,
      color: color,
    );
    return Container(
      width: size,
      height: size,
      child: Stack(
        children: <Widget>[
          icon,
          _newMessagesIcon(context, server),
        ],
      ),
    );
  }

  Widget _newMessagesIcon(BuildContext context, ServerData server) {
    if (server.inst?.view?.unreadMessages == null) return DummyWidget;
    return ValueListenableBuilder(
        valueListenable: server.inst.view.unreadMessages,
        builder: (_, count, __) {
          if (count == 0) return DummyWidget;
          count = count < 99 ? count : 99;
          return Container(
            alignment: Alignment.topRight,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.red[800],
                border: Border.all(width: 1, color: Theme.of(context).canvasColor),
              ),
              constraints: BoxConstraints(minWidth: 13),
              child: Padding(
                padding: EdgeInsets.zero,
                child: Center(
                  heightFactor: 1.3,
                  widthFactor: 1.3,
                  child: Text(
                    count.toString(),
                    style: TextStyle(fontSize: 8, color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        });
  }

  Widget _mainPopupMenu(BuildContext context, ServersController servers, InstancesState state) {
    return PopupMenuButton(
      itemBuilder: (context) => [
        PopupMenuItem(
          child: ListTile(
            leading: Icon(Icons.add_circle_outline),
            title: Text('Add server'),
          ),
          value: MainMenu.addServer,
        ),
        PopupMenuItem(
          enabled: false,
          child: PopupMenuDivider(),
        ),
        if (state.active == 0 && state.counts > 0)
          PopupMenuItem(
            child: ListTile(leading: Icon(Icons.clear_all), title: Text('Clear All')),
            value: MainMenu.clearAll,
          ),
        if (state.counts == 0 && servers.length > 0)
          PopupMenuItem(
            child: ListTile(leading: Icon(Icons.delete_forever), title: Text('Remove all')),
            value: MainMenu.removeAll,
          ),
        if (state.active > 0)
          PopupMenuItem(
            child: ListTile(leading: Icon(Icons.stop), title: Text('Stop All')),
            value: MainMenu.stopAll,
          ),
        PopupMenuItem(
          child: ListTile(leading: Icon(Icons.settings), title: Text('Settings')),
          value: MainMenu.settings,
        ),
        PopupMenuItem(
          child: ListTile(leading: Icon(Icons.account_box), title: Text('About')),
          value: MainMenu.About,
        ),
      ],
      icon: Icon(Icons.menu),
      onSelected: (value) {
        switch (value) {
          case MainMenu.addServer:
            _openAddServerDialog(context, servers);
            break;
          case MainMenu.removeAll:
            dialogYesNo(context, 'Really?', 'Remove all servers entry? This action cannot be undone.', 'Remove all',
                    'Cancel')
                .then((value) {
              if (value == true) {
                servers.removeAll();
              }
            });
            break;
          case MainMenu.settings:
            _openSettingsPage(context);
            break;
          case MainMenu.About:
            showAbout(context);
            break;
          case MainMenu.stopAll:
            servers.stopAll();
            break;
          case MainMenu.clearAll:
            servers.clearAll();
            break;
        }
      },
    );
  }

  Widget _title(InstancesState state) {
    return Text(
        '| active: ${state.active}'
        '| inactive: ${state.counts - state.active}'
        '| closing: ${state.closing} |',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: StreamBuilder<InstancesState>(
            initialData: InstancesState(),
            stream: Provider.of<ServersController>(context, listen: false).stateStream,
            builder: (_, value) => (value?.data?.counts ?? 0) != 0 ? _title(value.data) : DummyWidget),
        actions: <Widget>[
          Consumer<ServersController>(
            builder: (context, servers, _) => servers.isLoaded
                ? StreamBuilder<InstancesState>(
                    initialData: InstancesState(),
                    stream: servers.stateStream,
                    builder: (_, val) => val.data != null ? _mainPopupMenu(context, servers, val.data) : DummyWidget)
                : DummyWidget,
          )
        ],
      ),
      body: SafeArea(child: Consumer<ServersController>(
        builder: (context, servers, _) {
          if (!servers.isLoaded) return DummyWidget;
          _pageRestore(context, servers);
          return _buildServersView(context, servers);
        },
      )),
    );
  }
}

class FakeHomePage extends StatefulWidget {
  final RootPage _page;
  final Function _selfDestroy;

  FakeHomePage(this._page, this._selfDestroy, {Key key}) : super(key: key);
  @override
  _FakeHomePageState createState() => _FakeHomePageState();
}

class _FakeHomePageState extends State<FakeHomePage> {
  bool _isFirst = true;

  @override
  Widget build(BuildContext context) {
    return Consumer<ServersController>(
      builder: (context, servers, _) => servers.isLoaded && _isFirst ? _body(context, servers) : DummyWidget,
    );
  }

  Widget _body(BuildContext context, ServersController servers) {
    _isFirst = false;
    Future<void> Function() open = () => null;
    if (widget._page.type == 'settings') {
      open = () async => await _openSettingsPage(context);
    } else if (widget._page.type == 'instance') {
      open = () async => await _openInstancePage(context, servers.byName(widget._page.name), servers);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _openPage(open));
    return DummyWidget;
  }

  Future<void> _openPage(Future<void> Function() open) async {
    try {
      await open();
    } finally {
      widget._selfDestroy();
    }
  }
}

Future<void> _openInstancePage(BuildContext context, ServerData server, ServersController servers) async {
  if (server?.inst == null) return;
  final states = Provider.of<NativeStates>(context, listen: false);
  states.pageOpen(RootPage('instance', server.name));
  await Navigator.of(context)
      .push(MaterialPageRoute(builder: (_) => RunningServerPage(server, servers.style, () => servers.run(server))));
  states.pageClose();
  server.inst?.view?.unreadMessages?.messagesRead();
}

Future<void> _openSettingsPage(BuildContext context) async {
  final states = Provider.of<NativeStates>(context, listen: false);
  states.pageOpen(RootPage('settings', 'settings'));
  await Navigator.of(context).push(cupertino.CupertinoPageRoute(builder: (_) => SettingsPage()));
  states.pageClose();
}
