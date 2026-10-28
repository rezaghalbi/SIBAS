import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../deposit/presentation/providers/deposit_provider.dart';
import '../providers/trash_type_provider.dart';
import '../../../../core/theme/sibas_colors.dart';

/// Target sentuh minimum (§4).
const double _touch = 44;

/// Lebar konten: sama dengan `ContentWidth` agar hero sejajar (§4).
const double _maxContentWidth = 1120;

/// Angka tarif memakai lebar digit tetap (§3).
const List<FontFeature> _numbers = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// Judul seksi: 15.5 w700, tracking -0.2 (§3).
TextStyle get _sectionTitle => TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  color: SibasColors.text,
);

/// Daftar jenis sampah: tarif, satuan, status aktif, dan hapus.
///
/// Halaman ini hanya berisi daftar. Tambah/ubah dibuka sebagai halaman
/// penuh lewat `TrashTypeFormScreen` agar form punya ruang dan action bar
/// sendiri. Pintasan admin lain sudah ada di dashboard.
class TrashTypeManagementScreen extends ConsumerStatefulWidget {
  const TrashTypeManagementScreen({super.key});

  @override
  ConsumerState<TrashTypeManagementScreen> createState() =>
      _TrashTypeManagementScreenState();
}

class _TrashTypeManagementScreenState
    extends ConsumerState<TrashTypeManagementScreen> {
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allTrashTypesProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: SibasColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: SibasColors.leaf,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah jenis'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _hero()),
          ..._listSlivers(state),
          // Nav mengambang tidak boleh menutup aksi terakhir (§4).
          SliverToBoxAdapter(child: SizedBox(height: 96 + bottomInset)),
        ],
      ),
    );
  }

  /// Hero memakai gutter sendiri; dibatasi lebar agar sejajar kartu isi.
  Widget _hero() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: HeroHeader(
          title: 'Jenis Sampah',
          subtitle: 'Atur tarif dan status jenis sampah',
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
    );
  }

  List<Widget> _listSlivers(
    AsyncValue<List<Map<String, dynamic>>> state,
  ) {
    return state.when(
      data: (list) {
        if (list.isEmpty) {
          return [_stateSliver(_emptyCard())];
        }

        return [
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daftar jenis sampah',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _sectionTitle,
                      ),
                    ),
                    Text(
                      '${list.length} jenis',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: SibasColors.muted,
                        fontFeatures: _numbers,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SliverList.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => ContentWidth(
              child: _itemCard(list[i]),
            ),
          ),
        ];
      },
      loading: () => [_stateSliver(_loadingCard())],
      error: (_, __) => [
        _stateSliver(
          _errorCard(
            onRetry: () => ref.invalidate(allTrashTypesProvider),
          ),
        ),
      ],
    );
  }

  /// Keadaan kosong/gagal dibatasi 560 px agar tetap terbaca di desktop.
  Widget _stateSliver(Widget child) {
    return SliverToBoxAdapter(
      child: ContentWidth(
        child: Padding(
          padding: const EdgeInsets.only(top: 16),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: child,
            ),
          ),
        ),
      ),
    );
  }

  String _priceLabel(Map<String, dynamic> item) {
    final price = (item['price_per_kg'] as num?)?.toDouble() ?? 0.0;
    if (price <= 0) return 'Non-rupiah (kg saja)';
    final unit = ((item['unit'] as String?) ?? '').trim();
    return '${_currency.format(price)} / ${unit.isEmpty ? 'kg' : unit}';
  }

  Widget _thumbCard(String? imagePath) {
    final fallback = ColoredBox(
      color: SibasColors.mintWash,
      child: SizedBox(
        width: 40,
        height: 40,
        child: Icon(
          Icons.recycling_rounded,
          size: 20,
          color: SibasColors.leaf,
        ),
      ),
    );

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 40,
        height: 40,
        child: Consumer(
          builder: (context, ref, _) {
            final url = ref.watch(fotoJenisSampahUrlProvider(imagePath));
            if (url == null || url.isEmpty) return fallback;
            return Image.network(
              url,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => fallback,
            );
          },
        ),
      ),
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final id = item['id'] as String? ?? '';
    final name = (item['name'] as String?) ?? 'Tanpa nama';
    final description = ((item['description'] as String?) ?? '').trim();
    final isActive = (item['is_active'] as bool?) ?? true;
    final busy = _busyId == id;

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _thumbCard(item['image_path'] as String?),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: _sectionTitle,
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: SibasColors.muted,
                        ),
                      ),
                    ],
                    const SizedBox(height: 4),
                    Text(
                      _priceLabel(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: SibasColors.primary,
                        fontFeatures: _numbers,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _statusToggle(item, isActive, busy),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: busy ? null : () => _openForm(item),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Ubah'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: SibasColors.leaf,
                  minimumSize: const Size(0, _touch),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: BorderSide(color: SibasColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Hapus',
                onPressed: busy ? null : () => _delete(item),
                icon: const Icon(Icons.delete_outline_rounded, size: 20),
                style: IconButton.styleFrom(
                  minimumSize: const Size(_touch, _touch),
                  backgroundColor: SibasColors.status.rejectedBackground,
                  foregroundColor: SibasColors.status.badText,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Status aktif/nonaktif sekaligus tombol ubah status (target 44 px).
  Widget _statusToggle(
    Map<String, dynamic> item,
    bool isActive,
    bool busy,
  ) {
    final ink = isActive ? SibasColors.status.approvedText : SibasColors.muted;
    final surface = isActive
        ? SibasColors.status.approvedBackground
        : SibasColors.status.neutralText.withValues(alpha: 0.10);

    return Semantics(
      button: true,
      toggled: isActive,
      label: isActive ? 'Nonaktifkan' : 'Aktifkan',
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: ShapeDecoration(
            color: surface,
            shape: StadiumBorder(
              side: BorderSide(color: ink.withValues(alpha: 0.18)),
            ),
          ),
          child: InkWell(
            onTap: busy ? null : () => _toggle(item, !isActive),
            customBorder: const StadiumBorder(),
            child: Container(
              height: _touch,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (busy)
                    SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ink,
                      ),
                    )
                  else
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: ink,
                        shape: BoxShape.circle,
                      ),
                    ),
                  const SizedBox(width: 6),
                  Text(
                    isActive ? 'Aktif' : 'Nonaktif',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: ink,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Form dibuka sebagai halaman penuh; `true` berarti data tersimpan.
  Future<void> _openForm([Map<String, dynamic>? initial]) async {
    final id = (initial?['id'] as String?) ?? '';
    // Tanpa id yang sah, buka mode tambah agar rute tidak menunjuk id kosong.
    final isEdit = initial != null && id.isNotEmpty;
    final saved = await context.push<bool>(
      isEdit ? '/admin/trash-types/$id/edit' : '/admin/trash-types/new',
      extra: isEdit ? initial : null,
    );
    if (saved != true || !mounted) return;

    ref.invalidate(allTrashTypesProvider);
    ref.invalidate(wasteCategoriesProvider);
    _toast(
      isEdit ? 'Jenis sampah diperbarui.' : 'Jenis sampah ditambahkan.',
    );
  }

  Future<void> _toggle(Map<String, dynamic> item, bool isActive) async {
    final id = item['id'] as String? ?? '';
    if (id.isEmpty) return;

    setState(() => _busyId = id);
    final ok = await ref
        .read(trashTypeControllerProvider.notifier)
        .toggleActive(id, isActive);
    if (!mounted) return;
    setState(() => _busyId = null);

    if (ok) {
      ref.invalidate(wasteCategoriesProvider);
    } else {
      _toast(
        _friendlyError(
          ref.read(trashTypeControllerProvider).error,
          'Gagal mengubah status jenis sampah.',
        ),
        isError: true,
      );
    }
  }

  Future<void> _delete(Map<String, dynamic> item) async {
    final id = item['id'] as String? ?? '';
    if (id.isEmpty) return;

    final confirmed = await _confirm(
      title: 'Hapus jenis sampah?',
      message: '"${(item['name'] as String?) ?? ''}" akan dihapus permanen '
          'bila belum dipakai transaksi. Jenis yang sudah dipakai akan '
          'dinonaktifkan dan riwayat setoran tetap tersimpan.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = id);
    final mode = await ref
        .read(trashTypeControllerProvider.notifier)
        .hapusAman(id);
    if (!mounted) return;
    setState(() => _busyId = null);

    if (mode == null) {
      _toast(
        _friendlyError(
          ref.read(trashTypeControllerProvider).error,
          'Gagal menghapus jenis sampah.',
        ),
        isError: true,
      );
      return;
    }

    ref.invalidate(allTrashTypesProvider);
    ref.invalidate(wasteCategoriesProvider);
    _toast(
      mode == 'nonaktif'
          ? 'Jenis sampah dinonaktifkan karena sudah dipakai transaksi.'
          : 'Jenis sampah dihapus.',
    );
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            height: 1.45,
            color: SibasColors.muted,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, _touch),
              foregroundColor: SibasColors.muted,
            ),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: SibasColors.status.badText,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, _touch),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  void _toast(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? SibasColors.status.badText : SibasColors.primary,
      ),
    );
  }

  Widget _emptyCard() {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: SibasColors.mintWash,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.recycling_rounded,
              size: 26,
              color: SibasColors.leaf,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Belum ada jenis sampah',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SibasColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan jenis sampah lewat tombol di bawah.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: SibasColors.muted,
            ),
          ),
        ],
      ),
    );
  }

  Widget _loadingCard() {
    return SurfaceCard(
      padding: EdgeInsets.all(28),
      child: Column(
        children: [
          SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          SizedBox(height: 12),
          Text(
            'Memuat jenis sampah...',
            style: TextStyle(fontSize: 12.5, color: SibasColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _errorCard({required VoidCallback onRetry}) {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: SibasColors.status.rejectedBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.cloud_off_rounded,
              size: 26,
              color: SibasColors.status.badText,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Gagal memuat jenis sampah',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SibasColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Periksa koneksi Anda, lalu muat ulang daftar.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: SibasColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, _touch),
              foregroundColor: SibasColors.leaf,
              side: BorderSide(color: SibasColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Pesan exception Indonesia ditampilkan apa adanya, selain itu generik.
String _friendlyError(Object? error, String fallback) {
  final raw = (error?.toString() ?? '').replaceFirst('Exception: ', '').trim();
  if (raw.isEmpty) return fallback;
  const triggers = [
    'tidak',
    'gagal',
    'wajib',
    'sudah',
    'belum',
    'harus',
    'sedang',
    'minimal',
    'melebihi',
    'jenis sampah',
    'tarif',
    'satuan',
  ];
  final lower = raw.toLowerCase();
  return triggers.any((t) => lower.contains(t)) ? raw : fallback;
}
