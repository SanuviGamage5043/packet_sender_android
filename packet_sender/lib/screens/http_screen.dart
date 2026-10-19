import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart' as file_picker;

import '../services/certificate_service.dart';
import '../services/http_service.dart';

class HttpScreen extends StatefulWidget {
  const HttpScreen({super.key});

  @override
  State<HttpScreen> createState() => _HttpScreenState();
}

class _HttpScreenState extends State<HttpScreen> {
  final CertificateService _certificateService = CertificateService();
  final HttpService _httpService = HttpService();

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _headersController = TextEditingController(
    text: '{}',
  );
  final TextEditingController _bodyController = TextEditingController();

  String _method = 'GET';
  String? _certificateName;
  bool _isLoading = false;
  bool _isImportingCertificate = false;

  int? _statusCode;
  String _responseBody = '';
  String? _errorMessage;

  final List<String> _methods = ['GET', 'POST', 'PUT', 'DELETE'];

  static const List<String> _certExtensions = ['pem', 'crt', 'cer'];

  bool get _bodyAllowed => _method != 'GET';

  @override
  void initState() {
    super.initState();
    _loadCertificate();
  }

  Future<void> _loadCertificate() async {
    try {
      final name = await _certificateService.getCertificateName();
      if (!mounted) return;
      setState(() {
        _certificateName = name;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _certificateName = null;
      });
    }
  }

  Future<void> _importCertificate() async {
    setState(() {
      _isImportingCertificate = true;
      _errorMessage = null;
    });

    try {
      // FileType.any: Android often can't map pem/crt/cer to a MIME type,
      // which greys the files out. The extension is validated manually.
      final file = await file_picker.FilePicker.pickFile(
        type: file_picker.FileType.any,
      );

      if (file == null) return;

      final ext = file.name.contains('.')
          ? file.name.split('.').last.toLowerCase()
          : '';
      if (!_certExtensions.contains(ext)) {
        throw Exception('Select a .pem, .crt or .cer file.');
      }

      final path = file.path;
      if (path == null) {
        throw Exception('Could not read the selected certificate file.');
      }

      await _certificateService.importFromPath(path);
      await _loadCertificate();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Certificate imported successfully.')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Certificate import failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isImportingCertificate = false;
        });
      }
    }
  }

  Future<void> _removeCertificate() async {
    try {
      await _certificateService.remove();
      await _loadCertificate();

      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Certificate removed.')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Could not remove certificate: $e';
      });
    }
  }

  Future<void> _sendRequest() async {
    final url = _urlController.text.trim();

    if (url.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter a URL.';
      });
      return;
    }

    final uri = Uri.tryParse(url);

    if (uri == null ||
        !uri.hasScheme ||
        (uri.scheme != 'http' && uri.scheme != 'https') ||
        uri.host.isEmpty) {
      setState(() {
        _errorMessage = 'Enter a valid HTTP or HTTPS URL.';
      });
      return;
    }

    final Map<String, String> headers = {};

    try {
      final decoded = jsonDecode(_headersController.text.trim());

      if (decoded is! Map) {
        throw const FormatException('Headers must be a JSON object.');
      }

      for (final entry in decoded.entries) {
        if (entry.value is! String) {
          throw const FormatException('Header values must be strings.');
        }
        headers[entry.key.toString()] = entry.value as String;
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Invalid headers: $e';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _statusCode = null;
      _responseBody = '';
      _errorMessage = null;
    });

    try {
      final response = await _httpService.sendRequest(
        method: _method,
        url: url,
        headers: headers,
        body: (!_bodyAllowed || _bodyController.text.isEmpty)
            ? null
            : _bodyController.text,
      );

      if (!mounted) return;
      setState(() {
        _statusCode = response.statusCode;
        _responseBody = response.body;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Request failed: $e';
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _urlController.dispose();
    _headersController.dispose();
    _bodyController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('HTTP / HTTPS Client')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DropdownButtonFormField<String>(
              value: _method,
              decoration: const InputDecoration(
                labelText: 'HTTP Method',
                border: OutlineInputBorder(),
              ),
              items: _methods
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _method = value;
                  });
                }
              },
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _urlController,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Request URL',
                hintText: 'https://example.com/api',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.link),
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _headersController,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Headers (JSON)',
                hintText: '{"Content-Type": "application/json"}',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _bodyController,
              enabled: _bodyAllowed,
              maxLines: 5,
              decoration: InputDecoration(
                labelText: 'Request Body',
                hintText: _bodyAllowed
                    ? '{"key": "value"}'
                    : 'GET requests have no body',
                border: const OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 20),

            FilledButton.icon(
              onPressed: _isLoading ? null : _sendRequest,
              icon: _isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_isLoading ? 'Sending...' : 'Send Request'),
            ),

            const SizedBox(height: 24),
            const Divider(),

            Text(
              'Custom CA Certificate',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),

            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _certificateName == null
                    ? Icons.warning_amber
                    : Icons.verified_user,
              ),
              title: Text(_certificateName ?? 'No certificate imported'),
              subtitle: const Text('PEM, CRT or CER certificate'),
              trailing: _certificateName == null
                  ? null
                  : IconButton(
                      tooltip: 'Remove certificate',
                      onPressed: _removeCertificate,
                      icon: const Icon(Icons.delete_outline),
                    ),
            ),

            OutlinedButton.icon(
              onPressed: _isImportingCertificate ? null : _importCertificate,
              icon: _isImportingCertificate
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload_file),
              label: Text(
                _isImportingCertificate
                    ? 'Importing...'
                    : 'Import CA Certificate',
              ),
            ),

            const SizedBox(height: 24),
            const Divider(),

            Text('Response', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _errorMessage!,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),

            if (_statusCode != null) ...[
              Text(
                'Status Code: $_statusCode',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SelectableText(
                  _responseBody.isEmpty
                      ? '(Empty response body)'
                      : _responseBody,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
