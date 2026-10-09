import 'dart:async';
import 'dart:io';

class UdpResponse {
  final String data;
  final String host;
  final int port;

  UdpResponse({
    required this.data,
    required this.host,
    required this.port,
  });
}

class UdpService {
  RawDatagramSocket? _socket;

  Future<UdpResponse?> sendPacket({
    required String host,
    required int port,
    required List<int> data,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      final address = await InternetAddress.lookup(host);

      if (address.isEmpty) {
        throw Exception('Could not resolve host.');
      }

      _socket!.send(
        data,
        address.first,
        port,
      );

      final completer = Completer<UdpResponse?>();

      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      _socket!.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = _socket!.receive();

          if (datagram != null && !completer.isCompleted) {
            completer.complete(
              UdpResponse(
                data: String.fromCharCodes(datagram.data),
                host: datagram.address.address,
                port: datagram.port,
              ),
            );
          }
        }
      });

      return await completer.future;
    } finally {
      _socket?.close();
      _socket = null;
    }
  }
}