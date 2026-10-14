enum ChecksumType {
  none,
  xor,
  sum8,
  crc8Standard,
  crc8Maxim,
  crc16Modbus,
  crc16Ccitt,
}

enum LengthFormat {
  none,
  oneByte,
  twoBytesBigEndian,
  twoBytesLittleEndian,
}

class ChecksumHelper {
  /// Calculates standard XOR checksum across bytes.
  static int calculateXor(List<int> bytes) {
    int xor = 0;
    for (final b in bytes) {
      xor ^= (b & 0xFF);
    }
    return xor & 0xFF;
  }

  /// Calculates 8-bit Sum (Modulo 256) checksum across bytes.
  static int calculateSum8(List<int> bytes) {
    int sum = 0;
    for (final b in bytes) {
      sum = (sum + (b & 0xFF)) & 0xFF;
    }
    return sum;
  }

  /// Calculates CRC-8 Standard (Polynomial 0x07, Init 0x00).
  static int calculateCrc8Standard(List<int> bytes) {
    int crc = 0x00;
    for (final b in bytes) {
      crc ^= (b & 0xFF);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x80) != 0) {
          crc = ((crc << 1) ^ 0x07) & 0xFF;
        } else {
          crc = (crc << 1) & 0xFF;
        }
      }
    }
    return crc & 0xFF;
  }

  /// Calculates CRC-8 Maxim / Dallas (Polynomial 0x31, reflected / poly 0x8C, Init 0x00).
  static int calculateCrc8Maxim(List<int> bytes) {
    int crc = 0x00;
    for (final b in bytes) {
      int cur = (b & 0xFF);
      for (int i = 0; i < 8; i++) {
        final mix = (crc ^ cur) & 0x01;
        crc >>= 1;
        if (mix != 0) {
          crc ^= 0x8C;
        }
        cur >>= 1;
      }
    }
    return crc & 0xFF;
  }

  /// Calculates CRC-16 Modbus (Polynomial 0xA001, Init 0xFFFF).
  /// Output is 16-bit integer.
  static int calculateCrc16Modbus(List<int> bytes) {
    int crc = 0xFFFF;
    for (final b in bytes) {
      crc ^= (b & 0xFF);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x0001) != 0) {
          crc = ((crc >> 1) ^ 0xA001) & 0xFFFF;
        } else {
          crc = (crc >> 1) & 0xFFFF;
        }
      }
    }
    return crc & 0xFFFF;
  }

  /// Calculates CRC-16 CCITT (Polynomial 0x1021, Init 0xFFFF).
  static int calculateCrc16Ccitt(List<int> bytes) {
    int crc = 0xFFFF;
    for (final b in bytes) {
      crc ^= ((b & 0xFF) << 8);
      for (int i = 0; i < 8; i++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc & 0xFFFF;
  }

  /// Calculates checksum bytes for the given type.
  static List<int> computeChecksumBytes(
      List<int> bytes, ChecksumType type) {
    switch (type) {
      case ChecksumType.none:
        return [];
      case ChecksumType.xor:
        return [calculateXor(bytes)];
      case ChecksumType.sum8:
        return [calculateSum8(bytes)];
      case ChecksumType.crc8Standard:
        return [calculateCrc8Standard(bytes)];
      case ChecksumType.crc8Maxim:
        return [calculateCrc8Maxim(bytes)];
      case ChecksumType.crc16Modbus:
        final c = calculateCrc16Modbus(bytes);
        // Modbus puts low byte first, then high byte
        return [c & 0xFF, (c >> 8) & 0xFF];
      case ChecksumType.crc16Ccitt:
        final c = calculateCrc16Ccitt(bytes);
        // Big endian (high byte, then low byte)
        return [(c >> 8) & 0xFF, c & 0xFF];
    }
  }

  /// Assembles a complete framed microcontroller packet:
  /// [Header] [Length?] [Command ID?] [Payload] [Checksum] [Footer?]
  static List<int> buildFrame({
    List<int> header = const [],
    List<int> commandId = const [],
    required List<int> payload,
    LengthFormat lengthFormat = LengthFormat.none,
    ChecksumType checksumType = ChecksumType.none,
    List<int> footer = const [],
    bool checksumIncludesHeader = false,
  }) {
    final frame = <int>[];

    // 1. Header
    frame.addAll(header);

    // 2. Body to calculate length & checksum for
    final body = <int>[];
    body.addAll(commandId);
    body.addAll(payload);

    // Calculate length
    final lengthBytes = <int>[];
    final lengthVal = body.length;
    if (lengthFormat == LengthFormat.oneByte) {
      lengthBytes.add(lengthVal & 0xFF);
    } else if (lengthFormat == LengthFormat.twoBytesBigEndian) {
      lengthBytes.add((lengthVal >> 8) & 0xFF);
      lengthBytes.add(lengthVal & 0xFF);
    } else if (lengthFormat == LengthFormat.twoBytesLittleEndian) {
      lengthBytes.add(lengthVal & 0xFF);
      lengthBytes.add((lengthVal >> 8) & 0xFF);
    }

    frame.addAll(lengthBytes);
    frame.addAll(body);

    // Calculate Checksum
    List<int> bytesToChecksum;
    if (checksumIncludesHeader) {
      bytesToChecksum = List.from(frame);
    } else {
      bytesToChecksum = <int>[...lengthBytes, ...body];
    }

    final cBytes = computeChecksumBytes(bytesToChecksum, checksumType);
    frame.addAll(cBytes);

    // Footer
    frame.addAll(footer);

    return frame;
  }
}
