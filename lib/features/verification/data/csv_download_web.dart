import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Web: unduh langsung lewat anchor `download`. `true` = benar-benar unduh.
Future<bool> simpanCsv(String namaFile, String isi) async {
  final blob = web.Blob(
    <JSAny>[isi.toJS].toJS,
    web.BlobPropertyBag(type: 'text/csv;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final jangkar = web.HTMLAnchorElement()
    ..href = url
    ..download = namaFile
    ..style.display = 'none';

  web.document.body?.appendChild(jangkar);
  jangkar.click();
  jangkar.remove();
  web.URL.revokeObjectURL(url);
  return true;
}
