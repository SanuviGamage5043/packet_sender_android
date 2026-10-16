import 'dart:convert';
import 'dart:io';

class HttpResponseData {
  final int statusCode;
  final String body;

  HttpResponseData({
    required this.statusCode,
    required this.body,
  });
}

class HttpService {
  /// true = accept ANY HTTPS certificate (self-signed ESP32). Testing only.
  static const bool allowSelfSignedCerts = true;

  Future<HttpResponseData> sendRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    String? body,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 8)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => allowSelfSignedCerts;

    try {
      final uri = Uri.parse(url.trim());

      final request = await client.openUrl(
        method.toUpperCase(),
        uri,
      );
      request.persistentConnection = false;

      // Add headers
      if (headers != null) {
        headers.forEach((key, value) {
          request.headers.set(key, value);
        });
      }

      // Add JSON body
      if (body != null && body.trim().isNotEmpty) {
        final bytes = utf8.encode(body);
        request.headers.contentType = ContentType.json;
        request.contentLength = bytes.length;
        request.add(bytes);
      }

      final response = await request.close();
      final responseBody = await utf8.decoder.bind(response).join();

      return HttpResponseData(
        statusCode: response.statusCode,
        body: responseBody,
      );
    } catch (e) {
      throw Exception('HTTP request failed: $e');
    } finally {
      client.close(force: true);
    }
  }
}