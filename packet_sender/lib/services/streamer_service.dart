import 'dart:async';

class StreamerStats {
  final bool isStreaming;
  final int packetsSent;
  final int packetsFailed;
  final double currentFps;
  final Duration elapsed;
  final int intervalMs;

  StreamerStats({
    required this.isStreaming,
    required this.packetsSent,
    required this.packetsFailed,
    required this.currentFps,
    required this.elapsed,
    required this.intervalMs,
  });
}

class PacketStreamerService {
  Timer? _timer;
  Timer? _statsTimer;
  Stopwatch? _stopwatch;

  bool _isStreaming = false;
  int _packetsSent = 0;
  int _packetsFailed = 0;
  int _intervalMs = 100;
  List<int> _currentPayload = [];

  // FPS calculation window
  int _packetsInWindow = 0;
  double _currentFps = 0.0;
  DateTime _lastFpsCalc = DateTime.now();

  final _statsController = StreamController<StreamerStats>.broadcast();
  Stream<StreamerStats> get statsStream => _statsController.stream;

  bool get isStreaming => _isStreaming;
  int get packetsSent => _packetsSent;
  int get packetsFailed => _packetsFailed;
  double get currentFps => _currentFps;
  Duration get elapsed => _stopwatch?.elapsed ?? Duration.zero;

  void startStream({
    required int intervalMs,
    required List<int> payload,
    required Future<bool> Function(List<int> data) sendCallback,
  }) {
    if (_isStreaming) stopStream();

    _isStreaming = true;
    _intervalMs = intervalMs;
    _currentPayload = List.from(payload);
    _packetsSent = 0;
    _packetsFailed = 0;
    _packetsInWindow = 0;
    _currentFps = 0.0;
    _lastFpsCalc = DateTime.now();

    _stopwatch = Stopwatch()..start();

    // Stats emission timer (every 150ms for smooth UI updates)
    _statsTimer = Timer.periodic(const Duration(milliseconds: 150), (_) {
      _computeFps();
      _emitStats();
    });

    // Transmission timer
    _timer = Timer.periodic(Duration(milliseconds: intervalMs), (t) async {
      if (!_isStreaming) {
        t.cancel();
        return;
      }

      try {
        final success = await sendCallback(_currentPayload);
        if (success) {
          _packetsSent++;
          _packetsInWindow++;
        } else {
          _packetsFailed++;
        }
      } catch (_) {
        _packetsFailed++;
      }
    });

    _emitStats();
  }

  void updatePayload(List<int> newPayload) {
    _currentPayload = List.from(newPayload);
  }

  void _computeFps() {
    final now = DateTime.now();
    final diffMs = now.difference(_lastFpsCalc).inMilliseconds;
    if (diffMs >= 500) {
      _currentFps = (_packetsInWindow / (diffMs / 1000.0));
      _packetsInWindow = 0;
      _lastFpsCalc = now;
    }
  }

  void _emitStats() {
    if (_statsController.isClosed) return;
    _statsController.add(
      StreamerStats(
        isStreaming: _isStreaming,
        packetsSent: _packetsSent,
        packetsFailed: _packetsFailed,
        currentFps: _currentFps,
        elapsed: _stopwatch?.elapsed ?? Duration.zero,
        intervalMs: _intervalMs,
      ),
    );
  }

  void stopStream() {
    _isStreaming = false;
    _timer?.cancel();
    _timer = null;
    _statsTimer?.cancel();
    _statsTimer = null;
    _stopwatch?.stop();
    _currentFps = 0.0;
    _emitStats();
  }

  void dispose() {
    stopStream();
    _statsController.close();
  }
}
