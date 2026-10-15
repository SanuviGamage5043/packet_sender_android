import 'package:flutter_test/flutter_test.dart';

import 'package:packet_sender/utils/hex_converter.dart';
import 'package:packet_sender/services/scanner_service.dart';
import 'package:packet_sender/services/tcp_service.dart';
import 'package:packet_sender/services/websocket_service.dart';
import 'package:packet_sender/services/streamer_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HexConverter & HexDump Tests', () {
    test('bytesToCleanAscii handles non-printable and binary bytes cleanly', () {
      final bytes = [0x45, 0x53, 0x50, 0x33, 0x32, 0x00, 0x06, 0xFF, 0x0A];
      final clean = HexConverter.bytesToCleanAscii(bytes);
      expect(clean.startsWith('ESP32··'), isTrue);
      expect(clean.contains('\n'), isTrue);
    });

    test('bytesToHex formats byte arrays correctly', () {
      final bytes = [0xAA, 0x01, 0x00, 0xFF, 0x55];
      expect(HexConverter.bytesToHex(bytes), 'AA 01 00 FF 55');
      expect(HexConverter.bytesToHex(bytes, separator: ''), 'AA0100FF55');
    });

    test('bytesToHexDump formats 16-byte aligned Wireshark style dump', () {
      final bytes = [
        0x48, 0x65, 0x6C, 0x6C, 0x6F, 0x20, 0x45, 0x53,
        0x50, 0x33, 0x32, 0x21, 0xAA, 0xBB, 0xCC, 0xDD,
        0xEE, 0xFF,
      ];
      final dump = HexConverter.bytesToHexDump(bytes);

      expect(dump.contains('OFFSET   00 01 02 03 04 05 06 07'), isTrue);
      expect(dump.contains('00000000'), isTrue);
      expect(dump.contains('00000010'), isTrue);
      expect(dump.contains('Hello ESP32!'), isTrue);
    });
  });

  group('Continuous Streamer Tests', () {
    test('PacketStreamerService starts and computes statistics', () async {
      final streamer = PacketStreamerService();
      expect(streamer.isStreaming, isFalse);

      int callbackCount = 0;
      streamer.startStream(
        intervalMs: 25,
        payload: [0x01, 0x02],
        sendCallback: (data) async {
          callbackCount++;
          return true;
        },
      );

      expect(streamer.isStreaming, isTrue);

      await Future.delayed(const Duration(milliseconds: 120));
      expect(callbackCount >= 3, isTrue);
      expect(streamer.packetsSent >= 3, isTrue);

      streamer.stopStream();
      expect(streamer.isStreaming, isFalse);
      streamer.dispose();
    });
  });

  group('Service Lifecycle Tests', () {
    test('NetworkScannerService gets local network information', () async {
      final scanner = NetworkScannerService();
      final info = await scanner.getLocalNetworkInfo();
      expect(info.containsKey('ip'), isTrue);
      expect(info.containsKey('subnet'), isTrue);
      expect(info.containsKey('broadcast'), isTrue);
    });

    test('TcpService lifecycle and disconnection safety', () async {
      final tcp = TcpService();
      expect(tcp.isConnected, isFalse);
      await tcp.disconnect();
      tcp.dispose();
      expect(tcp.isConnected, isFalse);
    });

    test('WebSocketService lifecycle and disconnection safety', () async {
      final ws = WebSocketService();
      expect(ws.isConnected, isFalse);
      await ws.disconnect();
      ws.dispose();
      expect(ws.isConnected, isFalse);
    });
  });
}
