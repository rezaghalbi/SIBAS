import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../core/theme/sibas_colors.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/surface_card.dart';
import '../providers/trash_type_provider.dart';

/// Target sentuh minimum (§4).
const double _touch = 44;

/// Lebar kolom form: satu kolom nyaman dibaca, bukan selebar halaman.
const double _formWidth = 640;

/// Angka tarif memakai lebar digit tetap (§3).
const List<FontFeature> _numbers = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// Field 16 px agar Safari iOS tidak memperbesar halaman (§9).
TextStyle get _fieldText => TextStyle(
  fontSize: 16,
  color: SibasColors.text,
);

/// Label mikro: 10 px w800, tracking lebar, huruf besar (§3).
TextStyle get _microLabel => TextStyle(
  fontSize: 10,
  fontWeight: FontWeight.w800,
  letterSpacing: 1.1,
  color: SibasColors.muted,
);

/// Tombol batal: garis tipis, tinggi 44 px.
ButtonStyle get _batalStyle => OutlinedButton.styleFrom(
  minimumSize: const Size(0, _touch),
  foregroundColor: SibasColors.muted,
  side: BorderSide(color: SibasColors.border),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  ),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
);

/// Tombol simpan: hijau, tinggi 52 px (aksi utama halaman).
ButtonStyle get _simpanStyle => FilledButton.styleFrom(
  backgroundColor: SibasColors.leaf,
  foregroundColor: Colors.white,
  elevation: 0,
  minimumSize: const Size(0, 52),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  ),
  textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
);

/// Tombol kecil di area foto: kamera/galeri.
ButtonStyle get _fotoButtonStyle => OutlinedButton.styleFrom(
  minimumSize: const Size(0, _touch),
  padding: const EdgeInsets.symmetric(horizontal: 12),
  foregroundColor: SibasColors.leaf,
  side: BorderSide(color: SibasColors.border),
  shape: RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(14),
  ),
  textStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
);

/// Form tambah/ubah jenis sampah sebagai halaman penuh.
///
/// Halaman ini hanya memakai `SurfaceCard` (tanpa blur) sesuai §2/§7.1:
/// kaca hanya untuk lapisan mengambang. Pop `true` bila data tersimpan.
class TrashTypeFormScreen extends ConsumerStatefulWidget {
  /// Data awal dari `extra` rute; null saat menambah jenis baru.
  final Map<String, dynamic>? initial;

  /// Mode ubah. Bila true dan [initial] null, layar menampilkan
  /// "Data tidak ditemukan" alih-alih form kosong.
  final bool isEdit;

  const TrashTypeFormScreen({
    super.key,
    this.initial,
    this.isEdit = false,
  });

  @override
  ConsumerState<TrashTypeFormScreen> createState() =>
      _TrashTypeFormScreenState();
}

class _TrashTypeFormScreenState extends ConsumerState<TrashTypeFormScreen> {
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

  bool get _isEdit => widget.isEdit || widget.initial != null;

  /// Rute ubah butuh data awal berisi id; tanpa itu tampilkan state kosong
  /// alih-alih form yang akan gagal saat menyimpan.
  bool get _missing {
    if (!_isEdit) return false;
    return ((widget.initial?['id'] as String?) ?? '').isEmpty;
  }

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
    if (_missing) return;
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

