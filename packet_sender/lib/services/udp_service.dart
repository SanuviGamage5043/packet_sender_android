import 'dart:async';
import 'dart:io';

import '../utils/hex_converter.dart';

class UdpResponse {
  final String data;
  final List<int> rawBytes;
  final String host;
  final int port;
  final int latencyMs;
  final DateTime timestamp;

  UdpResponse({
    required this.data,
    required this.rawBytes,
    required this.host,
    required this.port,
    this.latencyMs = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get hexData => HexConverter.bytesToHex(rawBytes);
  String get hexDump => HexConverter.bytesToHexDump(rawBytes);
}

class UdpService {
  RawDatagramSocket? _socket;

  /// Sends a UDP packet to [host]:[port].
  /// Supports unicast and broadcast (e.g. 255.255.255.255).
  Future<UdpResponse?> sendPacket({
    required String host,
    required int port,
    required List<int> data,
    Duration timeout = const Duration(seconds: 4),
    bool isBroadcast = false,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      _socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      // Crucial for ESP32 discovery and broadcast packets:
      _socket!.broadcastEnabled = true;

      final targetAddress = await _resolveAddress(host);

      _socket!.send(
        data,
        targetAddress,
        port,
      );

      final completer = Completer<UdpResponse?>();

      final timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(null);
        }
      });

      _socket!.listen(
        (event) {
          if (event == RawSocketEvent.read) {
            final datagram = _socket?.receive();

            if (datagram != null && !completer.isCompleted) {
              timer.cancel();
              stopwatch.stop();

              completer.complete(
                UdpResponse(
                  data: HexConverter.bytesToCleanAscii(datagram.data),
                  rawBytes: datagram.data,
                  host: datagram.address.address,
                  port: datagram.port,
                  latencyMs: stopwatch.elapsedMilliseconds,
                ),
              );
            }
          }
        },
        onError: (err) {
          if (!completer.isCompleted) {
            completer.completeError(err);
          }
        },
      );

      return await completer.future;
    } finally {
      _socket?.close();
      _socket = null;
    }
  }

  /// Sends a broadcast discovery packet and listens for MULTIPLE responding ESP32 / IoT devices.
  Future<List<UdpResponse>> sendBroadcastDiscovery({
    required int port,
    required List<int> probeData,
    String broadcastAddress = '255.255.255.255',
    Duration timeout = const Duration(milliseconds: 1500),
  }) async {
    RawDatagramSocket? discoverySocket;
    final responses = <UdpResponse>[];
    final seenHosts = <String>{};

    try {
      discoverySocket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      );

      discoverySocket.broadcastEnabled = true;

      final target = await _resolveAddress(broadcastAddress);
      discoverySocket.send(probeData, target, port);

      final completer = Completer<List<UdpResponse>>();

      Timer(timeout, () {
        if (!completer.isCompleted) {
          completer.complete(responses);
        }
      });

      discoverySocket.listen((event) {
        if (event == RawSocketEvent.read) {
          final datagram = discoverySocket?.receive();
          if (datagram != null) {
            final ip = datagram.address.address;
            if (!seenHosts.contains(ip)) {
              seenHosts.add(ip);
              responses.add(
                UdpResponse(
                  data: HexConverter.bytesToCleanAscii(datagram.data),
                  rawBytes: datagram.data,
                  host: ip,
                  port: datagram.port,
                ),
              );
            }
          }
        }
      });

      return await completer.future;
    } catch (e) {
      return responses;
    } finally {
      discoverySocket?.close();
    }
  }

  Future<InternetAddress> _resolveAddress(String host) async {
    final parsed = InternetAddress.tryParse(host.trim());
    if (parsed != null) {
      return parsed;
    }

    final lookup = await InternetAddress.lookup(host.trim());
    if (lookup.isEmpty) {
      throw SocketException('Could not resolve host: $host');
    }
    return lookup.first;
  }
}