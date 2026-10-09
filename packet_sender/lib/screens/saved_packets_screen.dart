import 'package:flutter/material.dart';

import '../models/packet.dart';
import '../services/saved_packet_service.dart';

class SavedPacketsScreen extends StatefulWidget {
  const SavedPacketsScreen({super.key});

  @override
  State<SavedPacketsScreen> createState() =>
      _SavedPacketsScreenState();
}

class _SavedPacketsScreenState
    extends State<SavedPacketsScreen> {

  final SavedPacketService _service =
      SavedPacketService();

  List<Packet> _packets = [];

  @override
  void initState() {
    super.initState();
    _loadPackets();
  }

  Future<void> _loadPackets() async {
    final packets = await _service.getSavedPackets();

    setState(() {
      _packets = packets;
    });
  }

  Future<void> _deletePacket(int index) async {
    await _service.deletePacket(index);

    await _loadPackets();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Packets'),
      ),

      body: _packets.isEmpty
          ? const Center(
              child: Text(
                'No saved packets.',
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _packets.length,
              itemBuilder: (context, index) {
                final packet = _packets[index];

                return Card(
                  child: ListTile(
                    title: Text(
                      '${packet.protocol} - '
                      '${packet.host}:${packet.port}',
                    ),

                    subtitle: Text(
                      '${packet.format}: ${packet.data}',
                    ),

                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete,
                      ),
                      onPressed: () {
                        _deletePacket(index);
                      },
                    ),
                  ),
                );
              },
            ),
    );
  }
}