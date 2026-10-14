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
  Socket? _persistentSocket;
  StreamSubscription? _persistentSubscription;

  final _dataStreamController = StreamController<List<int>>.broadcast();
  final _connectionStateController = StreamController<bool>.broadcast();

  Stream<List<int>> get dataStream => _dataStreamController.stream;
  Stream<bool> get connectionStateStream => _connectionStateController.stream;

  bool get isConnected => _persistentSocket != null;

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

  // ---------------------------------------------------------------------------
  // Persistent Connection Mode (Ideal for ESP32 & LED Matrix Streaming)
  // ---------------------------------------------------------------------------

  Future<void> connect({
    required String host,
    required int port,
    Duration timeout = const Duration(seconds: 5),
  }) async {
    if (isConnected) {
      await disconnect();
    }

    _persistentSocket = await Socket.connect(
      host,
      port,
      timeout: timeout,
    );

    _connectionStateController.add(true);

    _persistentSubscription = _persistentSocket!.listen(
      (data) {
        _dataStreamController.add(data);
      },
      onError: (err) {
        disconnect();
      },
      onDone: () {
        disconnect();
      },
      cancelOnError: true,
    );
  }

  Future<void> sendPersistent(List<int> data) async {
    if (_persistentSocket == null) {
      throw const SocketException('TCP Socket is not connected.');
    }
    _persistentSocket!.add(data);
    await _persistentSocket!.flush();
  }

  Future<void> disconnect() async {
    await _persistentSubscription?.cancel();
    _persistentSubscription = null;
    await _persistentSocket?.close();
    _persistentSocket = null;
    if (!_connectionStateController.isClosed) {
      _connectionStateController.add(false);
    }
  }

  void dispose() {
    _persistentSubscription?.cancel();
    _persistentSubscription = null;
    _persistentSocket?.close();
    _persistentSocket = null;
    if (!_dataStreamController.isClosed) {
      _dataStreamController.close();
    }
    if (!_connectionStateController.isClosed) {
      _connectionStateController.close();
    }
  }
}