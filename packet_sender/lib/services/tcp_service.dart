import 'dart:async';
import 'dart:io';

class TcpResponse {
  final String data;

  TcpResponse({
    required this.data,
  });
}

class TcpService {
  Socket? _socket;

  Future<TcpResponse?> sendPacket({
    required String host,
    required int port,
    required List<int> data,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      _socket = await Socket.connect(
        host,
        port,
        timeout: timeout,
      );

      _socket!.add(data);
      await _socket!.flush();

      final completer = Completer<TcpResponse?>();
      final received = <int>[];

      Timer(timeout, () {
        if (!completer.isCompleted) {
          if (received.isNotEmpty) {
            completer.complete(
              TcpResponse(
                data: String.fromCharCodes(received),
              ),
            );
          } else {
            completer.complete(null);
          }
        }
      });

      _socket!.listen(
        (data) {
          received.addAll(data);

          if (!completer.isCompleted) {
            completer.complete(
              TcpResponse(
                data: String.fromCharCodes(received),
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
      await _socket?.close();
      _socket = null;
    }
  }
}