import 'dart:async';
import 'dart:io';

class DiscoveredDevice {
  final String ip;
  final int port;
  final String name;
  final String type;
  final int latencyMs;
  final String? extraInfo;

  DiscoveredDevice({
    required this.ip,
    required this.port,
    required this.name,
    required this.type,
    this.latencyMs = 0,
    this.extraInfo,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DiscoveredDevice &&
          runtimeType == other.runtimeType &&
          ip == other.ip &&
          port == other.port;

  @override
  int get hashCode => ip.hashCode ^ port.hashCode;
}

class NetworkScannerService {
  bool _isScanning = false;
  bool get isScanning => _isScanning;

  /// Gets the local IPv4 address and subnet prefix (e.g. "192.168.1.").
  Future<Map<String, String>> getLocalNetworkInfo() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );

      for (final interface in interfaces) {
        for (final addr in interface.addresses) {
          final ip = addr.address;
          if (ip.startsWith('192.168.') ||
              ip.startsWith('10.') ||
              ip.startsWith('172.')) {
            final parts = ip.split('.');
            if (parts.length == 4) {
              final subnet = '${parts[0]}.${parts[1]}.${parts[2]}.';
              final broadcast = '${parts[0]}.${parts[1]}.${parts[2]}.255';
              return {
                'ip': ip,
                'subnet': subnet,
                'broadcast': broadcast,
                'interface': interface.name,
              };
            }
          }
        }
      }
    } catch (_) {}

    return {
      'ip': '192.168.1.100',
      'subnet': '192.168.1.',
      'broadcast': '255.255.255.255',
      'interface': 'default',
    };
  }

  /// Runs an ESP32 & IoT discovery scan combining mDNS, UDP Broadcast, and subnet probe.
  Stream<DiscoveredDevice> scan({
    void Function(double progress, String status)? onProgress,
  }) async* {
    if (_isScanning) return;
    _isScanning = true;

    final discoveredSet = <String>{};
    final netInfo = await getLocalNetworkInfo();
    final localIp = netInfo['ip'] ?? '';
    final subnet = netInfo['subnet'] ?? '192.168.1.';
    final broadcastIp = netInfo['broadcast'] ?? '255.255.255.255';

    onProgress?.call(0.1, 'Probing mDNS & IoT hostnames...');

    // -------------------------------------------------------------------------
    // 1. mDNS and Well-known Hostname Probing
    // -------------------------------------------------------------------------
    final hostnames = [
      'esp32.local',
      'wled.local',
      'espressif.local',
      'packetflow.local',
      'nodemcu.local',
      'ledpanel.local',
    ];

    for (final host in hostnames) {
      try {
        final stopwatch = Stopwatch()..start();
        final addresses = await InternetAddress.lookup(host)
            .timeout(const Duration(milliseconds: 600));

        if (addresses.isNotEmpty) {
          final foundIp = addresses.first.address;
          stopwatch.stop();

          final key = '$foundIp:80';
          if (!discoveredSet.contains(key)) {
            discoveredSet.add(key);
            yield DiscoveredDevice(
              ip: foundIp,
              port: 80,
              name: host.replaceAll('.local', '').toUpperCase(),
              type: 'mDNS Service',
              latencyMs: stopwatch.elapsedMilliseconds,
              extraInfo: 'Resolved via $host',
            );
          }
        }
      } catch (_) {}
    }

    onProgress?.call(0.3, 'Sending UDP Broadcast pings...');

    // -------------------------------------------------------------------------
    // 2. UDP Broadcast Discovery Probe
    // -------------------------------------------------------------------------
    try {
      final probePorts = [5000, 8266, 21324, 8080];
      final probePayload = 'PACKETFLOW_DISCOVER'.codeUnits;

      for (final port in probePorts) {
        RawDatagramSocket? socket;
        try {
          socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
          socket.broadcastEnabled = true;

          // Broadcast to global and subnet broadcast
          final bTarget = InternetAddress.tryParse(broadcastIp) ??
              InternetAddress('255.255.255.255');
          socket.send(probePayload, bTarget, port);

          final completer = Completer<void>();
          final sub = socket.listen((event) {
            if (event == RawSocketEvent.read) {
              final dg = socket?.receive();
              if (dg != null) {
                final rIp = dg.address.address;
                final key = '$rIp:$port';
                if (!discoveredSet.contains(key)) {
                  discoveredSet.add(key);
                }
              }
            }
          });

          await Future.delayed(const Duration(milliseconds: 400));
          await sub.cancel();
          socket.close();
        } catch (_) {
          socket?.close();
        }
      }
    } catch (_) {}

    onProgress?.call(0.5, 'Sweeping local subnet for open ESP32 ports...');

    // -------------------------------------------------------------------------
    // 3. Subnet Sweep on Common IoT Ports (80, 5000, 81, 8080)
    // -------------------------------------------------------------------------
    const targetPorts = [80, 5000, 81, 8080];
    const batchSize = 32;

    // Scan IPs from 1 to 254 in batches
    final ipsToScan = <String>[];
    for (int i = 1; i <= 254; i++) {
      final candidateIp = '$subnet$i';
      if (candidateIp != localIp) {
        ipsToScan.add(candidateIp);
      }
    }

    int completed = 0;
    final totalIps = ipsToScan.length;

    for (int i = 0; i < ipsToScan.length; i += batchSize) {
      final batch = ipsToScan.skip(i).take(batchSize).toList();

      final futures = batch.map((ip) async {
        for (final port in targetPorts) {
          final key = '$ip:$port';
          if (discoveredSet.contains(key)) continue;

          final sw = Stopwatch()..start();
          Socket? testSocket;
          try {
            testSocket = await Socket.connect(
              ip,
              port,
              timeout: const Duration(milliseconds: 280),
            );
            sw.stop();

            String devName = 'ESP32 / IoT Device';
            if (port == 80) devName = 'HTTP Web Server';
            if (port == 5000) devName = 'PacketFlow / UDP Node';
            if (port == 81) devName = 'WebSocket Service';
            if (port == 8080) devName = 'IoT Server';

            discoveredSet.add(key);
            return DiscoveredDevice(
              ip: ip,
              port: port,
              name: devName,
              type: 'Port $port Active',
              latencyMs: sw.elapsedMilliseconds,
              extraInfo: 'Subnet device at $ip',
            );
          } catch (_) {
            // Port closed / unreachable
          } finally {
            await testSocket?.close();
          }
        }
        return null;
      });

      final results = await Future.wait(futures);
      for (final device in results) {
        if (device != null) {
          yield device;
        }
      }

      completed += batch.length;
      final progress = 0.5 + (completed / totalIps) * 0.5;
      onProgress?.call(
        progress.clamp(0.0, 1.0),
        'Scanning subnet (${completed}/$totalIps)...',
      );
    }

    onProgress?.call(1.0, 'Scan completed!');
    _isScanning = false;
  }

  void cancel() {
    _isScanning = false;
  }
}
