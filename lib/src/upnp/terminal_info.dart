import 'package:flutter/material.dart';
// ignore: implementation_imports
import 'package:upnp/src/utils.dart';
import 'package:upnp/upnp.dart';

class _IpPort {
  final String ip;
  final int port;
  _IpPort(this.ip, this.port);
}

class TerminalInfo {
  static const fullFresh = 2;
  static const zeroFresh = 1200;
  final String uuid;
  String version;
  int uptime;
  String ip;
  int port;
  int timestampSec;
  TerminalInfo.direct(this.uuid, this.ip, this.port, this.version, this.uptime, this.timestampSec);

  operator ==(other) => other is TerminalInfo && uuid == other.uuid;
  bool isEqual(TerminalInfo o) =>
      version == o.version && uptime == o.uptime && ip == o.ip && port == o.port && timestampSec == o.timestampSec;

  bool upgrade(TerminalInfo o) {
    if (isEqual(o)) return false;
    version = o.version;
    uptime = o.uptime;
    ip = o.ip;
    port = o.port;
    timestampSec = o.timestampSec;
    return true;
  }

  int get fresh {
    int _fresh = (DateTime.now().millisecondsSinceEpoch / 1000).truncate() - timestampSec;
    if (_fresh < fullFresh) return 100;
    if (_fresh > zeroFresh) return 0;
    return 100 - (_fresh * 100 / zeroFresh).round();
  }

  int get hashCode => uuid.hashCode;

  String toString() => '[$ip:$port] version $version, uptime $uptime seconds';

  static int _uptime(DiscoveredClient client) {
    int result = -1;
    try {
      final list = client.server.split(' ');
      result = int.parse(list.elementAt(list.length - 2)) ?? result;
    } catch (e) {
      debugPrint('*** parse uptime: $e');
    }
    return result;
  }

  static String _version(deviceNode) {
    String result = 'unknown';
    try {
      result = XmlUtils.getTextSafe(deviceNode, "modelNumber") ?? result;
    } catch (e) {
      debugPrint('*** parse version: $e');
    }
    return result;
  }

  static _IpPort _ipPort(deviceNode) {
    _IpPort result;
    try {
      var service = XmlUtils.getElementByName(XmlUtils.getElementByName(deviceNode, "serviceList"), "service");
      List<String> url = XmlUtils.getTextSafe(service, "URLBase").split(':');
      if (url[0].isNotEmpty) {
        result = _IpPort(url[0], int.parse(url[1]));
      }
    } catch (e) {
      debugPrint('*** parse ipPort: $e');
    }
    return result;
  }

  factory TerminalInfo(DiscoveredClient client, Device device, {DateTime timestamp}) {
    timestamp ??= DateTime.now();
    if (device.modelName != 'mdmTerminal2' || device.uuid == null || device.uuid == '') return null;
    var deviceNode;
    try {
      deviceNode = XmlUtils.getElementByName(device.deviceElement, "device");
    } catch (e) {
      debugPrint('*** parse device: $e');
    }
    if (deviceNode == null) return null;

    final ipPort = _ipPort(deviceNode);
    if (ipPort == null) return null;

    return TerminalInfo.direct(device.uuid, ipPort.ip, ipPort.port, _version(deviceNode), _uptime(client),
        (timestamp.millisecondsSinceEpoch / 1000).round());
  }
}
