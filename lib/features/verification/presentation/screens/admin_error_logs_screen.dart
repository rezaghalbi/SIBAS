import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../../core/theme/sibas_colors.dart';
import '../providers/error_log_provider.dart';

/// Daftar error klien terbaru; hanya admin yang bisa membuka layar ini.
class AdminErrorLogsScreen extends ConsumerWidget {
  const AdminErrorLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(errorLogsProvider);

    return Scaffold(
      backgroundColor: SibasColors.background,
      body: RefreshIndicator(
        color: SibasColors.leaf,
        onRefresh: () async {
          ref.invalidate(errorLogsProvider);
          await ref.read(errorLogsProvider.future);
        },
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1120),
                  child: HeroHeader(
                    title: 'Log Error',
                    subtitle: 'Error klien terbaru dari aplikasi',
                    trailing: IconButton(
                      tooltip: 'Kembali',
                      onPressed: () => Navigator.maybePop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.arrow_back_rounded,
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              sliver: state.when(
                data: (rows) {
                  if (rows.isEmpty) {
                    return SliverToBoxAdapter(
                      child: ContentWidth(
                        child: SurfaceCard(
                          padding: const EdgeInsets.all(28),
                          child: Text(
                            'Belum ada error klien yang tercatat.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: SibasColors.muted),
                          ),
                        ),
                      ),
                    );
                  }
                  return SliverList.builder(
                    itemCount: rows.length,
                    itemBuilder: (_, i) => ContentWidth(
                      child: _ErrorLogCard(row: rows[i]),
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
                error: (_, __) => SliverToBoxAdapter(
                  child: ContentWidth(
                    child: SurfaceCard(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text(
                            'Gagal memuat log error.',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: SibasColors.status.badText,
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () => ref.invalidate(errorLogsProvider),
                            child: const Text('Coba lagi'),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorLogCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _ErrorLogCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final dibuat = DateTime.tryParse('${row['dibuat_pada'] ?? ''}')?.toLocal();
    final tanggal = dibuat == null
        ? '-'
        : DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(dibuat);
    final platform = '${row['platform'] ?? '-'} • v${row['versi_aplikasi'] ?? '-'}';
    final pesan = '${row['pesan'] ?? '-'}';
    final detail = '${row['detail'] ?? ''}'.trim();

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline_rounded,
                size: 18,
                color: SibasColors.status.badText,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  tanggal,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: SibasColors.muted,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              ),
              Text(
                platform,
                style: TextStyle(fontSize: 11, color: SibasColors.muted),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            pesan,
            style: TextStyle(
              fontSize: 13,
              height: 1.45,
              fontWeight: FontWeight.w600,
              color: SibasColors.text,
            ),
          ),
          if (detail.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              detail,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                height: 1.4,
                color: SibasColors.muted,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
