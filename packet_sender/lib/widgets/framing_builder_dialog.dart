import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/checksum_helper.dart';
import '../utils/hex_converter.dart';

class FramingBuilderDialog extends StatefulWidget {
  final String? initialPayloadHex;

  const FramingBuilderDialog({super.key, this.initialPayloadHex});

  @override
  State<FramingBuilderDialog> createState() => _FramingBuilderDialogState();
}

class _FramingBuilderDialogState extends State<FramingBuilderDialog> {
  final TextEditingController _headerController =
      TextEditingController(text: 'AA');
  final TextEditingController _commandController =
      TextEditingController(text: '01');
  final TextEditingController _payloadController =
      TextEditingController(text: 'FF 00 00');
  final TextEditingController _footerController =
      TextEditingController(text: '55');

  LengthFormat _lengthFormat = LengthFormat.oneByte;
  ChecksumType _checksumType = ChecksumType.crc8Standard;
  bool _checksumIncludesHeader = false;

  List<int> _compiledFrame = [];
  String _compiledHex = '';

  @override
  void initState() {
    super.initState();
    if (widget.initialPayloadHex != null &&
        widget.initialPayloadHex!.isNotEmpty) {
      _payloadController.text = widget.initialPayloadHex!;
    }
    _recalculateFrame();
  }

  void _recalculateFrame() {
    List<int> headerBytes = [];
    List<int> commandBytes = [];
    List<int> payloadBytes = [];
    List<int> footerBytes = [];

    try {
      if (_headerController.text.trim().isNotEmpty) {
        headerBytes = HexConverter.hexToBytes(_headerController.text);
      }
      if (_commandController.text.trim().isNotEmpty) {
        commandBytes = HexConverter.hexToBytes(_commandController.text);
      }
      if (_payloadController.text.trim().isNotEmpty) {
        payloadBytes = HexConverter.hexToBytes(_payloadController.text);
      }
      if (_footerController.text.trim().isNotEmpty) {
        footerBytes = HexConverter.hexToBytes(_footerController.text);
      }
    } catch (_) {
      // Partial typing, ignore
    }

    final frame = ChecksumHelper.buildFrame(
      header: headerBytes,
      commandId: commandBytes,
      payload: payloadBytes,
      lengthFormat: _lengthFormat,
      checksumType: _checksumType,
      footer: footerBytes,
      checksumIncludesHeader: _checksumIncludesHeader,
    );

    setState(() {
      _compiledFrame = frame;
      _compiledHex = HexConverter.bytesToHex(frame);
    });
  }

  @override
  void dispose() {
    _headerController.dispose();
    _commandController.dispose();
    _payloadController.dispose();
    _footerController.dispose();
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
        constraints: const BoxConstraints(maxHeight: 650, maxWidth: 520),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.cyanAccent.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.dashboard_customize,
                    color: Colors.cyanAccent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Packet Framing & Checksum Helper',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'ESP32 & Microcontroller binary framing builder',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
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
            const Divider(color: Color(0xFF334155), height: 1),
            const SizedBox(height: 14),

            // Form Fields
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Header & Command ID
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'HEADER (HEX)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _headerController,
                                style: const TextStyle(fontFamily: 'monospace'),
                                decoration: const InputDecoration(
                                  hintText: 'AA',
                                  isDense: true,
                                ),
                                onChanged: (_) => _recalculateFrame(),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'COMMAND ID (HEX)',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              TextField(
                                controller: _commandController,
                                style: const TextStyle(fontFamily: 'monospace'),
                                decoration: const InputDecoration(
                                  hintText: '01',
                                  isDense: true,
                                ),
                                onChanged: (_) => _recalculateFrame(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Payload input
                    const Text(
                      'PAYLOAD (HEX BYTES)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF94A3B8),
                      ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: _payloadController,
                      style: const TextStyle(fontFamily: 'monospace'),
                      decoration: const InputDecoration(
                        hintText: 'FF 00 00 (e.g. RGB red)',
                        isDense: true,
                      ),
                      onChanged: (_) => _recalculateFrame(),
                    ),

                    const SizedBox(height: 14),

                    // Row 2: Length Field & Checksum Type
                    Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'LENGTH FIELD',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<LengthFormat>(
                                value: _lengthFormat,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF0F172A),
                                decoration: const InputDecoration(isDense: true),
                                items: const [
                                  DropdownMenuItem(
                                    value: LengthFormat.none,
                                    child: Text('None', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: LengthFormat.oneByte,
                                    child: Text('1 Byte', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: LengthFormat.twoBytesBigEndian,
                                    child: Text('2B (Big Endian)', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: LengthFormat.twoBytesLittleEndian,
                                    child: Text('2B (Little Endian)', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _lengthFormat = val);
                                    _recalculateFrame();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'CHECKSUM ALGO',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              const SizedBox(height: 6),
                              DropdownButtonFormField<ChecksumType>(
                                value: _checksumType,
                                isExpanded: true,
                                dropdownColor: const Color(0xFF0F172A),
                                decoration: const InputDecoration(isDense: true),
                                items: const [
                                  DropdownMenuItem(
                                    value: ChecksumType.none,
                                    child: Text('None', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: ChecksumType.xor,
                                    child: Text('XOR Checksum', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: ChecksumType.sum8,
                                    child: Text('8-bit Sum (Mod 256)', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: ChecksumType.crc8Standard,
                                    child: Text('CRC-8 (Std 0x07)', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: ChecksumType.crc8Maxim,
                                    child: Text('CRC-8 (Maxim 0x31)', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: ChecksumType.crc16Modbus,
                                    child: Text('CRC-16 (Modbus)', style: TextStyle(fontSize: 12)),
                                  ),
                                  DropdownMenuItem(
                                    value: ChecksumType.crc16Ccitt,
                                    child: Text('CRC-16 (CCITT)', style: TextStyle(fontSize: 12)),
                                  ),
                                ],
                                onChanged: (val) {
                                  if (val != null) {
                                    setState(() => _checksumType = val);
                                    _recalculateFrame();
                                  }
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Footer
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'FOOTER (HEX)',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: _footerController,
                          style: const TextStyle(fontFamily: 'monospace'),
                          decoration: const InputDecoration(
                            hintText: '55',
                            isDense: true,
                          ),
                          onChanged: (_) => _recalculateFrame(),
                        ),
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Result Preview Card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: Colors.cyanAccent.withOpacity(0.4),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'COMPILED FRAME',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.cyanAccent,
                                ),
                              ),
                              Text(
                                '${_compiledFrame.length} bytes',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            _compiledHex.isEmpty ? 'Waiting for input...' : _compiledHex,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Color(0xFF475569)),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _compiledHex));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Frame copied to clipboard.'),
                          backgroundColor: Color(0xFF1E293B),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('COPY HEX'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.cyanAccent,
                      foregroundColor: const Color(0xFF0B132B),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () {
                      Navigator.pop(context, _compiledHex);
                    },
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('USE IN SENDER'),
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
