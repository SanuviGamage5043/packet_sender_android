class Packet {
  final String protocol;
  final String host;
  final int port;
  final String data;
  final String format;
  final String? response;
  final DateTime timestamp;

  Packet({
    required this.protocol,
    required this.host,
    required this.port,
    required this.data,
    required this.format,
    this.response,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() {
    return {
      'protocol': protocol,
      'host': host,
      'port': port,
      'data': data,
      'format': format,
      'response': response,
      'timestamp': timestamp.toIso8601String(),
    };
  }

  factory Packet.fromJson(Map<String, dynamic> json) {
    return Packet(
      protocol: json['protocol'],
      host: json['host'],
      port: json['port'],
      data: json['data'],
      format: json['format'],
      response: json['response'],
      timestamp: DateTime.parse(json['timestamp']),
    );
  }
}