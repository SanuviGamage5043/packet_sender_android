import 'dart:async';
import 'package:flutter/material.dart';

import '../services/scanner_service.dart';

class Esp32ScannerDialog extends StatefulWidget {
  const Esp32ScannerDialog({super.key});

  @override
  State<Esp32ScannerDialog> createState() => _Esp32ScannerDialogState();
}

class _Esp32ScannerDialogState extends State<Esp32ScannerDialog> {
  final NetworkScannerService _scanner = NetworkScannerService();
  final List<DiscoveredDevice> _devices = [];

  bool _isScanning = false;
  double _progress = 0.0;
  String _status = 'Ready to scan';
  String _localIp = '';
  String _subnet = '';
  StreamSubscription? _scanSubscription;

  @override
  void initState() {
    super.initState();
    _initAndStartScan();
  }

  Future<void> _initAndStartScan() async {
    final netInfo = await _scanner.getLocalNetworkInfo();
    if (!mounted) return;

    setState(() {
      _localIp = netInfo['ip'] ?? '';
      _subnet = netInfo['subnet'] ?? '';
    });

    _startScan();
  }

  void _startScan() {
    setState(() {
      _devices.clear();
      _isScanning = true;
      _progress = 0.05;
      _status = 'Starting discovery scan...';
    });

    _scanSubscription?.cancel();
    _scanSubscription = _scanner.scan(
      onProgress: (progress, status) {
        if (!mounted) return;
        setState(() {
          _progress = progress;
          _status = status;
        });
      },
    ).listen(
      (device) {
        if (!mounted) return;
        setState(() {
          if (!_devices.contains(device)) {
            _devices.add(device);
          }
        });
      },
      onDone: () {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _progress = 1.0;
          _status = 'Scan complete (${_devices.length} found)';
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _isScanning = false;
          _status = 'Error: $e';
        });
      },
    );
  }

  @override
  void dispose() {
    _scanSubscription?.cancel();
    _scanner.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF334155)),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 580, maxWidth: 500),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.radar,
                    color: Colors.cyanAccent,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'ESP32 & Network Scanner',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _localIp.isNotEmpty
                            ? 'Subnet: $_subnet* (Your IP: $_localIp)'
                            : 'Scanning local network...',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF94A3B8),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: Colors.white70),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Progress bar and status
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: _isScanning ? (_progress > 0 ? _progress : null) : 1.0,
                backgroundColor: const Color(0xFF0F172A),
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isScanning ? Colors.cyanAccent : Colors.tealAccent,
                ),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    _status,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF94A3B8),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (_isScanning)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor:
                          AlwaysStoppedAnimation<Color>(Colors.cyanAccent),
                    ),
                  )
                else
                  Text(
                    '${_devices.length} Found',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.cyanAccent,
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 10),

            // Devices List
            Expanded(
              child: _devices.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            _isScanning
                                ? Icons.wifi_find
                                : Icons.devices_other,
                            size: 48,
                            color: const Color(0xFF64748B),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _isScanning
                                ? 'Scanning for ESP32 and IoT nodes...'
                                : 'No devices found on this subnet.',
                            style: const TextStyle(
                              color: Color(0xFF94A3B8),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            'Ensure phone and ESP32 are on the same 2.4GHz Wi-Fi.',
                            style: TextStyle(
                              color: Color(0xFF64748B),
                              fontSize: 12,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _devices.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final dev = _devices[index];
                        return Container(
                          decoration: BoxDecoration(
                            color: const Color(0xFF0F172A),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFF334155),
                            ),
                          ),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 4,
                            ),
                            leading: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withValues(alpha: 0.3),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.memory,
                                color: Colors.cyanAccent,
                                size: 22,
                              ),
                            ),
                            title: Text(
                              dev.ip,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                fontFamily: 'monospace',
                              ),
                            ),
                            subtitle: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  margin: const EdgeInsets.only(top: 4),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1E293B),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    'Port ${dev.port}',
                                    style: const TextStyle(
                                      color: Colors.cyanAccent,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    dev.name,
                                    style: const TextStyle(
                                      color: Color(0xFF94A3B8),
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            trailing: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.cyanAccent.shade700,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: () {
                                Navigator.pop(context, dev);
                              },
                              child: const Text(
                                'SELECT',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),

            const SizedBox(height: 14),

            // Footer action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF475569)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: _isScanning
                        ? () {
                            _scanSubscription?.cancel();
                            _scanner.cancel();
                            setState(() => _isScanning = false);
                          }
                        : _startScan,
                    icon: Icon(_isScanning ? Icons.stop : Icons.refresh),
                    label: Text(_isScanning ? 'STOP' : 'RESCAN'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF334155),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('CLOSE'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
