import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/sibas_colors.dart';
import '../theme/theme_mode_controller.dart';
import 'surface_card.dart';

/// Kartu pemilih tema: terang, gelap, atau ikut pengaturan perangkat.
///
/// Dipakai Profil (mahasiswa) dan Pengaturan Aplikasi (admin) agar pilihan
/// tampilan tersedia di kedua peran.
class ThemeModeCard extends ConsumerWidget {
  const ThemeModeCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tampilan',
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
              color: SibasColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Pilih tema terang, gelap, atau ikuti pengaturan perangkat.',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.45,
              color: SibasColors.muted,
            ),
          ),
          const SizedBox(height: 12),
          SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment<ThemeMode>(
                value: ThemeMode.light,
                icon: Icon(Icons.light_mode_outlined, size: 18),
                label: Text('Terang'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.dark,
                icon: Icon(Icons.dark_mode_outlined, size: 18),
                label: Text('Gelap'),
              ),
              ButtonSegment<ThemeMode>(
                value: ThemeMode.system,
                icon: Icon(Icons.brightness_auto_outlined, size: 18),
                label: Text('Sistem'),
              ),
            ],
            selected: {mode},
            showSelectedIcon: false,
            style: const ButtonStyle(
              minimumSize: WidgetStatePropertyAll(Size(0, 44)),
              textStyle: WidgetStatePropertyAll(
                TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
            ),
            onSelectionChanged: (values) =>
                ref.read(themeModeProvider.notifier).ubah(values.first),
          ),
        ],
      ),
    );
  }
}
