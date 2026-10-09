import 'package:flutter/material.dart';

import '../models/packet.dart';
import '../services/udp_service.dart';
import '../services/tcp_service.dart';
import '../services/history_service.dart';
import '../services/saved_packet_service.dart';
import '../utils/hex_converter.dart';

import 'history_screen.dart';
import 'saved_packets_screen.dart';
import 'udp_listener_screen.dart';
import 'tcp_server_screen.dart';
import 'http_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ------------------------------------------------------------
  // Controllers
  // ------------------------------------------------------------

  final TextEditingController _hostController =
      TextEditingController(text: '192.168.1.10');

  final TextEditingController _portController =
      TextEditingController(text: '5000');

  final TextEditingController _dataController =
      TextEditingController();

  // ------------------------------------------------------------
  // Services
  // ------------------------------------------------------------

  final UdpService _udpService = UdpService();
  final TcpService _tcpService = TcpService();
  final HistoryService _historyService = HistoryService();
  final SavedPacketService _savedPacketService = SavedPacketService();

  // ------------------------------------------------------------
  // State
  // ------------------------------------------------------------

  String _protocol = 'UDP';
  String _format = 'ASCII';

  String _response = '';
  bool _isSending = false;

  @override
  void dispose() {
    _hostController.dispose();
    _portController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  // ------------------------------------------------------------
  // Send Packet
  // ------------------------------------------------------------

  Future<void> _sendPacket() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    final inputData = _dataController.text;

    if (host.isEmpty) {
      _showError('Please enter a host or IP address.');
      return;
    }

    if (port == null || port < 1 || port > 65535) {
      _showError('Please enter a valid port number.');
      return;
    }

    if (inputData.isEmpty) {
      _showError('Please enter packet data.');
      return;
    }

    List<int> packetData;

    try {
      if (_format == 'HEX') {
        packetData = HexConverter.hexToBytes(inputData);
      } else {
        packetData = inputData.codeUnits;
      }
    } catch (e) {
      _showError('Invalid HEX data.');
      return;
    }

    if (packetData.isEmpty) {
      _showError('Packet data cannot be empty.');
      return;
    }

    setState(() {
      _isSending = true;
      _response = '';
    });

    String? responseText;
    String? errorMessage;

    try {
      if (_protocol == 'UDP') {
        final result = await _udpService.sendPacket(
          host: host,
          port: port,
          data: packetData,
        );

        if (result == null) {
          responseText = 'No response received.';
        } else {
          responseText = result.data;
        }
      } else {
        final result = await _tcpService.sendPacket(
          host: host,
          port: port,
          data: packetData,
        );

        if (result == null) {
          responseText = 'No response received.';
        } else {
          responseText = result.data;
        }
      }
    } catch (e) {
      errorMessage = e.toString();
      responseText = 'Error: $e';
    }

    if (!mounted) return;

    setState(() {
      _response = responseText ?? '';
      _isSending = false;
    });

    // ------------------------------------------------------------
    // Save to history
    // ------------------------------------------------------------

    try {
      await _historyService.addPacket(
        Packet(
          protocol: _protocol,
          host: host,
          port: port,
          data: inputData,
          format: _format,
          response: responseText,
          timestamp: DateTime.now(),
        ),
      );
    } catch (e) {
      debugPrint('History save error: $e');
    }

    if (errorMessage != null) {
      _showError(errorMessage);
    }
  }

  // ------------------------------------------------------------
  // Save Current Packet
  // ------------------------------------------------------------

  Future<void> _saveCurrentPacket() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    final data = _dataController.text;

    if (host.isEmpty) {
      _showError('Please enter a host or IP address.');
      return;
    }

    if (port == null || port < 1 || port > 65535) {
      _showError('Please enter a valid port number.');
      return;
    }

    if (data.isEmpty) {
      _showError('Please enter packet data.');
      return;
    }

    try {
      final packet = Packet(
        protocol: _protocol,
        host: host,
        port: port,
        data: data,
        format: _format,
        timestamp: DateTime.now(),
      );

      await _savedPacketService.savePacket(packet);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Packet saved successfully.'),
        ),
      );
    } catch (e) {
      _showError('Could not save packet: $e');
    }
  }

  // ------------------------------------------------------------
  // Error Message
  // ------------------------------------------------------------

  void _showError(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ------------------------------------------------------------
  // Clear Data
  // ------------------------------------------------------------

  void _clearPacket() {
    _dataController.clear();

    setState(() {
      _response = '';
    });
  }

  // ------------------------------------------------------------
  // Build UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Packet Sender',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),

      // ----------------------------------------------------------
      // Navigation Drawer
      // ----------------------------------------------------------

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const DrawerHeader(
              decoration: BoxDecoration(
                color: Colors.indigo,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.network_check,
                    color: Colors.white,
                    size: 45,
                  ),
                  SizedBox(height: 10),
                  Text(
                    'Packet Sender',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Network Testing Tool',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),

            // Send Packet
            ListTile(
              leading: const Icon(Icons.send),
              title: const Text('Send Packet'),
              onTap: () {
                Navigator.pop(context);
              },
            ),

            // History
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('History'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HistoryScreen(),
                  ),
                );
              },
            ),

            // Saved Packets
            ListTile(
              leading: const Icon(Icons.bookmark),
              title: const Text('Saved Packets'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const SavedPacketsScreen(),
                  ),
                );
              },
            ),

            const Divider(),

            // UDP Listener
            ListTile(
              leading: const Icon(Icons.hearing),
              title: const Text('UDP Listener'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const UdpListenerScreen(),
                  ),
                );
              },
            ),

            // TCP Server
            ListTile(
              leading: const Icon(Icons.dns),
              title: const Text('TCP Server'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const TcpServerScreen(),
                  ),
                );
              },
            ),

            // HTTP / HTTPS
            ListTile(
              leading: const Icon(Icons.language),
              title: const Text('HTTP / HTTPS'),
              onTap: () {
                Navigator.pop(context);

                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const HttpScreen(),
                  ),
                );
              },
            ),
          ],
        ),
      ),

      // ----------------------------------------------------------
      // Main Body
      // ----------------------------------------------------------

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [

              // --------------------------------------------------
              // Protocol
              // --------------------------------------------------

              const Text(
                'Protocol',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: _protocol,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.router),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'UDP',
                    child: Text('UDP'),
                  ),
                  DropdownMenuItem(
                    value: 'TCP',
                    child: Text('TCP'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _protocol = value;
                    _response = '';
                  });
                },
              ),

              const SizedBox(height: 18),

              // --------------------------------------------------
              // Host / IP
              // --------------------------------------------------

              const Text(
                'Host / IP Address',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _hostController,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '192.168.1.10',
                  prefixIcon: Icon(Icons.computer),
                ),
              ),

              const SizedBox(height: 18),

              // --------------------------------------------------
              // Port
              // --------------------------------------------------

              const Text(
                'Port',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _portController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: '5000',
                  prefixIcon: Icon(Icons.settings_ethernet),
                ),
              ),

              const SizedBox(height: 18),

              // --------------------------------------------------
              // Data Format
              // --------------------------------------------------

              const Text(
                'Data Format',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: _format,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.code),
                ),
                items: const [
                  DropdownMenuItem(
                    value: 'ASCII',
                    child: Text('ASCII'),
                  ),
                  DropdownMenuItem(
                    value: 'HEX',
                    child: Text('HEX'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;

                  setState(() {
                    _format = value;
                  });
                },
              ),

              const SizedBox(height: 18),

              // --------------------------------------------------
              // Packet Data
              // --------------------------------------------------

              const Text(
                'Packet Data',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              TextField(
                controller: _dataController,
                minLines: 5,
                maxLines: 10,
                decoration: InputDecoration(
                  border: const OutlineInputBorder(),
                  hintText: _format == 'ASCII'
                      ? 'Enter packet data...'
                      : 'Example: 48 65 6C 6C 6F',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 70),
                    child: Icon(Icons.data_object),
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --------------------------------------------------
              // Send Button
              // --------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendPacket,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSending
                        ? 'SENDING...'
                        : 'SEND PACKET',
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // --------------------------------------------------
              // Save Button
              // --------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: _saveCurrentPacket,
                  icon: const Icon(Icons.bookmark),
                  label: const Text('SAVE PACKET'),
                ),
              ),

              const SizedBox(height: 10),

              // --------------------------------------------------
              // Clear Button
              // --------------------------------------------------

              SizedBox(
                width: double.infinity,
                height: 50,
                child: TextButton.icon(
                  onPressed: _clearPacket,
                  icon: const Icon(Icons.clear),
                  label: const Text('CLEAR'),
                ),
              ),

              const SizedBox(height: 24),

              // --------------------------------------------------
              // Response Section
              // --------------------------------------------------

              const Text(
                'Response',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 8),

              Container(
                width: double.infinity,
                constraints: const BoxConstraints(
                  minHeight: 120,
                ),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Colors.grey.shade400,
                  ),
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade50,
                ),
                child: SelectableText(
                  _response.isEmpty
                      ? 'No response yet.'
                      : _response,
                  style: const TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // --------------------------------------------------
              // Current Configuration
              // --------------------------------------------------

              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Current Configuration',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 12),

                      _infoRow(
                        'Protocol',
                        _protocol,
                      ),

                      _infoRow(
                        'Host',
                        _hostController.text,
                      ),

                      _infoRow(
                        'Port',
                        _portController.text,
                      ),

                      _infoRow(
                        'Format',
                        _format,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // --------------------------------------------------
              // Information
              // --------------------------------------------------

              Card(
                color: Colors.indigo.shade50,
                child: const Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.indigo,
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'For local network testing, make sure your '
                          'Android phone and computer are connected '
                          'to the same Wi-Fi network.',
                          style: TextStyle(
                            color: Colors.indigo,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------------
  // Information Row
  // ------------------------------------------------------------

  Widget _infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(
              title,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}