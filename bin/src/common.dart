import 'dart:io';

import 'package:args/args.dart';

class Common {
  const Common._();

  static void handleSigintSignal() {
    ProcessSignal.sigint.watch().listen((signal) {
      if (signal == ProcessSignal.sigint) {
        Common.exitApp();
      }
    });
  }

  static bool isServer(List<String> arguments) {
    final parser = ArgParser()
      ..addFlag('isServer', negatable: false, abbr: 's');
    ArgResults argResults = parser.parse(arguments);
    return argResults['isServer'] as bool;
  }

  static void exitApp([int code = 0]) async {
    exit(code);
  }

  static void handleClose(String message) {
    if (message == 'close') exitApp();
  }

  static Future<String?> findMyIp() async {
    final interfaces = await NetworkInterface.list();
    return interfaces.firstOrNull?.addresses.firstOrNull?.address;
  }

  static String getIpAddress([bool invalid = true]) {
    if (invalid) {
      stdout.write('Invalid IP address. Please enter valid IP: ');
    } else {
      stdout.write('Enter server IP address: ');
    }
    final address = stdin.readLineSync() ?? '';
    final regex = RegExp(
        r'^(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.'
        r'(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))$');

    Common.handleClose(address);
    if (!regex.hasMatch(address)) {
      return getIpAddress();
    }
    return address;
  }

  static int getPort([bool invalid = true]) {
    if (invalid) {
      stdout.write('Invalid port number. Please enter valid port number: ');
    } else {
      stdout.write('Enter server port number: ');
    }
    final data = stdin.readLineSync() ?? '';
    Common.handleClose(data);
    final port = int.tryParse(data);
    if (port == null) return getPort();
    if (port > 65535) return getPort();
    return port;
  }

  static String fileName(String path) =>
      path.substring(path.lastIndexOf(Platform.pathSeparator));

  static String fileExtension(String path) =>
      path.substring(path.lastIndexOf('.'));
}

extension SocketExt on Socket {
  bool isSame(Socket other) =>
      remoteAddress.address == other.remoteAddress.address &&
      remotePort == other.remotePort;
}
