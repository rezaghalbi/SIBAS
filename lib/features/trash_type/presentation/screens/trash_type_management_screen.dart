import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../deposit/presentation/providers/deposit_provider.dart';
import '../providers/trash_type_provider.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.primaryMain,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Tambah Jenis'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
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
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            sliver: SliverToBoxAdapter(
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
          state.when(
            data: (list) {
              if (list.isEmpty) {
                return SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverToBoxAdapter(
                    child: _emptyCard(),
                  ),
                );
              }
              return SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
                sliver: SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => _itemCard(list[i]),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
            error: (_, __) => SliverPadding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              sliver: SliverToBoxAdapter(
                child: _errorCard(
                  onRetry: () => ref.invalidate(allTrashTypesProvider),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }

  String _priceLabel(Map<String, dynamic> item) {
    final price = (item['price_per_kg'] as num?)?.toDouble() ?? 0.0;
    if (price <= 0) return 'Non-rupiah (kg saja)';
    final unit = ((item['unit'] as String?) ?? '').trim();
    return '${_currency.format(price)} / ${unit.isEmpty ? 'kg' : unit}';
  }

  /// Pintasan ke layar admin lain. Dua panel kaca = batas blur layar ini.
  Widget _menuAdmin({
    required IconData icon,
    required String title,
    required String subtitle,
    required String route,
  }) {
    return GlassPanel(
      radius: 16,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => context.push(route),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.mintSoftBackground,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: AppColors.primaryMain),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 20,
                  color: AppColors.textMuted,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _thumbCard(String? imagePath) {
    final fallback = Container(
      width: 46,
      height: 46,
      color: AppColors.mintSoftBackground,
      child: const Icon(
        Icons.recycling_rounded,
        size: 22,
        color: AppColors.primaryMain,
      ),
    );

    return Consumer(
      builder: (context, ref, _) {
        final url = ref.watch(fotoJenisSampahUrlProvider(imagePath));
        if (url == null || url.isEmpty) return fallback;
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.network(
            url,
            width: 46,
            height: 46,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => fallback,
          ),
        );
      },
    );
  }

  Widget _itemCard(Map<String, dynamic> item) {
    final id = item['id'] as String? ?? '';
    final name = (item['name'] as String?) ?? 'Tanpa nama';
    final description = ((item['description'] as String?) ?? '').trim();
    final isActive = (item['is_active'] as bool?) ?? true;
    final busy = _busyId == id;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 8),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _thumbCard(item['image_path'] as String?),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _activeChip(isActive),
              Switch.adaptive(
                value: isActive,
                onChanged: busy ? null : (v) => _toggle(item, v),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.mintSoftBackground,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppColors.mintAccent),
                      ),
                      child: Text(
                        _priceLabel(item),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                ),
                if (busy)
                  const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  IconButton(
                    tooltip: 'Ubah',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _openForm(item),
                    icon: const Icon(
                      Icons.edit_outlined,
                      size: 20,
                      color: AppColors.primaryMain,
                    ),
                  ),
                  IconButton(
                    tooltip: 'Hapus',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => _delete(item),
                    icon: const Icon(
                      Icons.delete_outline_rounded,
                      size: 20,
                      color: AppColors.danger,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _activeChip(bool isActive) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isActive
            ? AppColors.statusApprovedBg
            : AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        isActive ? 'Aktif' : 'Nonaktif',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: isActive
              ? AppColors.statusApprovedText
              : AppColors.statusRejectedText,
        ),
      ),
    );
  }

  Future<void> _openForm([Map<String, dynamic>? initial]) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _TrashTypeFormDialog(initial: initial),
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
          borderRadius: BorderRadius.circular(18),
        ),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text(
              'Batal',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
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
        backgroundColor: isError ? AppColors.danger : AppColors.primaryDark,
      ),
    );
  }

  Widget _emptyCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: const Column(
        children: [
          Icon(Icons.recycling_rounded, size: 36, color: AppColors.textMuted),
          SizedBox(height: 10),
          Text(
            'Belum ada jenis sampah',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 4),
          Text(
            'Tambahkan jenis sampah lewat tombol di bawah.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  Widget _errorCard({required VoidCallback onRetry}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.statusRejectedBg),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.cloud_off_rounded,
            size: 34,
            color: AppColors.danger,
          ),
          const SizedBox(height: 10),
          const Text(
            'Gagal memuat jenis sampah. Periksa koneksi Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
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

/// Form tambah/ubah jenis sampah. Pop `true` bila berhasil disimpan.
class _TrashTypeFormDialog extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initial;

  const _TrashTypeFormDialog({this.initial});

  @override
  ConsumerState<_TrashTypeFormDialog> createState() =>
      _TrashTypeFormDialogState();
}

class _TrashTypeFormDialogState extends ConsumerState<_TrashTypeFormDialog> {
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
                leading: const Icon(
                  Icons.delete_outline_rounded,
                  color: AppColors.danger,
                ),
                title: const Text('Hapus Foto'),
                onTap: () => Navigator.pop(ctx, 'hapus'),
              ),
            ListTile(
              leading: const Icon(Icons.close_rounded),
              title: const Text('Batal'),
              onTap: () => Navigator.pop(ctx),
            ),
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
      color: AppColors.mintSoftBackground,
      child: Icon(Icons.image_outlined, size: 30, color: AppColors.textMuted),
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
        const Text(
          'Foto (opsional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(width: 84, height: 84, child: preview),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: _saving ? null : _openFotoSheet,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 8,
                    ),
                    visualDensity: VisualDensity.compact,
                  ),
                  icon: const Icon(
                    Icons.add_photo_alternate_outlined,
                    size: 18,
                  ),
                  label: const Text(
                    'Pilih Foto',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Text(
        _isEdit ? 'Ubah Jenis Sampah' : 'Tambah Jenis Sampah',
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Nama jenis sampah',
                  hintText: 'Contoh: Botol Plastik PET',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _unit,
                decoration: const InputDecoration(
                  labelText: 'Satuan',
                  hintText: 'kg',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _price,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
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
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _description,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Deskripsi (opsional)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 14),
              _fotoField(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.statusRejectedBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    _error!,
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.statusRejectedText,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text(
            'Batal',
            style: TextStyle(color: AppColors.textMuted),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryMain,
            foregroundColor: Colors.white,
          ),
          onPressed: _saving ? null : _submit,
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
      ],
    );
  }
}
