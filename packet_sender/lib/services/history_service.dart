import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/packet.dart';

class HistoryService {
  static const String _key = 'packet_history';

  Future<List<Packet>> getHistory() async {
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

  Future<void> addPacket(Packet packet) async {
    final prefs = await SharedPreferences.getInstance();

    final history = await getHistory();

    history.insert(0, packet);

    // Keep only latest 100 packets.
    if (history.length > 100) {
      history.removeRange(100, history.length);
    }

    final data = history
        .map(
          (packet) => jsonEncode(packet.toJson()),
        )
        .toList();

    await prefs.setStringList(_key, data);
  }

  Future<void> clearHistory() async {
    final prefs = await SharedPreferences.getInstance();

    await prefs.remove(_key);
  }
}