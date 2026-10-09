class HexConverter {
  /// Converts ASCII/string text to HEX.
  static String asciiToHex(String text) {
    return text.codeUnits
        .map((value) => value.toRadixString(16).padLeft(2, '0'))
        .join(' ')
        .toUpperCase();
  }

  /// Converts HEX text to ASCII.
  static String hexToAscii(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    if (cleaned.length % 2 != 0) {
      throw FormatException('HEX data must contain pairs of characters.');
    }

    final bytes = <int>[];

    for (int i = 0; i < cleaned.length; i += 2) {
      bytes.add(int.parse(cleaned.substring(i, i + 2), radix: 16));
    }

    return String.fromCharCodes(bytes);
  }

  /// Converts HEX to bytes for sending over the network.
  static List<int> hexToBytes(String hex) {
    final cleaned = hex.replaceAll(RegExp(r'[^0-9A-Fa-f]'), '');

    if (cleaned.length % 2 != 0) {
      throw FormatException('HEX data must contain pairs of characters.');
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
}