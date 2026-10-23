import 'package:flutter/material.dart';

import '../network/api_guard.dart';
import '../theme/sibas_colors.dart';

/// Bar tipis di atas layar saat permintaan terakhir gagal karena jaringan.
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
            height: 28,
            width: double.infinity,
            color: SibasColors.status.pendingBackground,
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'Tidak ada koneksi — data mungkin tidak terbaru',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                color: SibasColors.status.pendingText,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        );
      },
    );
  }
}
