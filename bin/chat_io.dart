import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';
import 'package:mime/mime.dart';

var _clients = <Socket>[];
var _clientBytes = <int>[];
StreamSubscription<String>? _clientSub;

void main(List<String> arguments) {
  ProcessSignal.sigint.watch().listen((signal) {
    if (signal == ProcessSignal.sigint) {
      _exitApp();
    }
  });
  final parser = ArgParser()..addFlag('isServer', negatable: false, abbr: 's');
  ArgResults argResults = parser.parse(arguments);
  final isServer = argResults['isServer'] as bool;
  if (isServer) {
    _startServerProcess();
  } else {
    _startClientProcess();
  }
}

Future<void> _startClientProcess() async {
  print('Client app started.');
  final ipAddress = _getIpAddress(false);
  final port = _getPort(false);
  Socket? client;
  try {
    print('start connecting to $ipAddress with port $port...');
    client = await Socket.connect(ipAddress, port);
    print('Connect to $ipAddress:$port');
  } catch (error) {
    client = null;
    print(error);
    _exitApp(69);
  }
  if (client == null) return;
  client.listen((event) => _listen(event, client!)).onDone(() {
    stdout.writeln();
    print('disconnect from server.');
    _clientSub?.cancel();
    _clientSub = null;
    _exitApp(70);
  });
  _startComunication(client);
}

void _listen(List<int> bytes, Socket socket) {
  try {
    final message = utf8.decode(bytes);
    if (message == 'EOF') {
      _handleClientFile();
      return;
    }
    print(message);
  } catch (error) {
    print('receive file packets...');
    _clientBytes.addAll(bytes);
  }
}

void _serverListen(List<int> bytes, Socket socket) async {
  try {
    final message = utf8.decode(bytes);
    print('Message received: $message');
    final temp = message.split('@');
    final addressTemp = temp[0].split(':');
    final ip = addressTemp[0];
    final port = int.parse(addressTemp[1]);
    for (var client in _clients) {
      if (client.remoteAddress.address == ip && client.remotePort == port) {
        continue;
      }
      client.add(utf8.encode(
          '${client.remoteAddress.address}:${client.remotePort}@ ${temp[1]}'));
      await client.flush();
    }
  } catch (error) {
    print('receiving and transfering file packets ...');
    for (var client in _clients) {
      if (client.remoteAddress.address == socket.remoteAddress.address &&
          client.remotePort == socket.remotePort) {
        continue;
      }
      client.add(bytes);
      await client.flush();
    }
  }
}

void _startComunication(Socket socket) async {
  stdout.write('me: ');
  _clientSub = stdin
      .transform(utf8.decoder)
      .transform(LineSplitter())
      .listen((line) async {
    stdout.write('me: ');
    final message = line;
    _handleClose(message);
    if (await (_handleFile(socket, message))) {
      return;
    }
    if (message.isEmpty) return;
    final data = '${socket.address.address}:${socket.port}@$message';
    socket.add(utf8.encode(data));
    await socket.flush();
  });
}

int _getPort([bool invalid = true]) {
  if (invalid) {
    stdout.write('Invalid port number. Please enter valid port number: ');
  } else {
    stdout.write('Enter server port number: ');
  }
  final data = stdin.readLineSync() ?? '';
  _handleClose(data);
  final port = int.tryParse(data);
  if (port == null) return _getPort();
  if (port > 65535) return _getPort();
  return port;
}

String _getIpAddress([bool invalid = true]) {
  if (invalid) {
    stdout.write('Invalid IP address. Please enter valid IP: ');
  } else {
    stdout.write('Enter server IP address: ');
  }
  final address = stdin.readLineSync() ?? '';
  final regex = RegExp(
      r'^(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.'
      r'(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))\.(\d|[1-9]\d|1\d\d|2([0-4]\d|5[0-5]))$');

  _handleClose(address);
  if (!regex.hasMatch(address)) {
    return _getIpAddress();
  }
  return address;
}

Future<void> _startServerProcess() async {
  print('Server app started.');
  late ServerSocket socket;
  try {
    print('start listening...');
    final ip = await _findMyIp();
    socket = await ServerSocket.bind(ip, 0);
    socket.listen(_onClientConnect);
  } catch (error) {
    print(error);
    _exitApp(69);
  }
  print('Listening on ${socket.address.address}:${socket.port}');
}

Future<String?> _findMyIp() async {
  final interfaces = await NetworkInterface.list();
  return interfaces.firstOrNull?.addresses.firstOrNull?.address;
}

void _onClientConnect(Socket socket) {
  _handleAddToClients(socket);
  socket.listen((event) => _serverListen(event, socket));
}

void _handleAddToClients(Socket socket) {
  if (_clients.any((e) =>
      e.address.address == socket.remoteAddress.address &&
      e.port == socket.remotePort)) {
    return;
  }
  _clients.add(socket);
  print('Client connect ${socket.remoteAddress.address}:${socket.remotePort}');
}

void _exitApp([int code = 0]) async {
  exit(code);
}

void _handleClose(String message) {
  if (message == 'close') _exitApp();
}

Future<bool> _handleFile(Socket socket, String message) async {
  if (!message.startsWith('file://')) return false;
  try {
    final path = message.substring(7).toLowerCase();
    final file = File(path);
    if (!file.existsSync()) {
      print('File $path does not exits');
      return true;
    }
    print('start uploading file from $path.');
    await socket.addStream(file.openRead());
    // await socket.flush();
    await Future.delayed(const Duration(seconds: 2));
    socket.add(utf8.encode('EOF'));
    stdout.writeln('me: file uploaded.');
    stdout.write('me: ');
  } catch (error) {
    print(error);
  }
  return true;
}

void _handleClientFile() {
  final mime = lookupMimeType('', headerBytes: _clientBytes);
  final extension = extensionFromMime(mime ?? '');
  final path =
      '${Directory.current.path}${Platform.pathSeparator}${DateTime.now().millisecondsSinceEpoch}.$extension';
  final file = File(path);
  if (file.existsSync()) file.deleteSync();
  file.createSync();
  file.writeAsBytesSync(_clientBytes.toList());
  print('file downloaded at $path');
  _clientBytes.clear();
}
