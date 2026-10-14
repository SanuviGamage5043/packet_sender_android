import 'dart:async';
import 'dart:io';

import '../utils/hex_converter.dart';

class WebSocketMessage {
  final dynamic data;
  final bool isBinary;
  final List<int> rawBytes;
  final String text;
  final DateTime timestamp;

  WebSocketMessage({
    required this.data,
    required this.isBinary,
    required this.rawBytes,
    required this.text,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();

  String get hexDump => HexConverter.bytesToHexDump(rawBytes);
}

class WebSocketService {
  WebSocket? _webSocket;
  StreamSubscription? _subscription;

  final _messageController = StreamController<WebSocketMessage>.broadcast();
  final _stateController = StreamController<bool>.broadcast();

  Stream<WebSocketMessage> get messageStream => _messageController.stream;
  Stream<bool> get connectionStateStream => _stateController.stream;

  bool get isConnected => _webSocket != null && _webSocket!.readyState == WebSocket.open;

  Future<void> connect(String url) async {
    if (isConnected) {
      await disconnect();
    }

    String formattedUrl = url.trim();
    if (!formattedUrl.startsWith('ws://') && !formattedUrl.startsWith('wss://')) {
      formattedUrl = 'ws://$formattedUrl';
    }

    _webSocket = await WebSocket.connect(
      formattedUrl,
    ).timeout(const Duration(seconds: 5));

    _stateController.add(true);

    _subscription = _webSocket!.listen(
      (message) {
        if (message is List<int>) {
          _messageController.add(
            WebSocketMessage(
              data: message,
              isBinary: true,
              rawBytes: message,
              text: HexConverter.bytesToCleanAscii(message),
            ),
          );
        } else {
          final str = message.toString();
          final bytes = str.codeUnits;
          _messageController.add(
            WebSocketMessage(
              data: str,
              isBinary: false,
              rawBytes: bytes,
              text: str,
            ),
          );
        }
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

  void sendText(String text) {
    if (!isConnected) {
      throw const SocketException('WebSocket is not connected.');
    }
    _webSocket!.add(text);
  }

  void sendBytes(List<int> bytes) {
    if (!isConnected) {
      throw const SocketException('WebSocket is not connected.');
    }
    _webSocket!.add(bytes);
  }

  Future<void> disconnect() async {
    await _subscription?.cancel();
    _subscription = null;
    await _webSocket?.close();
    _webSocket = null;
    if (!_stateController.isClosed) {
      _stateController.add(false);
    }
  }

  void dispose() {
    _subscription?.cancel();
    _subscription = null;
    _webSocket?.close();
    _webSocket = null;
    if (!_messageController.isClosed) {
      _messageController.close();
    }
    if (!_stateController.isClosed) {
      _stateController.close();
    }
  }
}
