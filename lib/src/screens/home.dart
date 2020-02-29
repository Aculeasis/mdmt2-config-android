import 'package:flutter/cupertino.dart' as cupertino;
import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/dialogs.dart';
import 'package:mdmt2_config/src/screens/running_server/runhing_server.dart';
import 'package:mdmt2_config/src/screens/settings.dart';
import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/servers/servers_controller.dart';
import 'package:mdmt2_config/src/settings/misc_settings.dart';
import 'package:mdmt2_config/src/terminal/instances_controller.dart';
import 'package:provider/provider.dart';

enum ServerMenu { connect, edit, remove, view, stop, clone, clear }
enum MainMenu { addServer, removeAll, settings, About, stopAll, clearAll }

class MainServersPage extends StatelessWidget {
  void _undoToast(BuildContext context, String msg, Function() undo) {
    final scaffold = Scaffold.of(context);
    scaffold.hideCurrentSnackBar();
    scaffold.showSnackBar(SnackBar(
      content: Text(msg, textAlign: TextAlign.center),
      action: SnackBarAction(label: 'Undo!', onPressed: undo),
    ));
  }

  Widget _buildServersView(BuildContext context, ServersController servers) {
    return ReorderableListView(
      padding: EdgeInsets.only(top: 10),
      children: <Widget>[
        if (servers.length > 0)
          for (var server in servers.loop)
            ValueListenableBuilder(
                key: ObjectKey(server),
                valueListenable: server.states.changeNotify,
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
            onTap: () => _addServer(context, servers),
          )
      ],
      onReorder: (oldIndex, newIndex) {
        debugPrint('* old=$oldIndex, new=$newIndex');
        servers.relocation(oldIndex, newIndex);
      },
    );
  }

  Widget _buildRow(BuildContext context, ServersController servers, ServerData server) {
    final instances = Provider.of<InstancesController>(context, listen: false);
    void view({TerminalInstance instance}) {
      instance ??= instances[server];
      if (instance != null)
        Navigator.of(context)
            .push(
                MaterialPageRoute(builder: (context) => RunningServerPage(instance, instances.style, server)))
            .then((value) => server.states.messagesRead());
    }

    void openPageCallback(TerminalInstance instance) {
      if (Provider.of<MiscSettings>(context, listen: false).openOnRunning) view(instance: instance);
    }

    final state = CollectActualServerState(server, instances[server]);
    return ListTile(
      leading: _serverIcon(context, state, server),
      title: Text(
        '${server.name}',
        maxLines: 1,
      ),
      onTap: () {
        if (state.isControlled) view();
      },
      subtitle: Text(
        state.subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis
      ),
      trailing: PopupMenuButton(
        itemBuilder: (context) => [
          if (state.isPartialLogger || state.isPartialControl)
            PopupMenuItem(
              child: Row(
                children: <Widget>[
                  Icon(Icons.settings_backup_restore),
                  VerticalDivider(),
                  Text('Run ${state.isPartialLogger ? 'Logger' : 'Maintence'}')
                ],
              ),
              value: ServerMenu.connect,
            ),
          if (state.isEnabled && !(state.isControlled && state.work))
            PopupMenuItem(
              child: Row(
                children: <Widget>[
                  Icon(Icons.cast_connected),
                  VerticalDivider(),
                  Text(state.isControlled ? 'Reconnect' : 'Connect')
                ],
              ),
              value: ServerMenu.connect,
            ),
          if (state.isControlled)
            PopupMenuItem(
              child: Row(
                children: <Widget>[Icon(Icons.open_in_new), VerticalDivider(), Text('View')],
              ),
              value: ServerMenu.view,
            ),
          if (state.isControlled && state.work)
            PopupMenuItem(
              child: Row(
                children: <Widget>[Icon(Icons.stop), VerticalDivider(), Text('Stop')],
              ),
              value: ServerMenu.stop,
            ),
          if (state.isControlled && !state.work)
            PopupMenuItem(
              child: Row(
                children: <Widget>[Icon(Icons.clear), VerticalDivider(), Text('Clear')],
              ),
              value: ServerMenu.clear,
            ),
          if (!state.isControlled || !state.work)
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
          if (!state.isControlled || !state.work)
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
              instances.run(server, result: openPageCallback);
              debugPrint('-- Run ${server.name}');
              break;
            case ServerMenu.view:
              view();
              break;
            case ServerMenu.edit:
              serverFormDialog(context, server, servers.contains).then((value) => servers.upgrade(server, value));
              break;
            case ServerMenu.remove:
              final index = servers.indexOf(server.name);
              instances.remove(server);
              servers.remove(server);
              _undoToast(context, 'Removed "${server.name}"', () {
                servers.insertAlways(index, server);
              });
              break;
            case ServerMenu.stop:
              instances.stop(server);
              break;
            case ServerMenu.clone:
              servers.addAlways(server.clone());
              break;
            case ServerMenu.clear:
              instances.clear(server);
              break;
          }
        },
      ),
    );
  }

  Widget _serverIcon(BuildContext context, CollectActualServerState state, ServerData server) {
    Color color;
    final size = Theme.of(context).iconTheme.size ?? 24;
    if (!state.isControlled) {
    } else if (state.work && state.errors == 0)
      color = Colors.green;
    else if (!state.work && state.errors == 0)
      color = Colors.cyan;
    else if (state.errors < state.counts)
      color = Colors.yellow;
    else
      color = Colors.red;
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
    return ValueListenableBuilder(
        valueListenable: server.states.unreadMessages,
        builder: (_, count, __) {
          if (count == 0) return SizedBox();
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

  Widget _mainPopupMenu(
      BuildContext context, ServersController servers, InstancesController instances, InstancesState state) {
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
            _addServer(context, servers);
            break;
          case MainMenu.removeAll:
            dialogYesNo(context, 'Really?', 'Remove all servers entry? This action cannot be undone.', 'Remove all',
                    'Cancel')
                .then((value) {
              if (value == true) {
                instances.clearAll();
                servers.removeAll();
              }
            });
            break;
          case MainMenu.settings:
            //Navigator.
            Navigator.of(context).push(cupertino.CupertinoPageRoute(builder: (context) => SettingsPage()));
            // settings
            break;
          case MainMenu.About:
            showAbout(context);
            break;
          case MainMenu.stopAll:
            instances.stopAll();
            break;
          case MainMenu.clearAll:
            instances.clearAll();
            break;
        }
      },
    );
  }

  Widget _title(InstancesState state) {
    if (state.counts == 0) return SizedBox();
    return Text(
        '| active: ${state.active}'
        '| inactive: ${state.counts - state.active}'
        '| closing: ${state.closing} |',
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w300));
  }

  _addServer(BuildContext context, ServersController servers) =>
      serverFormDialog(context, ServerData(), servers.contains).then((value) {
        if (value != null) servers.add(value);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Consumer<InstancesController>(
            builder: (_, manager, __) => StreamBuilder<InstancesState>(
                initialData: InstancesState(), stream: manager.stateStream, builder: (_, value) => _title(value.data))),
        actions: <Widget>[
          Consumer2<ServersController, InstancesController>(
            builder: (context, servers, manager, child) => servers.isLoaded
                ? StreamBuilder<InstancesState>(
                    initialData: InstancesState(),
                    stream: manager.stateStream,
                    builder: (_, val) => _mainPopupMenu(context, servers, manager, val.data))
                : child,
            child: Container(),
          )
        ],
      ),
      body: SafeArea(
          child: Consumer<ServersController>(
        builder: (context, servers, child) => servers.isLoaded ? _buildServersView(context, servers) : child,
        child: Container(),
      )),
    );
  }
}
