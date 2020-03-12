import 'package:flutter/material.dart';
import 'package:mdmt2_config/src/misc.dart';
import 'package:mdmt2_config/src/upnp/finder.dart';
import 'package:mdmt2_config/src/upnp/terminal_info.dart';

class FinderPage extends StatefulWidget {
  @override
  _FinderPageState createState() => _FinderPageState();
}

class _FinderPageState extends State<FinderPage> {
  final finder = Finder();

  @override
  void initState() {
    super.initState();
    finder.start();
  }

  @override
  void dispose() {
    finder.dispose();
    super.dispose();
  }

  void _popResult(TerminalInfo info) {
    Navigator.of(context).pop<TerminalInfo>(info);
  }

  Widget _buttonBack() => Container(
        width: MediaQuery.of(context).size.width,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            FlatButton(
              child: Text('Back'),
              onPressed: () => Navigator.of(context).pop(),
            )
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return SafeArea(
        child: Scaffold(
      persistentFooterButtons: <Widget>[_buttonBack()],
      appBar: AppBar(
        leading: DummyWidget,
        title: Text('SSDP'),
      ),
      body: _body(),
    ));
  }

  Widget _body() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[_status(), Expanded(child: _view())],
    );
  }

  Widget _status() {
    return StreamBuilder<FinderStage>(
        stream: finder.status,
        builder: (_, snapshot) {
          debugPrint('${snapshot.data} ${snapshot.connectionState}');
          if (snapshot == null || snapshot.connectionState != ConnectionState.active) return DummyWidget;
          if (snapshot.hasError) return _retryBar(text: snapshot.error.toString());
          if (snapshot.data == null || snapshot.data == FinderStage.processing) return DummyWidget;
          if (snapshot.data == FinderStage.wait) return _retryBar();
          return Container(
            height: 2,
            child: LinearProgressIndicator(),
          );
        });
  }

  Widget _retryBar({String text}) {
    return Column(
      verticalDirection: VerticalDirection.up,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (text != null) Text(text),
        RaisedButton(
          onPressed: () => finder.start(),
          child: Text(
            'Retry',
            overflow: TextOverflow.ellipsis,
          ),
          padding: EdgeInsets.zero,
        )
      ],
    );
  }

  Widget _view() {
    return StreamBuilder<List<TerminalInfo>>(
        stream: finder.data,
        builder: (_, snapshot) {
          final error = snapshot?.hasError == true ? snapshot.error : null;
          return DataTable(
              sortColumnIndex: 1,
              sortAscending: finder.sort,
              columns: [
                DataColumn(label: Text('Terminals', overflow: TextOverflow.ellipsis)),
                DataColumn(
                    label: Text('Fresh', overflow: TextOverflow.ellipsis),
                    numeric: true,
                    onSort: (_, value) => finder.sort = !finder.sort)
              ],
              showCheckboxColumn: false,
              rows: [
                if (error != null)
                  DataRow(cells: [DataCell(Text('$error', overflow: TextOverflow.ellipsis)), DataCell(DummyWidget)])
                else
                  ..._rowsBuild(snapshot?.data)
              ]);
        });
  }

  List<DataRow> _rowsBuild(List<TerminalInfo> data) {
    if (data == null || data.isEmpty) return [];
    final subtitleScale = (MediaQuery.of(context).textScaleFactor ?? 1.0) * 0.85;

    return [
      for (var i in data)
        DataRow(onSelectChanged: (_) => _popResult(i), cells: [
          DataCell(
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text('${i.ip}:${i.port}', overflow: TextOverflow.ellipsis),
                Text(
                  'Version: ${i.version}, uptime: ${i.uptime} sec',
                  overflow: TextOverflow.ellipsis,
                  textScaleFactor: subtitleScale,
                )
              ],
            ),
          ),
          DataCell(Text(
            '${i.fresh}%',
            overflow: TextOverflow.ellipsis,
          ))
        ]),
    ];
  }
}