  /// Foto baru yang belum disimpan cukup dibuang; foto lama di server baru
  /// dihapus bila tidak ada foto baru yang menunggu.
  void _buangFoto() {
    setState(() {
      final adaBaru = _fotoBytes != null;
      _fotoBytes = null;
      _fotoMime = null;
      _hapusFoto = !adaBaru && _initialFoto != null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SibasColors.background,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _header(),
            Expanded(child: _missing ? _notFound() : _formBody()),
          ],
        ),
      ),
      bottomNavigationBar: _missing ? null : _actionBar(),
    );
  }

  /// Header ringkas yang menempel: tombol kembali + judul + keterangan.
  Widget _header() {
    return Container(
      decoration: BoxDecoration(
        color: SibasColors.background,
        border: Border(bottom: BorderSide(color: SibasColors.border)),
      ),
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: ContentWidth(
        maxWidth: _formWidth,
        child: Row(
          children: [
            IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back_rounded, size: 20),
              style: IconButton.styleFrom(
                minimumSize: const Size(_touch, _touch),
                foregroundColor: SibasColors.text,
                backgroundColor: SibasColors.mintWash,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _isEdit ? 'Ubah Jenis Sampah' : 'Tambah Jenis Sampah',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: SibasColors.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _isEdit
                        ? 'Perubahan tarif berlaku untuk setoran baru.'
                        : 'Jenis baru langsung tampil di katalog setoran.',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.3,
                      color: SibasColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _formBody() {
    return Form(
      key: _formKey,
      child: SingleChildScrollView(
        padding: const EdgeInsets.only(top: 16, bottom: 24),
        child: ContentWidth(
          maxWidth: _formWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _fotoCard(),
              const SizedBox(height: 14),
              _detailCard(),
              if (_error != null) ...[
                const SizedBox(height: 14),
                _errorCard(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _fotoCard() {
    return SurfaceCard(
      padding: const EdgeInsets.all(16),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Di ponsel sempit tombol foto turun ke bawah agar tidak berdesakan;
          // di layar lebar tombol mengisi kolom di samping foto.
          final sempit = constraints.maxWidth < 360;
          final tile = sempit ? 96.0 : 128.0;
          final info = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Foto jenis sampah',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: SibasColors.text,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _hasFoto
                    ? 'Foto tampil di katalog setoran.'
                    : 'Opsional, membantu petugas mengenali jenis sampah.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.4,
                  color: SibasColors.muted,
                ),
              ),
            ],
          );

          if (sempit) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fotoTile(tile),
                    const SizedBox(width: 14),
                    Expanded(child: info),
                  ],
                ),
                const SizedBox(height: 12),
                _fotoActions(),
              ],
            );
          }

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _fotoTile(tile),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    info,
                    const SizedBox(height: 12),
                    _fotoActions(),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  /// Kamera, galeri, dan hapus foto. Ketiganya bisa dibungkus ke baris baru.
  Widget _fotoActions() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        _fotoButton(
          icon: Icons.photo_camera_outlined,
          label: 'Kamera',
          onTap: () => _pickFoto(ImageSource.camera),
        ),
        _fotoButton(
          icon: Icons.photo_library_outlined,
          label: 'Galeri',
          onTap: () => _pickFoto(ImageSource.gallery),
        ),
        if (_hasFoto)
          TextButton.icon(
            onPressed: _saving ? null : _buangFoto,
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            label: const Text('Hapus foto'),
            style: TextButton.styleFrom(
              foregroundColor: SibasColors.status.badText,
              minimumSize: const Size(0, _touch),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              textStyle: const TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
      ],
    );
  }

  /// Foto persegi radius 20; ketuk untuk memilih/mengganti dari galeri.
  Widget _fotoTile(double size) {
    return Semantics(
      button: true,
      label: _hasFoto ? 'Ganti foto jenis sampah' : 'Pilih foto jenis sampah',
      child: Container(
        width: size,
        height: size,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: SibasColors.mintWash,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: SibasColors.border),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _saving ? null : () => _pickFoto(ImageSource.gallery),
            child: Stack(
              fit: StackFit.expand,
              children: [
                _fotoPreview(),
                Positioned(
                  right: 6,
                  bottom: 6,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.92),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.photo_camera_outlined,
                      size: 15,
                      color: SibasColors.leaf,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fotoPreview() {
    if (_fotoBytes != null) {
      return Image.memory(_fotoBytes!, fit: BoxFit.cover);
    }

    final url = _hapusFoto
        ? null
        : ref.watch(fotoJenisSampahUrlProvider(_initialFoto));
    if (url == null || url.isEmpty) return _fotoKosong();

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (_, __, ___) => _fotoKosong(),
    );
  }

  Widget _fotoKosong() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.image_outlined, size: 26, color: SibasColors.faint),
          const SizedBox(height: 6),
          Text(
            'Belum ada',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: SibasColors.faint,
            ),
          ),
        ],
      ),
    );
  }

  Widget _fotoButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return OutlinedButton.icon(
      onPressed: _saving ? null : onTap,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: _fotoButtonStyle,
    );
  }

  Widget _detailCard() {
    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('DETAIL JENIS SAMPAH', style: _microLabel),
          const SizedBox(height: 14),
          _namaField(),
          const SizedBox(height: 14),
          _satuanField(),
          const SizedBox(height: 14),
          _tarifField(),
          const SizedBox(height: 14),
          _deskripsiField(),
        ],
      ),
    );
  }

  Widget _namaField() {
    return TextFormField(
      controller: _name,
      textCapitalization: TextCapitalization.words,
      textInputAction: TextInputAction.next,
      style: _fieldText,
      decoration: const InputDecoration(
        labelText: 'Nama jenis sampah',
        hintText: 'Contoh: Botol Plastik PET',
      ),
      validator: (v) =>
          (v ?? '').trim().isEmpty ? 'Nama wajib diisi.' : null,
    );
  }

  Widget _satuanField() {
    return TextFormField(
      controller: _unit,
      textInputAction: TextInputAction.next,
      style: _fieldText,
      decoration: const InputDecoration(
        labelText: 'Satuan',
        hintText: 'kg',
        helperText: 'Bawaan kg. Isi lain bila dihitung per unit.',
      ),
    );
  }

  Widget _tarifField() {
    return TextFormField(
      controller: _price,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: TextInputAction.next,
      style: _fieldText.copyWith(fontFeatures: _numbers),
      decoration: const InputDecoration(
        labelText: 'Tarif per kg (Rp)',
        hintText: '0',
        helperText: 'Isi 0 untuk jenis non-rupiah.',
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
      maxLines: 3,
      style: _fieldText,
      textCapitalization: TextCapitalization.sentences,
      decoration: const InputDecoration(
        labelText: 'Deskripsi (opsional)',
        hintText: 'Catatan singkat untuk petugas.',
      ),
    );
  }

  Widget _errorCard() {
    return SurfaceCard(
      tone: SurfaceTone.subtle,
      radius: 16,
      color: SibasColors.status.rejectedBackground,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 18,
            color: SibasColors.status.rejectedText,
          ),
          const SizedBox(width: 10),
          Expanded(
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
      ),
    );
  }

  /// Action bar menempel di bawah, aman dari home indicator (§4, §9).
  Widget _actionBar() {
    return Container(
      decoration: BoxDecoration(
        color: SibasColors.background,
        border: Border(top: BorderSide(color: SibasColors.border)),
      ),
      padding: const EdgeInsets.only(top: 12, bottom: 12),
      child: SafeArea(
        top: false,
        child: ContentWidth(
          maxWidth: _formWidth,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 4,
                child: SizedBox(
                  height: _touch,
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.maybePop(context),
                    style: _batalStyle,
                    child: const Text('Batal'),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 6,
                child: SizedBox(
                  height: 52,
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
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Rute ubah tanpa data awal: beri jalan kembali, jangan crash.
  Widget _notFound() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: ContentWidth(
          maxWidth: _formWidth,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: SurfaceCard(
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
                        Icons.inventory_2_outlined,
                        size: 26,
                        color: SibasColors.leaf,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Data tidak ditemukan',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: SibasColors.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Data jenis sampah tidak tersedia. Kembali ke daftar, '
                      'lalu pilih Ubah dari kartu jenis sampah.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.4,
                        color: SibasColors.muted,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: _touch,
                      child: FilledButton(
                        onPressed: () => Navigator.maybePop(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: SibasColors.leaf,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          textStyle: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        child: const Text('Kembali'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
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
