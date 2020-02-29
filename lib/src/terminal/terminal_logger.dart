import 'package:mdmt2_config/src/terminal/terminal_client.dart';

class TerminalLogger extends TerminalClient {
  TerminalLogger(server, _stopNotifyStream, log)
      : super(server, WorkingMode.logger, _stopNotifyStream, log: log, name: 'Logger');

  @override
  onLogger(dynamic msg) => log.addFromJson(msg);
  @override
  onOk() {}
  @override
  onClose(_, __) {}
}
