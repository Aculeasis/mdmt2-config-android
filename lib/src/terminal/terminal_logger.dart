import 'package:mdmt2_config/src/servers/server_data.dart';
import 'package:mdmt2_config/src/terminal/terminal_client.dart';
import 'package:native_state/native_state.dart';

class TerminalLogger extends TerminalClient {
  TerminalLogger(ServerData server, SavedStateData saved, _stopNotifyStream, log)
      : super(server, WorkingMode.logger, _stopNotifyStream, saved, 'Logger', log: log);

  @override
  onLogger(dynamic msg) => log.addFromJson(msg);
  @override
  onOk() {}
  @override
  onClose(_, __) {}
}
