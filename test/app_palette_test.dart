import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/core/constants/colors.dart';
import 'package:sibas/core/theme/app_palette.dart';

void main() {
  group('AppPalette light', () {
    test('token inti sama dengan konstanta AppColors lama', () {
      expect(AppPalette.light.background, AppColors.background);
      expect(AppPalette.light.surface, AppColors.cardSurface);
      expect(AppPalette.light.text, AppColors.textPrimary);
      expect(AppPalette.light.primary, AppColors.primaryDark);
    });
  });

  group('AppPalette dark', () {
    test('latar, permukaan, dan teks berbeda dari light', () {
      expect(AppPalette.dark.background, isNot(AppPalette.light.background));
      expect(AppPalette.dark.surface, isNot(AppPalette.light.surface));
      expect(AppPalette.dark.text, isNot(AppPalette.light.text));
    });

    test('teks terang di atas latar gelap', () {
      expect(AppPalette.dark.text.computeLuminance(), greaterThan(0.5));
      expect(AppPalette.dark.background.computeLuminance(), lessThan(0.1));
      expect(
        AppPalette.dark.text.computeLuminance(),
        greaterThan(AppPalette.dark.background.computeLuminance()),
      );
    });
  });

  group('lerp', () {
    test('t = 0 tetap light dan t = 1 menjadi dark', () {
      final awal = AppPalette.light.lerp(AppPalette.dark, 0);
      expect(awal.background, AppPalette.light.background);
      expect(awal.brightness, Brightness.light);

      final akhir = AppPalette.light.lerp(AppPalette.dark, 1);
      expect(akhir.background, AppPalette.dark.background);
      expect(akhir.brightness, Brightness.dark);
    });

    test('t = 0.5 berada di antara kedua latar', () {
      final tengah = AppPalette.light.lerp(AppPalette.dark, 0.5);
      final terang = AppPalette.light.background.computeLuminance();
      final gelap = AppPalette.dark.background.computeLuminance();

      expect(tengah.background.computeLuminance(), lessThan(terang));
      expect(tengah.background.computeLuminance(), greaterThan(gelap));
    });
  });

  group('AppStatusColors', () {
    test('of() memilih set sesuai brightness', () {
      expect(AppStatusColors.of(Brightness.dark), AppStatusColors.dark);
      expect(AppStatusColors.of(Brightness.light), AppStatusColors.light);
    });
  });
}
