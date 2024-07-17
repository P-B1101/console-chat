import 'dart:convert';
import 'dart:io';
import 'common.dart';

class Client {
  late final String id;
  final Socket socket;
  final Function(Socket socket, List<int> bytes) onTransferToAll;
  // final Function(Socket socket, List<int> bytes) onSendFileToAll;
  Client(this.socket, this.onTransferToAll) {
    id = '${socket.remoteAddress.address}:${socket.remotePort}';
    socket.listen((event) => onTransferToAll(socket, event)).onDone(() {
      print('Client $id disconnected');
    });
    print(
        'Client connect ${socket.remoteAddress.address}:${socket.remotePort}');
  }

  bool isSame(Socket socket) => this.socket.isSame(socket);

  Future<void> addString(String message) async {
    socket.add(utf8.encode(message));
    await socket.flush();
  }

  Future<void> addBytes(List<int> bytes) async {
    socket.add(bytes);
    await socket.flush();
  }
}
