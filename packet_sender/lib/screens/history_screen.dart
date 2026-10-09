import 'package:flutter/material.dart';

import '../models/packet.dart';
import '../services/history_service.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final HistoryService _historyService = HistoryService();

  List<Packet> _history = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadHistory();
  }

  Future<void> _loadHistory() async {
    final history = await _historyService.getHistory();

    setState(() {
      _history = history;
      _loading = false;
    });
  }

  Future<void> _clearHistory() async {
    await _historyService.clearHistory();

    setState(() {
      _history.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Packet History'),
        actions: [
          IconButton(
            onPressed: _history.isEmpty ? null : _clearHistory,
            icon: const Icon(Icons.delete),
          ),
        ],
      ),

      body: _loading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _history.isEmpty
              ? const Center(
                  child: Text('No packet history yet.'),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _history.length,
                  itemBuilder: (context, index) {
                    final packet = _history[index];

                    return Card(
                      child: ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            packet.protocol,
                            style: const TextStyle(
                              fontSize: 11,
                            ),
                          ),
                        ),

                        title: Text(
                          '${packet.host}:${packet.port}',
                        ),

                        subtitle: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 5),
                            Text('Data: ${packet.data}'),
                            Text('Format: ${packet.format}'),
                            Text(
                              'Time: ${packet.timestamp}',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}