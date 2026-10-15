import 'dart:async';
import 'dart:io';

import '../utils/hex_converter.dart';

class TcpResponse {
  final String data;
  final List<int> rawBytes;
  final int latencyMs;
  final DateTime timestamp;

  TcpResponse({
    required this.data,
    required this.rawBytes,
    this.latencyMs = 0,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get hexData => HexConverter.bytesToHex(rawBytes);
  String get hexDump => HexConverter.bytesToHexDump(rawBytes);
}

class TcpService {
  // ---------------------------------------------------------------------------
  // Single-Shot Send (Connect -> Send -> Await Response -> Disconnect)
  // ---------------------------------------------------------------------------

  Future<TcpResponse?> sendPacket({
    required String host,
    required int port,
    required List<int> data,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    Socket? socket;
    final stopwatch = Stopwatch()..start();

    try {
      socket = await Socket.connect(
        host,
        port,
        timeout: timeout,
      );

      socket.add(data);
      await socket.flush();

      final completer = Completer<TcpResponse?>();
      final received = <int>[];

      final timer = Timer(timeout, () {
        if (!completer.isCompleted) {
          stopwatch.stop();
          if (received.isNotEmpty) {
            completer.complete(
              TcpResponse(
                data: HexConverter.bytesToCleanAscii(received),
                rawBytes: received,
                latencyMs: stopwatch.elapsedMilliseconds,
              ),
            );
          } else {
            completer.complete(null);
          }
        }
      });

      socket.listen(
        (chunk) {
          received.addAll(chunk);

          if (!completer.isCompleted) {
            timer.cancel();
            stopwatch.stop();
            completer.complete(
              TcpResponse(
                data: HexConverter.bytesToCleanAscii(received),
                rawBytes: received,
                latencyMs: stopwatch.elapsedMilliseconds,
              ),
            );
          }
        },
        onError: (error) {
          if (!completer.isCompleted) {
            completer.completeError(error);
          }
        },
      );

      return await completer.future;
    } finally {
      await socket?.close();
    }
  }
}