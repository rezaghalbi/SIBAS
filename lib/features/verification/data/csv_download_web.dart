import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: unduh langsung lewat anchor `download`. `true` = benar-benar unduh.
///
/// `false` = unduhan tidak bisa dimulai (mis. tanpa `document.body` atau
/// anchor gagal). Pemanggil lalu menyalin CSV ke papan klip.
Future<bool> simpanCsv(String namaFile, String isi) async {
  final badan = web.document.body;
  if (badan == null) return false;

  final blob = web.Blob(
    <JSAny>[isi.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final jangkar = web.HTMLAnchorElement()
    ..href = url
    ..download = namaFile
    ..style.display = 'none';

  var berhasil = false;
  try {
    badan.appendChild(jangkar);
    jangkar.click();
    berhasil = true;
  } catch (_) {
    berhasil = false;
  } finally {
    // Safari membatalkan unduhan bila anchor/blob dilepas terlalu cepat,
    // jadi bersihkan setelah jeda singkat.
    Timer(const Duration(seconds: 1), () {
      jangkar.remove();
      web.URL.revokeObjectURL(url);
    });
  }
  return berhasil;
}
