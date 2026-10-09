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
  Future<HttpResponseData> sendRequest({
    required String method,
    required String url,
    Map<String, String>? headers,
    String? body,
  }) async {
    final client = HttpClient();

    try {
      final uri = Uri.parse(url);

      final request = await client.openUrl(
        method.toUpperCase(),
        uri,
      );

      // Add headers
      if (headers != null) {
        headers.forEach((key, value) {
          request.headers.set(key, value);
        });
      }

      // Add JSON body
      if (body != null && body.trim().isNotEmpty) {
        request.headers.contentType = ContentType.json;
        request.headers.contentLength = utf8.encode(body).length;
        request.write(body);
      }

      final response = await request.close();

      // Read the response using the response stream.
      // Do not manually depend on Content-Length.
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