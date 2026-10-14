import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/hex_converter.dart';

enum InspectorMode { ascii, hexDump }

class ResponseInspector extends StatefulWidget {
  final List<int> rawBytes;
  final String? textResponse;
  final int? latencyMs;
  final String? fromEndpoint;
  final DateTime? timestamp;
  final VoidCallback? onClear;

  const ResponseInspector({
    super.key,
    required this.rawBytes,
    this.textResponse,
    this.latencyMs,
    this.fromEndpoint,
    this.timestamp,
    this.onClear,
  });

  @override
  State<ResponseInspector> createState() => _ResponseInspectorState();
}

class _ResponseInspectorState extends State<ResponseInspector> {
  InspectorMode _mode = InspectorMode.ascii;

  void _copyToClipboard(BuildContext context) {
    String textToCopy;
    if (_mode == InspectorMode.hexDump) {
      textToCopy = HexConverter.bytesToHexDump(widget.rawBytes);
    } else {
      textToCopy = widget.textResponse ??
          HexConverter.bytesToCleanAscii(widget.rawBytes);
    }

    Clipboard.setData(ClipboardData(text: textToCopy));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _mode == InspectorMode.hexDump
              ? 'HEX Dump copied to clipboard.'
              : 'ASCII text copied to clipboard.',
        ),
        backgroundColor: const Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _copyRawHex(BuildContext context) {
    final hexString = HexConverter.bytesToHex(widget.rawBytes);
    Clipboard.setData(ClipboardData(text: hexString));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Raw HEX bytes copied to clipboard.'),
        backgroundColor: Color(0xFF1E293B),
        behavior: SnackBarBehavior.floating,
        duration: Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasData = widget.rawBytes.isNotEmpty ||
        (widget.textResponse != null && widget.textResponse!.isNotEmpty);

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0B132B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: hasData
              ? Colors.cyanAccent.withOpacity(0.3)
              : const Color(0xFF1E293B),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Inspector Header Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF131D33),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(11),
                topRight: Radius.circular(11),
              ),
            ),
            child: Row(
              children: [
                // Mode Toggle
                Container(
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildToggleButton(
                        label: 'ASCII',
                        isSelected: _mode == InspectorMode.ascii,
                        onTap: () =>
                            setState(() => _mode = InspectorMode.ascii),
                      ),
                      _buildToggleButton(
                        label: 'HEX DUMP',
                        isSelected: _mode == InspectorMode.hexDump,
                        onTap: () =>
                            setState(() => _mode = InspectorMode.hexDump),
                      ),
                    ],
                  ),
                ),

                const Spacer(),

                // Metadata Metrics
                if (hasData) ...[
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
                      '${widget.rawBytes.length} B',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.cyanAccent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  if (widget.latencyMs != null && widget.latencyMs! > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.indigo.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${widget.latencyMs} ms',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF818CF8),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  // Actions Menu
                  PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_vert,
                      color: Colors.white70,
                      size: 20,
                    ),
                    color: const Color(0xFF1E293B),
                    onSelected: (val) {
                      if (val == 'copy_view') _copyToClipboard(context);
                      if (val == 'copy_hex') _copyRawHex(context);
                      if (val == 'clear') widget.onClear?.call();
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'copy_view',
                        child: Row(
                          children: [
                            Icon(Icons.copy, size: 18, color: Colors.cyanAccent),
                            SizedBox(width: 8),
                            Text('Copy Current View', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'copy_hex',
                        child: Row(
                          children: [
                            Icon(Icons.code, size: 18, color: Color(0xFF818CF8)),
                            SizedBox(width: 8),
                            Text('Copy Raw HEX', style: TextStyle(color: Colors.white)),
                          ],
                        ),
                      ),
                      const PopupMenuDivider(height: 1),
                      const PopupMenuItem(
                        value: 'clear',
                        child: Row(
                          children: [
                            Icon(Icons.delete_outline, size: 18, color: Colors.redAccent),
                            SizedBox(width: 8),
                            Text('Clear Output', style: TextStyle(color: Colors.redAccent)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),

          // Content Display Area
          Container(
            padding: const EdgeInsets.all(14),
            constraints: const BoxConstraints(minHeight: 140, maxHeight: 260),
            child: !hasData
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.terminal,
                          size: 36,
                          color: Color(0xFF334155),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'No response received yet.',
                          style: TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 13,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Ready to capture ESP32 ASCII or raw HEX packets',
                          style: TextStyle(
                            color: Color(0xFF475569),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  )
                : SingleChildScrollView(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SelectableText(
                        _mode == InspectorMode.hexDump
                            ? HexConverter.bytesToHexDump(widget.rawBytes)
                            : (widget.textResponse != null &&
                                    widget.textResponse!.isNotEmpty
                                ? widget.textResponse!
                                : HexConverter.bytesToCleanAscii(
                                    widget.rawBytes)),
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12.5,
                          height: 1.45,
                          color: _mode == InspectorMode.hexDump
                              ? const Color(0xFF38BDF8)
                              : Colors.tealAccent.shade100,
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: isSelected
              ? Colors.cyanAccent.withOpacity(0.2)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
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
}
