import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../deposit/presentation/providers/deposit_provider.dart';
import '../providers/trash_type_provider.dart';
import '../../core/theme/sibas_colors.dart';

/// Target sentuh minimum (§4).
const double _touch = 44;

/// Lebar konten: sama dengan `ContentWidth` agar hero sejajar (§4).
const double _maxContentWidth = 1120;

/// Angka tarif memakai lebar digit tetap (§3).
const List<FontFeature> _numbers = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// Judul seksi: 15.5 w700, tracking -0.2 (§3).
TextStyle _sectionTitle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  color: SibasColors.text,
);

/// Field 16 px agar Safari iOS tidak memperbesar halaman (§9).
TextStyle _fieldText = TextStyle(
  fontSize: 16,
  color: SibasColors.text,
);

/// Tombol batal di sheet form: garis tipis, tinggi 48 px.
final ButtonStyle _batalStyle = OutlinedButton.styleFrom(
  minimumSize: const Size(0, 48),
  foregroundColor: SibasColors.muted,
  side: BorderSide(color: SibasColors.border),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
);

/// Tombol simpan: hijau, tinggi 48 px.
final ButtonStyle _simpanStyle = FilledButton.styleFrom(
  backgroundColor: SibasColors.leaf,
  foregroundColor: Colors.white,
  elevation: 0,
  minimumSize: const Size(0, 48),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(12),
  ),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
);

