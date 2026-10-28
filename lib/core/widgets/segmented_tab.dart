import 'package:flutter/material.dart';

import '../theme/sibas_colors.dart';

/// Sakelar dua/lebih tab dengan bahasa visual yang sama di seluruh aplikasi.
///
/// Dipakai Riwayat admin dan mahasiswa; bukan pengganti navigasi utama.
class SegmentedTab<T> extends StatelessWidget {
  final T value;
  final Map<T, String> items;
  final ValueChanged<T> onChanged;

  const SegmentedTab({
    super.key,
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      expandedInsets: EdgeInsets.zero,
      segments: [
        for (final entry in items.entries)
          ButtonSegment<T>(
            value: entry.key,
            label: Text(entry.value),
          ),
      ],
      selected: {value},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onChanged(selection.first),
      style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 44)),
        textStyle: const WidgetStatePropertyAll<TextStyle>(
          TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.1,
          ),
        ),
        backgroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? SibasColors.leaf
              : SibasColors.surfaceAlt;
        }),
        foregroundColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? Colors.white
              : SibasColors.text;
        }),
        side: WidgetStatePropertyAll(
          BorderSide(color: SibasColors.border),
        ),
      ),
    );
  }
}
