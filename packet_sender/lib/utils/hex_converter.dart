class HexConverter {
  /// Converts ASCII/string text to HEX string (e.g. "Hello" -> "48 65 6C 6C 6F").
  static String asciiToHex(String text) {
    return text.codeUnits
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase();
  }

  /// Converts bytes list to HEX string with optional separator.
  static String bytesToHex(List<int> bytes, {String separator = ' '}) {
    return bytes
        .map((b) => (b & 0xFF).toRadixString(16).padLeft(2, '0').toUpperCase())
        .join(separator);
  }

  /// Converts HEX text to ASCII string.
  static String hexToAscii(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    if (cleaned.length % 2 != 0) {
      throw const FormatException('HEX data must contain pairs of characters.');
    }

    final bytes = <int>[];

    for (int i = 0; i < cleaned.length; i += 2) {
      bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }

    return bytesToCleanAscii(bytes);
  }

  /// Converts HEX to bytes for sending over the network.
  static List<int> hexToBytes(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    if (cleaned.length % 2 != 0) {
      throw const FormatException('HEX data must contain pairs of characters.');
    }

    final bytes = <int>[];

    for (int i = 0; i < cleaned.length; i += 2) {
      bytes.add(
        int.parse(
          cleaned.substring(i, i + 2),
          radix: 16,
        ),
      );
    }

    return bytes;
  }

  /// Safely converts bytes to printable ASCII without crashing on binary control characters.
  /// Replaces unprintable control characters with '·'.
  static String bytesToCleanAscii(List<int> bytes) {
    final buffer = StringBuffer();
    for (final b in bytes) {
      final code = b & 0xFF;
      if (code == 10) {
        // newline
        buffer.write('\n');
      } else if (code == 13) {
        // carriage return
        buffer.write('\r');
      } else if (code == 9) {
        // tab
        buffer.write('\t');
      } else if (code >= 32 && code <= 126) {
        // Printable ASCII
        buffer.writeCharCode(code);
      } else {
        // Unprintable byte (binary flag, null, ack, etc.)
        buffer.write('·');
      }
    }
    return buffer.toString();
  }

  /// Formats byte array into canonical Wireshark-style Hex Dump:
  /// OFFSET    00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F   ASCII
  /// 00000000  48 65 6C 6C 6F 20 57 6F  72 6C 64 21 00 01 02 03  |Hello World!....|
  static String bytesToHexDump(List<int> bytes) {
    if (bytes.isEmpty) return 'No data.';

    final sb = StringBuffer();
    sb.writeln('OFFSET   00 01 02 03 04 05 06 07  08 09 0A 0B 0C 0D 0E 0F  ASCII');
    sb.writeln('----------------------------------------------------------------');

    for (int i = 0; i < bytes.length; i += 16) {
      // Offset (8 hex digits)
      sb.write(i.toRadixString(16).padLeft(8, '0').toUpperCase());
      sb.write(' ');

      // Hex bytes (16 bytes per line with gap after 8)
      final chunkLength = (i + 16 <= bytes.length) ? 16 : bytes.length - i;

      for (int j = 0; j < 16; j++) {
        if (j == 8) sb.write(' ');
        if (j < chunkLength) {
          final b = bytes[i + j] & 0xFF;
          sb.write(b.toRadixString(16).padLeft(2, '0').toUpperCase());
          sb.write(' ');
        } else {
          sb.write('   ');
        }
      }

      sb.write(' |');
      // Printable ASCII representation
      for (int j = 0; j < chunkLength; j++) {
        final b = bytes[i + j] & 0xFF;
        if (b >= 32 && b <= 126) {
          sb.writeCharCode(b);
        } else {
          sb.write('.');
        }
      }
      sb.writeln('|');
    }

    return sb.toString();
  }
}