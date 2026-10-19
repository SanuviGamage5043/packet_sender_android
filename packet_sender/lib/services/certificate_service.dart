import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

class CertificateService {
  static const _pemHeader = '-----BEGIN CERTIFICATE-----';
  static const _pemFooter = '-----END CERTIFICATE-----';

  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/custom_ca.pem');
  }

  Future<File> _nameFile() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/custom_ca.name');
  }

  Future<bool> hasCertificate() async => (await _file()).exists();

  // Original filename of the imported certificate
  Future<String?> getCertificateName() async {
    if (!await (await _file()).exists()) return null;

    final nf = await _nameFile();
    if (await nf.exists()) {
      final name = (await nf.readAsString()).trim();
      if (name.isNotEmpty) return name;
    }
    return 'custom_ca.pem';
  }

  Future<void> importFromPath(String path) async {
    final bytes = await File(path).readAsBytes();
    final name = path.split(RegExp(r'[\\/]')).last;
    await importFromBytes(bytes, name: name);
  }

  Future<void> importFromBytes(Uint8List bytes, {String? name}) async {
    final pem = _toPem(bytes);

    // Validate that the bytes can be loaded as trusted certificates
    SecurityContext(withTrustedRoots: false).setTrustedCertificatesBytes(pem);

    await (await _file()).writeAsBytes(pem, flush: true);

    final nf = await _nameFile();
    if (name != null && name.isNotEmpty) {
      await nf.writeAsString(name, flush: true);
    } else if (await nf.exists()) {
      await nf.delete();
    }
  }

  Future<void> remove() async {
    final f = await _file();
    if (await f.exists()) await f.delete();

    final nf = await _nameFile();
    if (await nf.exists()) await nf.delete();
  }

  Future<SecurityContext> buildContext() async {
    final ctx = SecurityContext(withTrustedRoots: true);
    final f = await _file();

    if (await f.exists()) {
      ctx.setTrustedCertificatesBytes(await f.readAsBytes());
    }

    return ctx;
  }

  // PEM passes through; DER (common for .crt/.cer) is wrapped as PEM.
  Uint8List _toPem(Uint8List bytes) {
    final text = String.fromCharCodes(bytes);
    if (text.contains(_pemHeader)) return bytes;

    final b64 = base64.encode(bytes);
    final lines = RegExp('.{1,64}').allMatches(b64).map((m) => m.group(0)!);
    final pem = '$_pemHeader\n${lines.join('\n')}\n$_pemFooter\n';
    return Uint8List.fromList(utf8.encode(pem));
  }
}