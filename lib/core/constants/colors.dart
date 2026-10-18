import 'package:flutter/material.dart';

/// Palet warna resmi SIBAS terkunci sesuai .antigravity/design_system.md
class AppColors {
  AppColors._();

  /// Primary Palette
  static const Color primaryDark = Color(0xFF095C3B);
  static const Color primaryMain = Color(0xFF0E7A4F);
  static const Color primary = primaryMain; // Alias standard
  static const Color primaryLight = Color(0xFF2FA56F);

  /// Mint & Accent
  static const Color mint = Color(0xFFDFF3E8);
  static const Color mintAccent = mint;
  static const Color accent = primaryLight;
  static const Color mintSoftBackground = Color(0xFFEEF8F2);

  /// App Backgrounds & Surface
  static const Color background = Color(0xFFF3F8F5);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color surface = cardSurface;

  /// Typography
  static const Color textPrimary = Color(0xFF12201A);
  static const Color textMuted = Color(0xFF5F6F67);
  static const Color textSecondary = textMuted;

  /// Lines & Borders
  static const Color borderLine = Color.fromRGBO(15, 60, 40, 0.10);
  static const Color border = borderLine;

  /// Translucent Hero Card Surface
  static const Color heroCardSurface = Color.fromRGBO(255, 255, 255, 0.14);
  static const Color heroCardBorder = Color.fromRGBO(255, 255, 255, 0.25);

  /// Status Badges & Chips
  /// Menunggu Validasi / Verifikasi
  static const Color statusPendingText = Color(0xFFB45309);
  static const Color statusPendingBg = Color(0xFFFEF3C7);
  static const Color statusPending = statusPendingText;

  /// Disetujui / Diterima
  static const Color statusApprovedText = Color(0xFF15803D);
  static const Color statusApprovedBg = Color(0xFFDCFCE7);
  static const Color statusApproved = statusApprovedText;

  /// Ditolak / Kedaluwarsa
  static const Color statusRejectedText = Color(0xFFB91C1C);
  static const Color statusRejectedBg = Color(0xFFFEE2E2);
  static const Color statusRejected = statusRejectedText;
  static const Color statusExpired = Color(0xFF6B7280);

  /// Danger / Error
  static const Color danger = Color(0xFFB91C1C);

  /// Hero Header Gradient
  static const LinearGradient heroGradient = LinearGradient(
    colors: [
      Color(0xFF095C3B),
      Color(0xFF0E7A4F),
      Color(0xFF2FA56F),
    ],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Soft Card Shadow
  static const BoxShadow cardShadow = BoxShadow(
    color: Color.fromRGBO(9, 92, 59, 0.12),
    blurRadius: 24,
    offset: Offset(0, 4),
  );
}
