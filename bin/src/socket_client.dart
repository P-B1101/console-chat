import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'common.dart';
import 'package:mime/mime.dart';

class SocketClient {
  final Socket socket;
  late final String id;

  final _clientBytes = <int>[];
  StreamSubscription<String>? _clientSub;
  SocketClient(this.socket) {
    id = '${socket.remoteAddress.address}:${socket.remotePort}';
  }

  void run() {
    socket.listen((event) => _listen(event, socket)).onDone(() {
      stdout.writeln();
      print('disconnect from server.');
      _clientSub?.cancel();
      _clientSub = null;
      Common.exitApp(70);
    });
    _startComunication(socket);
  }

  void _listen(List<int> bytes, Socket socket) {
    try {
      final message = utf8.decode(bytes);
      if (message == 'EOF') {
        _handleEOF();
        return;
      }
      print(message);
    } catch (error) {
      print('receive file packets...');
      _clientBytes.addAll(bytes);
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
      Common.handleClose(message);
      if (await (_handleFile(socket, message))) {
        return;
      }
      if (message.isEmpty) return;
      final data = '${socket.address.address}:${socket.port}@$message';
      socket.add(utf8.encode(data));
      await socket.flush();
    });
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

  void _handleEOF() {
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
}
