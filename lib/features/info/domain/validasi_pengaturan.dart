/// Validasi murni untuk form Pengaturan Aplikasi (mudah diuji unit).
library;

/// Error TTL QR atau null bila valid. Batas server 5–1440 menit.
String? validasiTtlQr(String teks) {
  final nilai = int.tryParse(teks.trim());
  if (nilai == null) return 'Masa berlaku QR harus berupa angka menit.';
  if (nilai < 5 || nilai > 1440) {
    return 'Masa berlaku QR harus antara 5 dan 1440 menit.';
  }
  return null;
}

/// Email kontak boleh kosong; bila diisi harus berbentuk email sederhana.
String? validasiEmailKontak(String teks) {
  final nilai = teks.trim();
  if (nilai.isEmpty) return null;
  final cocok = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(nilai);
  return cocok ? null : 'Format email kontak tidak valid.';
}

/// Lokasi dan jam layanan boleh kosong; batas 160 karakter.
String? validasiTeksKontak(String teks, {int maks = 160}) {
  return teks.trim().length > maks ? 'Maksimal $maks karakter.' : null;
}
