import 'package:web/web.dart' as web;

/// Menyamakan latar `body` HTML dengan tema aplikasi.
///
/// Tanpa ini, `body` mengikuti `prefers-color-scheme` sistem sehingga warna
/// gelap bisa tetap terlihat di belakang kanvas saat aplikasi memakai tema
/// terang.
void aturLatarWeb(int argb) {
  final hex = (argb & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
  web.document.body?.style.backgroundColor = '#$hex';
}
