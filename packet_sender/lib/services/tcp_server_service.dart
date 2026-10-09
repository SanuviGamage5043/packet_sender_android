import 'dart:async';
import 'dart:io';

class TcpIncomingConnection {
  final String host;
  final int port;
  final String data;

  TcpIncomingConnection({
    required this.host,
    required this.port,
    required this.data,
  });
}

class TcpServerService {
  ServerSocket? _server;

  final StreamController<TcpIncomingConnection>
      _controller =
      StreamController.broadcast();

  Stream<TcpIncomingConnection> get packets =>
      _controller.stream;

  Future<void> start(int port) async {
    _server = await ServerSocket.bind(
      InternetAddress.anyIPv4,
      port,
    );

    _server!.listen(_handleClient);
  }

  void _handleClient(Socket client) {
    final host = client.remoteAddress.address;
    final port = client.remotePort;

    client.listen(
      (data) {
        final text = String.fromCharCodes(data);

        _controller.add(
          TcpIncomingConnection(
            host: host,
            port: port,
            data: text,
          ),
        );

        client.write(
          'Hello from Android TCP server',
        );
      },

      onDone: () {
        client.destroy();
      },

      onError: (_) {
        client.destroy();
      },
    );
  }

  Future<void> stop() async {
    await _server?.close();
    _server = null;
  }

  Future<void> dispose() async {
    await stop();
    await _controller.close();
  }
}