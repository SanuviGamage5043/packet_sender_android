import 'dart:async';

import 'package:flutter/material.dart';

import '../services/tcp_server_service.dart';

class TcpServerScreen extends StatefulWidget {
  const TcpServerScreen({super.key});

  @override
  State<TcpServerScreen> createState() =>
      _TcpServerScreenState();
}

class _TcpServerScreenState
    extends State<TcpServerScreen> {

  final _portController =
      TextEditingController(text: '5000');

  final TcpServerService _service =
      TcpServerService();

  StreamSubscription<TcpIncomingConnection>?
      _subscription;

  final List<TcpIncomingConnection> _connections =
      [];

  bool _running = false;

  Future<void> _startServer() async {
    final port = int.tryParse(
      _portController.text,
    );

    if (port == null || port < 1 || port > 65535) {
      _showMessage('Invalid port.');
      return;
    }

    try {
      await _service.start(port);

      _subscription =
          _service.packets.listen((packet) {
        setState(() {
          _connections.insert(0, packet);
        });
      });

      setState(() {
        _running = true;
      });
    } catch (e) {
      _showMessage('Failed to start server: $e');
    }
  }

  Future<void> _stopServer() async {
    await _subscription?.cancel();
    _subscription = null;

    await _service.stop();

    setState(() {
      _running = false;
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _service.dispose();

    _portController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('TCP Server'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _portController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Server Port',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton(
                onPressed:
                    _running ? _stopServer : _startServer,
                child: Text(
                  _running
                      ? 'STOP SERVER'
                      : 'START SERVER',
                ),
              ),
            ),

            const SizedBox(height: 16),

            Expanded(
              child: _connections.isEmpty
                  ? const Center(
                      child: Text(
                        'No TCP connections yet.',
                      ),
                    )
                  : ListView.builder(
                      itemCount:
                          _connections.length,
                      itemBuilder:
                          (context, index) {
                        final connection =
                            _connections[index];

                        return Card(
                          child: ListTile(
                            title: Text(
                              '${connection.host}:${connection.port}',
                            ),
                            subtitle: Text(
                              connection.data,
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