import 'package:flutter/material.dart';

import '../services/http_service.dart';

class HttpScreen extends StatefulWidget {
  const HttpScreen({super.key});

  @override
  State<HttpScreen> createState() =>
      _HttpScreenState();
}

class _HttpScreenState extends State<HttpScreen> {
  final _urlController = TextEditingController();

  final _bodyController = TextEditingController();

  final HttpService _service = HttpService();

  String _method = 'GET';

  String _response = '';

  int? _statusCode;

  bool _loading = false;

  Future<void> _sendRequest() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      _showMessage('Enter a URL.');
      return;
    }

    setState(() {
      _loading = true;
      _response = '';
      _statusCode = null;
    });

    try {
      final result =
          await _service.sendRequest(
        method: _method,
        url: url,
        body: _bodyController.text.isEmpty
            ? null
            : _bodyController.text,
      );

      setState(() {
        _statusCode = result.statusCode;
        _response = result.body;
      });
    } catch (e) {
      setState(() {
        _response = 'Error: $e';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
      ),
    );
  }

  @override
  void dispose() {
    _urlController.dispose();
    _bodyController.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('HTTP / HTTPS'),
      ),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _method,
              decoration: const InputDecoration(
                labelText: 'Method',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'GET',
                  child: Text('GET'),
                ),
                DropdownMenuItem(
                  value: 'POST',
                  child: Text('POST'),
                ),
                DropdownMenuItem(
                  value: 'PUT',
                  child: Text('PUT'),
                ),
                DropdownMenuItem(
                  value: 'DELETE',
                  child: Text('DELETE'),
                ),
              ],
              onChanged: (value) {
                setState(() {
                  _method = value!;
                });
              },
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL',
                hintText:
                    'https://example.com/api',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _bodyController,
              maxLines: 6,
              decoration: const InputDecoration(
                labelText: 'Body',
                hintText: '{"message":"hello"}',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),

            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed:
                    _loading ? null : _sendRequest,
                icon: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.send),
                label: Text(
                  _loading
                      ? 'SENDING...'
                      : 'SEND REQUEST',
                ),
              ),
            ),

            const SizedBox(height: 24),

            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                _statusCode == null
                    ? 'Response'
                    : 'Status: $_statusCode',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                border: Border.all(
                  color: Colors.grey,
                ),
                borderRadius:
                    BorderRadius.circular(10),
              ),
              child: SelectableText(
                _response.isEmpty
                    ? 'No response.'
                    : _response,
              ),
            ),
          ],
        ),
      ),
    );
  }
}