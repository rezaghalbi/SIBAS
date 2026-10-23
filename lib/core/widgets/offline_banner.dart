import 'package:flutter/material.dart';

import '../network/api_guard.dart';
import '../theme/sibas_colors.dart';

/// Bar di atas layar saat permintaan terakhir gagal karena jaringan.
///
/// SIBAS wajib online: tidak ada data tersimpan yang ditampilkan, jadi pesannya
/// menjelaskan bahwa koneksi harus disambungkan lebih dulu.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: offlineNotifier,
      builder: (context, offline, _) {
        if (!offline) return const SizedBox.shrink();

        return SafeArea(
          bottom: false,
          child: Container(
            width: double.infinity,
            color: SibasColors.status.pendingBackground,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: Row(
              children: [
                Icon(
                  Icons.wifi_off_rounded,
                  size: 16,
                  color: SibasColors.status.pendingText,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Maaf, Anda sedang offline. SIBAS memerlukan koneksi '
                    'internet.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.3,
                      color: SibasColors.status.pendingText,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
