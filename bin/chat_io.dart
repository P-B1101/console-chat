import 'dart:async';
import 'src/common.dart';
import 'dart:io';
import 'src/socket_client.dart';
import 'src/socket_server.dart';

var _clients = <Client>[];

void main(List<String> arguments) {
  Common.handleSigintSignal();
  final isServer = Common.isServer(arguments);
  if (isServer) {
    _startServerProcess();
    return;
  }
  _startClientProcess();
}

// ------------------ client ------------------
Future<void> _startClientProcess() async {
  print('Client app started.');
  final ipAddress = Common.getIpAddress(false);
  final port = Common.getPort(false);
  Socket? client;
  try {
    print('start connecting to $ipAddress with port $port...');
    client = await Socket.connect(ipAddress, port);
    print('Connect to $ipAddress:$port');
  } catch (error) {
    client = null;
    print(error);
    Common.exitApp(69);
  }
  if (client == null) return;
  SocketClient(client).run();
}

// ------------------ server ------------------

Future<void> _startServerProcess() async {
  print('Server app started.');
  late ServerSocket socket;
  try {
    print('start listening...');
    final ip = await Common.findMyIp();
    socket = await ServerSocket.bind(ip, 0);
    socket.listen((socket) {
      if (_clients.any((e) => e.isSame(socket))) return;
      final newClient = Client(socket, _onTransferToAll);
      _clients.add(newClient);
    });
  } catch (error) {
    print(error);
    Common.exitApp(69);
  }
  print('Listening on ${socket.address.address}:${socket.port}');
}

void _onTransferToAll(Socket self, List<int> bytes) {
  print('receiving and transfering packets ...');
  for (var client in _clients) {
    if (client.isSame(self)) continue;
    client.addBytes(bytes);
  }
}
