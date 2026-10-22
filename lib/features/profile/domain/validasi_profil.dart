/// Validasi form profil. `null` berarti nilai valid; selain itu pesan siap
/// tampil untuk pengguna. Aturan mengikuti RPC `ubah_profil_sendiri`.

/// Nama lengkap 2-80 karakter.
String? validasiNama(String? value) {
  final nama = (value ?? '').trim();
  if (nama.isEmpty) return 'Nama lengkap wajib diisi.';
  if (nama.length < 2) return 'Nama minimal 2 karakter.';
  if (nama.length > 80) return 'Nama maksimal 80 karakter.';
  return null;
}

/// NIM 3-20 karakter, hanya huruf dan angka.
String? validasiNim(String? value) {
  final nim = (value ?? '').trim();
  if (nim.isEmpty) return 'NIM wajib diisi.';
  if (!RegExp(r'^[A-Za-z0-9]+$').hasMatch(nim)) {
    return 'NIM hanya boleh huruf dan angka.';
  }
  if (nim.length < 3) return 'NIM minimal 3 karakter.';
  if (nim.length > 20) return 'NIM maksimal 20 karakter.';
  return null;
}

/// Nomor WhatsApp 8-20 digit, boleh diawali +62, spasi, dan strip.
String? validasiNomorWa(String? value) {
  final nomor = (value ?? '').trim();
  if (nomor.isEmpty) return 'Nomor WhatsApp wajib diisi.';
  if (!RegExp(r'^[0-9+][0-9 -]{7,19}$').hasMatch(nomor)) {
    return 'Nomor WhatsApp tidak valid. Contoh: 081234567890.';
  }
  return null;
}
