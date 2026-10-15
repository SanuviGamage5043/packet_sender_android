import 'dart:async';
import 'package:flutter/material.dart';

import '../models/packet.dart';
import '../services/udp_service.dart';
import '../services/tcp_service.dart';
import '../services/websocket_service.dart';
import '../services/history_service.dart';
import '../services/saved_packet_service.dart';
import '../services/scanner_service.dart';
import '../services/streamer_service.dart';
import '../utils/hex_converter.dart';

import 'history_screen.dart';
import 'saved_packets_screen.dart';
import 'udp_listener_screen.dart';
import 'tcp_server_screen.dart';
import 'http_screen.dart';

import '../widgets/packet_flow_logo.dart';
import '../widgets/response_inspector.dart';
import '../widgets/esp32_scanner_dialog.dart';

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

  final TextEditingController _dataController = TextEditingController();

  // ------------------------------------------------------------
  // Services
  // ------------------------------------------------------------

  final UdpService _udpService = UdpService();
  final TcpService _tcpService = TcpService();
  final WebSocketService _wsService = WebSocketService();
  final HistoryService _historyService = HistoryService();
  final SavedPacketService _savedPacketService = SavedPacketService();
  final PacketStreamerService _streamerService = PacketStreamerService();

  // ------------------------------------------------------------
  // State
  // ------------------------------------------------------------

  String _protocol = 'UDP';
  String _format = 'ASCII';

  bool _isBroadcast = false;
  bool _isSending = false;
  bool _isConnecting = false;

  // Continuous Streamer State
  bool _showStreamerSection = false;
  int _streamIntervalMs = 33; // Default 33ms (~30 FPS for LED panels)
  StreamerStats? _streamerStats;

  // Dual Response Inspector state
  List<int> _rawResponseBytes = [];
  String _response = '';
  int? _responseLatencyMs;
  String? _responseEndpoint;
  DateTime? _responseTimestamp;

  // Stream Subscriptions
  StreamSubscription? _tcpDataSub;
  StreamSubscription? _tcpStateSub;
  StreamSubscription? _wsMessageSub;
  StreamSubscription? _wsStateSub;
  StreamSubscription? _streamerSub;

  @override
  void initState() {
    super.initState();
    _listenToPersistentStreams();

    _streamerSub = _streamerService.statsStream.listen((stats) {
      if (!mounted) return;
      setState(() => _streamerStats = stats);
    });
  }

  void _listenToPersistentStreams() {
    // TCP persistent stream
    _tcpDataSub = _tcpService.dataStream.listen((chunk) {
      if (!mounted) return;
      setState(() {
        _rawResponseBytes.addAll(chunk);
        _response = HexConverter.bytesToCleanAscii(_rawResponseBytes);
        _responseTimestamp = DateTime.now();
      });
    });

    _tcpStateSub = _tcpService.connectionStateStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
      });
    });

    // WebSocket stream
    _wsMessageSub = _wsService.messageStream.listen((msg) {
      if (!mounted) return;
      setState(() {
        _rawResponseBytes.addAll(msg.rawBytes);
        _response = HexConverter.bytesToCleanAscii(_rawResponseBytes);
        _responseTimestamp = DateTime.now();
      });
    });

    _wsStateSub = _wsService.connectionStateStream.listen((connected) {
      if (!mounted) return;
      setState(() {
        _isConnecting = false;
      });
    });
  }

  @override
  void dispose() {
    _streamerSub?.cancel();
    _streamerService.dispose();

    _tcpDataSub?.cancel();
    _tcpStateSub?.cancel();
    _wsMessageSub?.cancel();
    _wsStateSub?.cancel();

    _tcpService.dispose();
    _wsService.dispose();

    _hostController.dispose();
    _portController.dispose();
    _dataController.dispose();
    super.dispose();
  }

  bool get _isPersistentProtocol =>
      _protocol == 'TCP (Persistent)' || _protocol == 'WebSocket';

  bool get _isCurrentlyConnected =>
      (_protocol == 'TCP (Persistent)' && _tcpService.isConnected) ||
      (_protocol == 'WebSocket' && _wsService.isConnected);

  bool get _isTcpReconnecting =>
      _protocol == 'TCP (Persistent)' &&
      _tcpService.isReconnecting &&
      !_isConnecting;

  // ------------------------------------------------------------
  // Toggle Connection for Persistent Protocols
  // ------------------------------------------------------------

  Future<void> _togglePersistentConnection() async {
    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());

    if (_isCurrentlyConnected) {
      setState(() => _isConnecting = true);
      if (_protocol == 'TCP (Persistent)') {
        await _tcpService.disconnect();
      } else {
        await _wsService.disconnect();
      }
      setState(() => _isConnecting = false);
      return;
    }

    if (host.isEmpty) {
      _showError('Please enter a host or IP address.');
      return;
    }

    if (port == null || port < 1 || port > 65535) {
      _showError('Please enter a valid port number.');
      return;
    }

    setState(() => _isConnecting = true);

    try {
      if (_protocol == 'TCP (Persistent)') {
        await _tcpService.connect(host: host, port: port);
        _showSuccess('Connected to TCP $host:$port');
      } else {
        final url = 'ws://$host:$port';
        await _wsService.connect(url);
        _showSuccess('Connected to WebSocket $url');
      }
    } catch (e) {
      _showError('Connection failed: $e');
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
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
      _showError('Invalid HEX data: $e');
      return;
    }

    if (packetData.isEmpty) {
      _showError('Packet data cannot be empty.');
      return;
    }

    // If persistent connection protocol and not connected, prompt
    if (_isPersistentProtocol && !_isCurrentlyConnected) {
      _showError('Please CONNECT to $host:$port first.');
      return;
    }

    setState(() {
      _isSending = true;
      if (!_isPersistentProtocol) {
        _rawResponseBytes = [];
        _response = '';
      }
    });

    String? responseText;
    List<int> receivedBytes = [];
    int? latency;
    String? errorMessage;

    try {
      if (_protocol == 'UDP') {
        final effectiveHost = _isBroadcast ? '255.255.255.255' : host;
        final result = await _udpService.sendPacket(
          host: effectiveHost,
          port: port,
          data: packetData,
          isBroadcast: _isBroadcast,
        );

        if (result == null) {
          responseText = 'No response received (Timeout).';
          receivedBytes = [];
        } else {
          responseText = result.data;
          receivedBytes = result.rawBytes;
          latency = result.latencyMs;
        }
      } else if (_protocol == 'TCP') {
        final result = await _tcpService.sendPacket(
          host: host,
          port: port,
          data: packetData,
        );

        if (result == null) {
          responseText = 'No response received (Timeout).';
          receivedBytes = [];
        } else {
          responseText = result.data;
          receivedBytes = result.rawBytes;
          latency = result.latencyMs;
        }
      } else if (_protocol == 'TCP (Persistent)') {
        await _tcpService.sendPersistent(packetData);
      } else if (_protocol == 'WebSocket') {
        if (_format == 'HEX') {
          _wsService.sendBytes(packetData);
        } else {
          _wsService.sendText(inputData);
        }
      }
    } catch (e) {
      errorMessage = e.toString();
      responseText = 'Error: $e';
    }

    if (!mounted) return;

    setState(() {
      if (!_isPersistentProtocol) {
        _response = responseText ?? '';
        _rawResponseBytes = receivedBytes;
        _responseLatencyMs = latency;
        _responseEndpoint = '$host:$port';
        _responseTimestamp = DateTime.now();
      }
      _isSending = false;
    });

    // Save to history
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
  // Continuous Packet Streamer
  // ------------------------------------------------------------

  void _toggleStreaming() {
    if (_streamerService.isStreaming) {
      _streamerService.stopStream();
      return;
    }

    final host = _hostController.text.trim();
    final port = int.tryParse(_portController.text.trim());
    final inputData = _dataController.text;

    if (host.isEmpty || port == null) {
      _showError('Please configure valid Host and Port first.');
      return;
    }

    if (inputData.isEmpty) {
      _showError('Please enter packet data to stream.');
      return;
    }

    List<int> bytes;
    try {
      if (_format == 'HEX') {
        bytes = HexConverter.hexToBytes(inputData);
      } else {
        bytes = inputData.codeUnits;
      }
    } catch (e) {
      _showError('Invalid HEX data: $e');
      return;
    }

    if (_isPersistentProtocol && !_isCurrentlyConnected) {
      _showError('Please CONNECT to $host:$port first.');
      return;
    }

    _streamerService.startStream(
      intervalMs: _streamIntervalMs,
      payload: bytes,
      sendCallback: (payload) async {
        try {
          if (_protocol == 'UDP') {
            final effectiveHost = _isBroadcast ? '255.255.255.255' : host;
            await _udpService.sendPacket(
              host: effectiveHost,
              port: port,
              data: payload,
              isBroadcast: _isBroadcast,
              timeout: Duration(milliseconds: _streamIntervalMs.clamp(40, 1000)),
            );
          } else if (_protocol == 'TCP') {
            await _tcpService.sendPacket(
              host: host,
              port: port,
              data: payload,
              timeout: Duration(milliseconds: _streamIntervalMs.clamp(40, 1000)),
            );
          } else if (_protocol == 'TCP (Persistent)') {
            await _tcpService.sendPersistent(payload);
          } else if (_protocol == 'WebSocket') {
            if (_format == 'HEX') {
              _wsService.sendBytes(payload);
            } else {
              _wsService.sendText(String.fromCharCodes(payload));
            }
          }
          return true;
        } catch (_) {
          return false;
        }
      },
    );
  }

  // ------------------------------------------------------------
  // Open Helpers: Scanner
  // ------------------------------------------------------------

  Future<void> _openEsp32Scanner() async {
    final selectedDevice = await showDialog<DiscoveredDevice>(
      context: context,
      builder: (_) => const Esp32ScannerDialog(),
    );

    if (selectedDevice != null && mounted) {
      setState(() {
        _hostController.text = selectedDevice.ip;
        _portController.text = selectedDevice.port.toString();
      });

      _showSuccess(
        'Selected ${selectedDevice.name} (${selectedDevice.ip}:${selectedDevice.port})',
      );
    }
  }

  // ------------------------------------------------------------
  // Save & Clear
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
      _showSuccess('Packet is saved.');
    } catch (e) {
      _showError('Could not save packet: $e');
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red.shade900,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _clearPacket() {
    _dataController.clear();
    setState(() {
      _response = '';
      _rawResponseBytes = [];
      _responseLatencyMs = null;
    });
  }

  // ------------------------------------------------------------
  // Build UI
  // ------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isStreaming = _streamerStats?.isStreaming ?? false;

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PacketFlowLogo(size: 26, borderRadius: 6, showGlow: false),
            SizedBox(width: 10),
            Text(
              'PacketFlow',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Scan for ESP32 devices',
            icon: const Icon(Icons.radar, color: Colors.cyanAccent),
            onPressed: _openEsp32Scanner,
          ),
        ],
      ),

      // ----------------------------------------------------------
      // Navigation Drawer
      // ----------------------------------------------------------

      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF0F172A), Color(0xFF1E1B4B)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const PacketFlowLogo(size: 44, borderRadius: 10),
                  const SizedBox(height: 10),
                  const Text(
                    'PacketFlow',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                  ),
                  
                ],
              ),
            ),

            ListTile(
              leading: const Icon(Icons.send, color: Colors.cyanAccent),
              title: const Text('Send Packet'),
              selected: true,
              selectedTileColor: Colors.cyanAccent.withOpacity(0.1),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.radar, color: Colors.cyanAccent),
              title: const Text('ESP32 Device Scanner'),
              onTap: () {
                Navigator.pop(context);
                _openEsp32Scanner();
              },
            ),
            ListTile(
              leading: const Icon(Icons.history, color: Color(0xFF818CF8)),
              title: const Text('History'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HistoryScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.bookmark, color: Color(0xFF818CF8)),
              title: const Text('Saved Packets'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const SavedPacketsScreen()),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.hearing, color: Colors.tealAccent),
              title: const Text('UDP Listener'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const UdpListenerScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.dns, color: Colors.tealAccent),
              title: const Text('TCP Server'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const TcpServerScreen()),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.language, color: Colors.tealAccent),
              title: const Text('HTTP / HTTPS'),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HttpScreen()),
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
              // Protocol Selector
              // --------------------------------------------------
              const Text(
                'PROTOCOL',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 8),

              DropdownButtonFormField<String>(
                value: _protocol,
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.router, color: Colors.cyanAccent),
                ),
                dropdownColor: const Color(0xFF1E293B),
                items: const [
                  DropdownMenuItem(value: 'UDP', child: Text('UDP (Datagram)')),
                  DropdownMenuItem(value: 'TCP', child: Text('TCP (Single Packet)')),
                  DropdownMenuItem(
                    value: 'TCP (Persistent)',
                    child: Text('TCP (Persistent Session)'),
                  ),
                  DropdownMenuItem(
                    value: 'WebSocket',
                    child: Text('WebSocket (ws://)'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _protocol = value;
                    _response = '';
                    _rawResponseBytes = [];
                  });
                },
              ),

              // --------------------------------------------------
              // UDP Broadcast Toggle (Only shown when protocol == UDP)
              // --------------------------------------------------
              if (_protocol == 'UDP') ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D33),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isBroadcast
                          ? Colors.cyanAccent.withOpacity(0.5)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.podcasts,
                        color: _isBroadcast
                            ? Colors.cyanAccent
                            : const Color(0xFF64748B),
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'UDP Broadcast Mode',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            Text(
                              _isBroadcast
                                  ? 'Targets 255.255.255.255 (ESP32 discovery)'
                                  : 'Targeting specified Host/IP address',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Color(0xFF94A3B8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isBroadcast,
                        activeColor: Colors.cyanAccent,
                        onChanged: (val) {
                          setState(() {
                            _isBroadcast = val;
                            if (val) {
                              _hostController.text = '255.255.255.255';
                            }
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // --------------------------------------------------
              // Persistent Session Bar (TCP Persistent & WebSocket)
              // --------------------------------------------------
              if (_isPersistentProtocol) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF131D33),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _isCurrentlyConnected
                          ? Colors.greenAccent.withOpacity(0.6)
                          : const Color(0xFF334155),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _isCurrentlyConnected
                              ? Colors.greenAccent
                              : const Color(0xFF64748B),
                          boxShadow: _isCurrentlyConnected
                              ? [
                                  BoxShadow(
                                    color: Colors.greenAccent.withOpacity(0.5),
                                    blurRadius: 6,
                                  ),
                                ]
                              : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isCurrentlyConnected
                              ? 'Connected (${_hostController.text}:${_portController.text})'
                              : _isTcpReconnecting
                                  ? 'Reconnecting...'
                              : 'Session Disconnected',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: _isCurrentlyConnected
                                ? Colors.greenAccent
                                : _isTcpReconnecting
                                    ? Colors.orangeAccent
                                : const Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                      ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _isCurrentlyConnected
                              ? Colors.redAccent.shade700
                              : Colors.cyanAccent,
                          foregroundColor: _isCurrentlyConnected
                              ? Colors.white
                              : const Color(0xFF0B132B),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                        onPressed: _isConnecting
                            ? null
                            : _togglePersistentConnection,
                        child: _isConnecting
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                _isCurrentlyConnected
                                    ? 'DISCONNECT'
                                    : 'CONNECT',
                                style: const TextStyle(fontSize: 12),
                              ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 18),

              // --------------------------------------------------
              // Host & Port Row
              // --------------------------------------------------
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Host / IP
                  Expanded(
                    flex: 6,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'HOST / IP ADDRESS',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _hostController,
                          keyboardType: TextInputType.url,
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: InputDecoration(
                            hintText: '192.168.1.10',
                            prefixIcon: const Icon(
                              Icons.memory,
                              color: Color(0xFF818CF8),
                            ),
                            suffixIcon: IconButton(
                              tooltip: 'Scan subnet for ESP32',
                              icon: const Icon(
                                Icons.radar,
                                color: Colors.cyanAccent,
                              ),
                              onPressed: _openEsp32Scanner,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(width: 12),

                  // Port
                  Expanded(
                    flex: 4,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'PORT',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.1,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _portController,
                          keyboardType: TextInputType.number,
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: '5000',
                            prefixIcon: Icon(
                              Icons.settings_ethernet,
                              color: Color(0xFF818CF8),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 18),

              // --------------------------------------------------
              // Data Format & Framing Helper Bar
              // --------------------------------------------------
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'PACKET DATA',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.1,
                      color: Color(0xFF94A3B8),
                    ),
                  ),
                  Row(
                    children: [
                      _buildFormatPill('ASCII'),
                      const SizedBox(width: 6),
                      _buildFormatPill('HEX'),
                    ],
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // --------------------------------------------------
              // Packet Data Input
              // --------------------------------------------------
              TextField(
                controller: _dataController,
                minLines: 4,
                maxLines: 8,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 14,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText: _format == 'ASCII'
                      ? 'Enter text packet or ESP32 command...'
                      : 'Example: AA 01 00 FF 55',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 50),
                    child: Icon(Icons.code, color: Colors.cyanAccent),
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // Continuous Streamer Panel (FPS / Keep-Alive)
              // --------------------------------------------------
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF131D33),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isStreaming
                        ? Colors.cyanAccent.withOpacity(0.7)
                        : const Color(0xFF334155),
                  ),
                ),
                child: Column(
                  children: [
                    // Streamer Header Tile
                    InkWell(
                      onTap: () => setState(() =>
                          _showStreamerSection = !_showStreamerSection),
                      borderRadius: BorderRadius.circular(12),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.speed,
                              color: isStreaming
                                  ? Colors.cyanAccent
                                  : const Color(0xFF94A3B8),
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Continuous Packet Streamer (FPS / Keep-Alive)',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.bold,
                                  color: isStreaming
                                      ? Colors.cyanAccent
                                      : Colors.white,
                                ),
                              ),
                            ),
                            if (isStreaming) ...[
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.cyanAccent.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  '${_streamerStats?.currentFps.toStringAsFixed(1) ?? "0"} FPS',
                                  style: const TextStyle(
                                    color: Colors.cyanAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 6),
                            ],
                            Icon(
                              _showStreamerSection
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: const Color(0xFF94A3B8),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Expandable Streamer Settings & Stats
                    if (_showStreamerSection || isStreaming) ...[
                      const Divider(color: Color(0xFF1E293B), height: 1),
                      Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Interval Presets Row
                            Row(
                              children: [
                                const Text(
                                  'Rate:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFF94A3B8),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: SingleChildScrollView(
                                    scrollDirection: Axis.horizontal,
                                    child: Row(
                                      children: [
                                        _buildIntervalChip(33, '33ms (~30 FPS)'),
                                        const SizedBox(width: 6),
                                        _buildIntervalChip(50, '50ms (20 FPS)'),
                                        const SizedBox(width: 6),
                                        _buildIntervalChip(100, '100ms (10 FPS)'),
                                        const SizedBox(width: 6),
                                        _buildIntervalChip(1000, '1s (Keep-Alive)'),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            // Realtime Streaming Metrics Dashboard
                            if (_streamerStats != null) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0F172A),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceAround,
                                  children: [
                                    _buildStatItem(
                                      'FPS',
                                      _streamerStats!.currentFps
                                          .toStringAsFixed(1),
                                      Colors.cyanAccent,
                                    ),
                                    _buildStatItem(
                                      'SENT',
                                      '${_streamerStats!.packetsSent}',
                                      Colors.greenAccent,
                                    ),
                                    _buildStatItem(
                                      'DROPPED',
                                      '${_streamerStats!.packetsFailed}',
                                      _streamerStats!.packetsFailed > 0
                                          ? Colors.redAccent
                                          : const Color(0xFF94A3B8),
                                    ),
                                    _buildStatItem(
                                      'ELAPSED',
                                      '${_streamerStats!.elapsed.inSeconds}s',
                                      Colors.white,
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            const SizedBox(height: 12),

                            // Start / Stop Streamer Button
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: isStreaming
                                      ? Colors.redAccent.shade700
                                      : Colors.cyanAccent.shade700,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12),
                                ),
                                onPressed: _toggleStreaming,
                                icon: Icon(isStreaming
                                    ? Icons.stop
                                    : Icons.play_arrow),
                                label: Text(
                                  isStreaming
                                      ? 'STOP STREAMING'
                                      : 'START CONTINUOUS STREAM',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // --------------------------------------------------
              // Action Buttons: Send & Save
              // --------------------------------------------------
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isSending ? null : _sendPacket,
                  icon: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0B132B),
                          ),
                        )
                      : const Icon(Icons.send),
                  label: Text(
                    _isSending
                        ? 'TRANSMITTING...'
                        : (_isPersistentProtocol && _isCurrentlyConnected
                            ? 'SEND THROUGH STREAM'
                            : 'SEND SINGLE PACKET'),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saveCurrentPacket,
                      icon: const Icon(Icons.bookmark_add, size: 18),
                      label: const Text('SAVE PACKET'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton.icon(
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF94A3B8),
                      ),
                      onPressed: _clearPacket,
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('CLEAR'),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 24),

              // --------------------------------------------------
              // Dual Response Inspector (ASCII + Hex Dump)
              // --------------------------------------------------
              const Text(
                'RESPONSE INSPECTOR',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Color(0xFF94A3B8),
                ),
              ),
              const SizedBox(height: 8),

              ResponseInspector(
                rawBytes: _rawResponseBytes,
                textResponse: _response,
                latencyMs: _responseLatencyMs,
                fromEndpoint: _responseEndpoint,
                timestamp: _responseTimestamp,
                onClear: () {
                  setState(() {
                    _rawResponseBytes = [];
                    _response = '';
                    _responseLatencyMs = null;
                  });
                },
              ),

              const SizedBox(height: 20),

              // --------------------------------------------------
              // Active Hardware Target Card
              // --------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.memory,
                            color: Colors.cyanAccent,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Active Hardware Target',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.cyanAccent.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              _protocol,
                              style: const TextStyle(
                                color: Colors.cyanAccent,
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _targetRow(
                        'Target',
                        _isBroadcast
                            ? '255.255.255.255 (Broadcast)'
                            : '${_hostController.text}:${_portController.text}',
                      ),
                      _targetRow('Payload Format', _format),
                      _targetRow(
                        'Mode',
                        _isPersistentProtocol
                            ? (_isCurrentlyConnected
                                ? 'Persistent Pipe (Live)'
                                : 'Persistent Pipe (Offline)')
                            : 'Datagram / Request-Response',
                      ),
                      _targetRow(
                        'Continuous Streamer',
                        isStreaming
                            ? 'ACTIVE (${_streamIntervalMs}ms / ${_streamerStats?.currentFps.toStringAsFixed(1) ?? "0"} FPS)'
                            : 'Idle',
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

  Widget _buildIntervalChip(int ms, String label) {
    final isSelected = _streamIntervalMs == ms;
    return GestureDetector(
      onTap: () {
        setState(() => _streamIntervalMs = ms);
        if (_streamerService.isStreaming) {
          _toggleStreaming(); // Restart with new interval
          _toggleStreaming();
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withOpacity(0.25)
              : const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : const Color(0xFF334155),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.cyanAccent : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String title, String val, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 10, color: Color(0xFF94A3B8)),
        ),
        const SizedBox(height: 2),
        Text(
          val,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: color,
            fontFamily: 'monospace',
          ),
        ),
      ],
    );
  }

  Widget _buildFormatPill(String format) {
    final isSelected = _format == format;
    return GestureDetector(
      onTap: () => setState(() => _format = format),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withOpacity(0.2)
              : const Color(0xFF131D33),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? Colors.cyanAccent : const Color(0xFF334155),
          ),
        ),
        child: Text(
          format,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.cyanAccent : const Color(0xFF94A3B8),
          ),
        ),
      ),
    );
  }

  Widget _targetRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          SizedBox(
            width: 140,
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 12,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: Colors.white,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}