import 'dart:convert';
import 'dart:io';

import 'certificate_service.dart';

class HttpResponseData {
  final int statusCode;
  final String body;

  HttpResponseData({
    required this.statusCode,
    required this.body,
  });
}

class HttpService {
  Future<HttpResponseData> sendRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    String? body,
    bool allowInvalidCert = false, // testing only, HTTPS
  }) async {
    final ctx = await CertificateService().buildContext();
    final client = HttpClient(context: ctx)
      ..connectionTimeout = const Duration(seconds: 8)
      ..badCertificateCallback =
          (X509Certificate cert, String host, int port) => allowInvalidCert;

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