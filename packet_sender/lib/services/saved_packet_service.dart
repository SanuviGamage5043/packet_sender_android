import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/packet.dart';

class SavedPacketService {
  static const String _key = 'saved_packets';

  Future<List<Packet>> getSavedPackets() async {
    final prefs = await SharedPreferences.getInstance();

    final data = prefs.getStringList(_key) ?? [];

    return data
        .map(
          (item) => Packet.fromJson(
            jsonDecode(item) as Map<String, dynamic>,
          ),
        )
        .toList();
  }

  Future<void> savePacket(Packet packet) async {
    final prefs = await SharedPreferences.getInstance();

    final packets = await getSavedPackets();

    packets.insert(0, packet);

    final data = packets
        .map(
          (packet) => jsonEncode(packet.toJson()),
        )
        .toList();

    await prefs.setStringList(_key, data);
  }

  Future<void> deletePacket(int index) async {
    final prefs = await SharedPreferences.getInstance();

    final packets = await getSavedPackets();

    if (index >= 0 && index < packets.length) {
      packets.removeAt(index);
    }

    final data = packets
        .map(
          (packet) => jsonEncode(packet.toJson()),
        )
        .toList();

    await prefs.setStringList(_key, data);
  }
}