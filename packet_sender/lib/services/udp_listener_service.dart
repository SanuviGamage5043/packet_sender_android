import 'dart:async';
import 'dart:io';

class UdpIncomingPacket {
  final String host;
  final int port;
  final List<int> data;

  UdpIncomingPacket({
    required this.host,
    required this.port,
    required this.data,
  });
}

class UdpListenerService {
  RawDatagramSocket? _socket;

  Stream<UdpIncomingPacket> start(int port) async* {
    _socket = await RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      port,
    );

    await for (final event in _socket!) {
      if (event == RawSocketEvent.read) {
        final datagram = _socket!.receive();

        if (datagram != null) {
          yield UdpIncomingPacket(
            host: datagram.address.address,
            port: datagram.port,
            data: datagram.data,
          );
        }
      }
    }
  }

  void stop() {
    _socket?.close();
    _socket = null;
  }
}