/// Master data jenis sampah: tarif, satuan, status aktif, dan hapus.
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
        label: const Text('Tambah Jenis'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _hero()),
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
                child: Column(
                  children: [
                    _menuAdmin(
                      icon: Icons.people_alt_rounded,
                      title: 'Data Mahasiswa',
                      subtitle: 'Akun, saldo, dan berat terkumpul',
                      route: '/admin/students',
                    ),
                    const SizedBox(height: 12),
                    _menuAdmin(
                      icon: Icons.settings_rounded,
                      title: 'Pengaturan Aplikasi',
                      subtitle: 'Masa berlaku QR dan kontak admin',
                      route: '/admin/settings',
                    ),
                  ],
                ),
              ),
            ),
          ),
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
          subtitle: 'Atur tarif dan status master data',
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
                    const Expanded(
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

  /// Pintasan ke layar admin lain. Kartu konten, bukan lapisan kaca.
  Widget _menuAdmin({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: SibasColors.mintWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: SibasColors.leaf),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: SibasColors.text,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: SibasColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: SibasColors.muted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbCard(String? imagePath) {
    const fallback = ColoredBox(
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

  Future<void> _openForm([Map<String, dynamic>? initial]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: SibasColors.text.withValues(alpha: 0.36),
      builder: (_) => _TrashTypeFormSheet(initial: initial),
    );
    if (saved != true || !mounted) return;

    ref.invalidate(allTrashTypesProvider);
    ref.invalidate(wasteCategoriesProvider);
    _toast(
      initial == null
          ? 'Jenis sampah ditambahkan.'
          : 'Jenis sampah diperbarui.',
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

/// MIME berdasarkan ekstensi; default JPEG.
String _mimeFromName(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  return 'image/jpeg';
}

/// Form tambah/ubah jenis sampah dalam sheet. Pop `true` bila tersimpan.
class _TrashTypeFormSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initial;

  const _TrashTypeFormSheet({this.initial});

  @override
  ConsumerState<_TrashTypeFormSheet> createState() =>
      _TrashTypeFormSheetState();
}

class _TrashTypeFormSheetState extends ConsumerState<_TrashTypeFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _price;
  late final TextEditingController _description;

  bool _saving = false;
  String? _error;

  Uint8List? _fotoBytes;
  String? _fotoMime;
  bool _hapusFoto = false;

  bool get _isEdit => widget.initial != null;

  String? get _initialFoto {
    final raw = (widget.initial?['image_path'] as String?)?.trim() ?? '';
    return raw.isEmpty ? null : raw;
  }

  bool get _hasFoto =>
      _fotoBytes != null || (!_hapusFoto && _initialFoto != null);

  @override
  void initState() {
    super.initState();
    final item = widget.initial;
    final price = (item?['price_per_kg'] as num?)?.toDouble() ?? 0.0;
    _name = TextEditingController(text: (item?['name'] as String?) ?? '');
    _unit = TextEditingController(text: (item?['unit'] as String?) ?? 'kg');
    _price = TextEditingController(
      text: price == price.roundToDouble()
          ? price.toStringAsFixed(0)
          : price.toString(),
    );
    _description = TextEditingController(
      text: (item?['description'] as String?) ?? '',
    );
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _price.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final name = _name.text.trim();
    final unitText = _unit.text.trim();
    final unit = unitText.isEmpty ? 'kg' : unitText;
    final price = double.tryParse(_price.text.trim().replaceAll(',', '.')) ?? 0;
    final description = _description.text.trim();
    final controller = ref.read(trashTypeControllerProvider.notifier);

    final ok = _isEdit
        ? await controller.update(
            widget.initial!['id'] as String,
            name: name,
            unit: unit,
            pricePerKg: price,
            description: description.isEmpty ? null : description,
            foto: _fotoBytes,
            fotoMime: _fotoMime,
            hapusFoto: _hapusFoto,
          )
        : await controller.create(
            name: name,
            unit: unit,
            pricePerKg: price,
            description: description.isEmpty ? null : description,
            foto: _fotoBytes,
            fotoMime: _fotoMime,
          );

    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
      return;
    }

    setState(() {
      _saving = false;
      _error = _friendlyError(
        ref.read(trashTypeControllerProvider).error,
        'Gagal menyimpan jenis sampah. Coba lagi.',
      );
    });
  }

  Future<void> _openFotoSheet() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(ctx, 'kamera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(ctx, 'galeri'),
            ),
            if (_hasFoto)
              ListTile(
                leading: Icon(
                  Icons.delete_outline_rounded,
                  color: SibasColors.status.badText,
                ),
                title: const Text('Hapus Foto'),
                onTap: () => Navigator.pop(ctx, 'hapus'),
              ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Batal'),
              onTap: () => Navigator.pop(ctx),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;

    if (action == 'kamera') {
      await _pickFoto(ImageSource.camera);
    } else if (action == 'galeri') {
      await _pickFoto(ImageSource.gallery);
    } else if (action == 'hapus') {
      setState(() {
        // Foto baru yang belum disimpan cukup dibuang; foto lama di server
        // baru dihapus bila tidak ada foto baru yang menunggu.
        final adaBaru = _fotoBytes != null;
        _fotoBytes = null;
        _fotoMime = null;
        _hapusFoto = !adaBaru && _initialFoto != null;
      });
    }
  }

  Future<void> _pickFoto(ImageSource source) async {
    try {
      final picked = await ImagePicker().pickImage(
        source: source,
        maxWidth: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;
      final bytes = await picked.readAsBytes();
      if (!mounted) return;
      setState(() {
        _fotoBytes = bytes;
        _fotoMime = _mimeFromName(picked.name);
        _hapusFoto = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'Gagal memilih foto. Coba lagi.');
    }
  }

  Widget _fotoField() {
    final url = _hapusFoto
        ? null
        : ref.watch(fotoJenisSampahUrlProvider(_initialFoto));
    const placeholder = ColoredBox(
      color: SibasColors.mintWash,
      child: Icon(Icons.image_outlined, size: 28, color: SibasColors.muted),
    );

    Widget preview;
    if (_fotoBytes != null) {
      preview = Image.memory(_fotoBytes!, fit: BoxFit.cover);
    } else if (url == null || url.isEmpty) {
      preview = placeholder;
    } else {
      preview = Image.network(
        url,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => placeholder,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Foto (opsional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SibasColors.text,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: SizedBox(width: 84, height: 84, child: preview),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _openFotoSheet,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, _touch),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    foregroundColor: SibasColors.leaf,
                    side: BorderSide(color: SibasColors.border),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: const Text('Pilih Foto'),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _handle() {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: SibasColors.border,
          borderRadius: BorderRadius.circular(999),
        ),
      ),
    );
  }

  Widget _namaField() {
    return TextFormField(
      controller: _name,
      textCapitalization: TextCapitalization.words,
      style: _fieldText,
      decoration: const InputDecoration(
        labelText: 'Nama jenis sampah',
        hintText: 'Contoh: Botol Plastik PET',
        border: OutlineInputBorder(),
      ),
      validator: (v) =>
          (v ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
    );
  }

  Widget _satuanField() {
    return TextFormField(
      controller: _unit,
      style: _fieldText,
      decoration: const InputDecoration(
        labelText: 'Satuan',
        hintText: 'kg',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _tarifField() {
    return TextFormField(
      controller: _price,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: _fieldText,
      decoration: const InputDecoration(
        labelText: 'Tarif per kg (Rp)',
        hintText: '0',
        helperText: 'Isi 0 untuk jenis non-rupiah.',
        border: OutlineInputBorder(),
      ),
      validator: (v) {
        final text = (v ?? '').trim().replaceAll(',', '.');
        if (text.isEmpty) return null;
        final parsed = double.tryParse(text);
        if (parsed == null) return 'Masukkan angka yang valid.';
        if (parsed < 0) return 'Tarif tidak boleh negatif.';
        return null;
      },
    );
  }

  Widget _deskripsiField() {
    return TextFormField(
      controller: _description,
      maxLines: 2,
      style: _fieldText,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Deskripsi (opsional)',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _sheetBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _handle(),
        const SizedBox(height: 12),
        Text(
          _isEdit ? 'Ubah Jenis Sampah' : 'Tambah Jenis Sampah',
          style: _sectionTitle,
        ),
        const SizedBox(height: 4),
        Text(
          _isEdit
              ? 'Perubahan tarif berlaku untuk setoran baru.'
              : 'Jenis baru langsung tampil di katalog setoran.',
          style: TextStyle(
            fontSize: 12.5,
            height: 1.4,
            color: SibasColors.muted,
          ),
        ),
        const SizedBox(height: 16),
        Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _namaField(),
              const SizedBox(height: 12),
              _satuanField(),
              const SizedBox(height: 12),
              _tarifField(),
              const SizedBox(height: 12),
              _deskripsiField(),
              const SizedBox(height: 16),
              _fotoField(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                SurfaceCard(
                  tone: SurfaceTone.subtle,
                  radius: 12,
                  color: SibasColors.status.rejectedBackground,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.4,
                      color: SibasColors.status.rejectedText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: _saving ? null : () => Navigator.pop(context),
                style: _batalStyle,
                child: const Text('Batal'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: _saving ? null : _submit,
                style: _simpanStyle,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Simpan'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final insets = MediaQuery.viewInsetsOf(context);
    final height = MediaQuery.sizeOf(context).height - insets.bottom;
    final maxHeight = height * 0.9;

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: GlassPanel(
                tone: GlassTone.dense,
                radius: 24,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: _sheetBody(),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
