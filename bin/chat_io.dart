import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:args/args.dart';

var _clients = <Socket>[];
Socket? _client;

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
  try {
    print('start connecting to $ipAddress with port $port...');
    _client = await Socket.connect(ipAddress, port);
  } catch (error) {
    print(error);
    _exitApp(69);
  }
  print('Connect to $ipAddress:$port');
  _client!.listen((event) => _listen(event, _client!));
  _startComunication(_client!);
}

void _listen(List<int> bytes, Socket socket) {
  try {
    final message = utf8.decode(bytes);
    print(message);
  } catch (error) {
    print('File transfer is not implemented yet');
    _exitApp(69);
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
    print('File transfer is not implemented yet');
    _exitApp(69);
  }
}

void _startComunication(Socket socket) async {
  await for (String line
      in stdin.transform(utf8.decoder).transform(LineSplitter())) {
    final message = line;
    _handleClose(message);
    if (message.isEmpty) return;
    final data = '${socket.address.address}:${socket.port}@$message';
    socket.add(utf8.encode(data));
    await socket.flush();
  }
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
  if (message != 'close') _exitApp();
  if (message == '^C') _exitApp();
}
