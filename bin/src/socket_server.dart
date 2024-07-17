import 'dart:convert';
import 'dart:io';
import 'common.dart';

class Client {
  late final String id;
  final Socket socket;
  final Function(Socket socket, List<int> bytes) onSendMessageToAll;
  final Function(Socket socket, List<int> bytes) onSendFileToAll;
  Client(this.socket, this.onSendMessageToAll, this.onSendFileToAll) {
    id = '${socket.remoteAddress.address}:${socket.remotePort}';
    socket.listen((event) => _serverListen(event));
    print(
        'Client connect ${socket.remoteAddress.address}:${socket.remotePort}');
  }

  void _serverListen(List<int> bytes) async {
    try {
      onSendMessageToAll(socket, bytes);
    } catch (error) {
      onSendFileToAll(socket, bytes);
    }
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
