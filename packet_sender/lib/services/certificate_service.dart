
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CertificateService {
  Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/custom_ca.pem');
  }

  Future<bool> hasCertificate() async =>
      (await _file()).exists();

  // Get the imported certificate filename
  Future<String?> getCertificateName() async {
    final f = await _file();

    if (await f.exists()) {
      return 'custom_ca.pem';
    }

    return null;
  }

  Future<void> importFromPath(String path) async {
    final bytes = await File(path).readAsBytes();

    // Validate that the bytes can be loaded as trusted certificates
    SecurityContext(withTrustedRoots: false)
        .setTrustedCertificatesBytes(bytes);

    await (await _file()).writeAsBytes(bytes, flush: true);
  }

  Future<void> remove() async {
    final f = await _file();
    if (await f.exists()) {
      await f.delete();
    }
  }

  Future<SecurityContext> buildContext() async {
    final ctx = SecurityContext(withTrustedRoots: true);
    final f = await _file();

    if (await f.exists()) {
      ctx.setTrustedCertificatesBytes(await f.readAsBytes());
    }

    return ctx;
  }
}
