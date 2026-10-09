import 'dart:async';

import 'package:flutter/material.dart';

import '../services/udp_listener_service.dart';
import '../utils/hex_converter.dart';

class UdpListenerScreen extends StatefulWidget {
  const UdpListenerScreen({super.key});

  @override
  State<UdpListenerScreen> createState() =>
      _UdpListenerScreenState();
}

class _UdpListenerScreenState
    extends State<UdpListenerScreen> {

  final _portController =
      TextEditingController(text: '5000');

  final UdpListenerService _service =
      UdpListenerService();

  StreamSubscription<UdpIncomingPacket>? _subscription;

  final List<UdpIncomingPacket> _packets = [];

  bool _running = false;

  void _startListening() {
    final port = int.tryParse(
      _portController.text,
    );

    if (port == null || port < 1 || port > 65535) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid port.'),
        ),
      );
      return;
    }

    _packets.clear();

    _subscription = _service
        .start(port)
        .listen((packet) {
      setState(() {
        _packets.insert(0, packet);
      });
    });

    setState(() {
      _running = true;
    });
  }

  void _stopListening() {
    _subscription?.cancel();
    _subscription = null;

    _service.stop();

    setState(() {
      _running = false;
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.stop();

    _portController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('UDP Listener'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Listen Port',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed: _running
                    ? _stopListening
                    : _startListening,
                child: Text(
                  _running
                      ? 'STOP LISTENING'
                      : 'START LISTENING',
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _packets.isEmpty
                  ? const Center(
                      child: Text(
                        'No incoming packets.',
                      ),
                    )
                  : ListView.builder(
                      itemCount: _packets.length,
                      itemBuilder: (context, index) {
                        final packet =
                            _packets[index];

                        final hex = packet.data
                            .map(
                              (byte) => byte
                                  .toRadixString(16)
                                  .padLeft(2, '0'),
                            )
                            .join(' ')
                            .toUpperCase();

                        final ascii =
                            String.fromCharCodes(
                          packet.data,
                        );

                        return Card(
                          child: Padding(
                            padding:
                                const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${packet.host}:${packet.port}',
                                  style:
                                      const TextStyle(
                                    fontWeight:
                                        FontWeight.bold,
                                  ),
                                ),

                                const SizedBox(
                                  height: 8,
                                ),

                                Text('HEX:\n$hex'),

                                const SizedBox(
                                  height: 8,
                                ),

                                Text(
                                  'ASCII:\n$ascii',
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}