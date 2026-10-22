import 'package:flutter/services.dart';

/// Non-web: tidak ada unduhan file, jadi salin CSV ke papan klip.
/// `false` = disalin, bukan diunduh.
Future<bool> simpanCsv(String namaFile, String isi) async {
  await Clipboard.setData(ClipboardData(text: isi));
  return false;
}
