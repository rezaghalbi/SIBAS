import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/koordinat_tautan.dart';
import '../../domain/models/bank_location_model.dart';
import '../providers/bank_location_provider.dart';
import '../../../../core/theme/sibas_colors.dart';

/// Target sentuh minimum (§4).
const double _touch = 44;

/// Lebar konten: sama dengan `ContentWidth` agar hero sejajar (§4).
const double _maxContentWidth = 1120;

/// Koordinat dan rekap memakai lebar digit tetap (§3).
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

/// Field 16 px agar Safari iOS tidak memperbesar halaman (§9).
TextStyle get _fieldText => TextStyle(
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

/// Master lokasi bank sampah: daftar titik setor/tarik, ubah, dan hapus.
///
/// Seluruh kartu konten memakai `SurfaceCard`; `GlassPanel` hanya dipakai
/// sheet form (`dense`). Status aktif diubah lewat sakelar di form, bukan
/// tombol cepat, karena perubahan titik aktif memengaruhi alur setor.
class AdminLocationsScreen extends ConsumerStatefulWidget {
  const AdminLocationsScreen({super.key});

  @override
  ConsumerState<AdminLocationsScreen> createState() =>
      _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends ConsumerState<AdminLocationsScreen> {
  /// Id lokasi yang sedang dihapus; mengunci aksi pada kartu tersebut.
  String? _busyId;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bankLocationsProvider);
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: SibasColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busyId == null ? () => _openForm() : null,
        backgroundColor: SibasColors.leaf,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_location_alt_rounded),
        label: const Text('Tambah Lokasi'),
      ),
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _hero(state)),
          ..._content(state),
          // Nav mengambang tidak boleh menutup aksi terakhir (§4).
          SliverToBoxAdapter(child: SizedBox(height: 96 + bottomInset)),
        ],
      ),
    );
  }

  /// Hero memakai gutter sendiri; dibatasi lebar agar sejajar kartu isi.
  Widget _hero(AsyncValue<List<BankLocationModel>> state) {
    final semua = state.valueOrNull;
    final aktif = semua == null
        ? '—'
        : '${semua.where((lokasi) => lokasi.isActive).length}';
    final total = semua == null ? '—' : '${semua.length}';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: HeroHeader(
          title: 'Lokasi Bank Sampah',
          subtitle: 'Titik setor dan tarik sampah',
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
          bottomContent: Row(
            children: [
              Expanded(child: _heroStat('Titik aktif', aktif)),
              const SizedBox(width: 16),
              Container(
                width: 1,
                height: 32,
                color: SibasColors.glassBorder,
              ),
              const SizedBox(width: 16),
              Expanded(child: _heroStat('Total lokasi', total)),
            ],
          ),
        ),
      ),
    );
  }

  /// Angka ringkas di dalam hero. Latar hero sudah hijau pekat, jadi teks
  /// memakai putih dengan alfa bertingkat alih-alih `SurfaceCard`.
  Widget _heroStat(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: Colors.white70,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            fontFeatures: _numbers,
          ),
        ),
      ],
    );
  }

  List<Widget> _content(AsyncValue<List<BankLocationModel>> state) {
    return state.when(
      data: (list) {
        if (list.isEmpty) return [_stateSliver(_emptyCard())];

        return [
          SliverToBoxAdapter(child: _sectionHeader(list.length)),
          SliverList.builder(
            itemCount: list.length,
            itemBuilder: (_, i) => ContentWidth(child: _itemCard(list[i])),
          ),
        ];
      },
      loading: () => [_stateSliver(_loadingCard())],
      error: (_, __) => [
        _stateSliver(
          _errorCard(
            onRetry: () => ref.invalidate(bankLocationsProvider),
          ),
        ),
      ],
    );
  }

  Widget _sectionHeader(int jumlah) {
    return ContentWidth(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(0, 24, 0, 8),
        child: Row(
          children: [
            Expanded(
              child: Text(
                'Daftar lokasi',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: _sectionTitle,
              ),
            ),
            Text(
              '$jumlah lokasi',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: SibasColors.muted,
                fontFeatures: _numbers,
              ),
            ),
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Muat ulang',
              onPressed: () => ref.invalidate(bankLocationsProvider),
              icon: Icon(
                Icons.refresh_rounded,
                size: 18,
                color: SibasColors.leaf,
              ),
              style: IconButton.styleFrom(
                minimumSize: const Size(_touch, _touch),
              ),
            ),
          ],
        ),
      ),
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

  /// Satu lokasi. Seluruh permukaan kartu membuka form ubah; tombol Ubah dan
  /// Hapus tetap target sentuh terpisah 44 px.
  Widget _itemCard(BankLocationModel lokasi) {
    final busy = _busyId == lokasi.id;

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: busy ? null : () => _openForm(lokasi),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lokasi.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: _sectionTitle,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            lokasi.address,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12.5,
                              height: 1.35,
                              color: SibasColors.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _statusChip(lokasi.isActive),
                  ],
                ),
                if (lokasi.hasCoordinates) ...[
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Icon(
                        Icons.my_location_rounded,
                        size: 14,
                        color: SibasColors.leaf,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          lokasi.koordinatLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: SibasColors.primary,
                            fontFeatures: _numbers,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (busy) ...[
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Memproses…',
                        style: TextStyle(
                          fontSize: 12,
                          color: SibasColors.muted,
                        ),
                      ),
                    ],
                    const Spacer(),
                    OutlinedButton.icon(
                      onPressed: busy ? null : () => _openForm(lokasi),
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
                      onPressed: busy ? null : () => _delete(lokasi),
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
          ),
        ),
      ),
    );
  }

  /// Pil status 44 px. Titik 5–6 px menemani teks agar status tidak
  /// disampaikan lewat warna saja (§2).
  Widget _statusChip(bool aktif) {
    final ink = aktif ? SibasColors.status.approvedText : SibasColors.muted;
    final surface = aktif
        ? SibasColors.status.approvedBackground
        : SibasColors.status.neutralText.withValues(alpha: 0.12);

    return Container(
      height: _touch,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: ShapeDecoration(
        color: surface,
        shape: StadiumBorder(
          side: BorderSide(color: ink.withValues(alpha: 0.18)),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
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
            aktif ? 'Aktif' : 'Nonaktif',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ink,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm([BankLocationModel? initial]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: SibasColors.text.withValues(alpha: 0.36),
      builder: (_) => _LocationFormSheet(initial: initial),
    );
    if (saved != true || !mounted) return;

    ref.invalidate(bankLocationsProvider);
    _toast(
      initial == null
          ? 'Lokasi bank sampah ditambahkan.'
          : 'Lokasi bank sampah diperbarui.',
    );
  }

  Future<void> _delete(BankLocationModel lokasi) async {
    final confirmed = await _confirm(
      title: 'Hapus lokasi?',
      message: '"${lokasi.name}" akan dihapus permanen bila belum dipakai '
          'transaksi. Lokasi yang sudah dipakai akan dinonaktifkan dan '
          'riwayat setoran tetap tersimpan.',
    );
    if (!confirmed || !mounted) return;

    setState(() => _busyId = lokasi.id);
    try {
      final repo = ref.read(bankLocationRepositoryProvider);
      final dihapus = await repo.hapus(lokasi.id);
      if (!mounted) return;
      _toast(
        dihapus
            ? 'Lokasi bank sampah dihapus.'
            : 'Lokasi sudah dipakai transaksi sehingga dinonaktifkan.',
      );
    } catch (error) {
      if (!mounted) return;
      _toast(pesanKesalahan(error), isError: true);
    } finally {
      if (mounted) {
        setState(() => _busyId = null);
        ref.invalidate(bankLocationsProvider);
      }
    }
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
              Icons.location_on_rounded,
              size: 26,
              color: SibasColors.leaf,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Belum ada lokasi bank sampah',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SibasColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tambahkan lokasi agar mahasiswa bisa memilih titik setor.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: SibasColors.muted,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => _openForm(),
            style: FilledButton.styleFrom(
              backgroundColor: SibasColors.leaf,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(0, _touch),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              textStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Tambah Lokasi'),
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
            'Memuat lokasi bank sampah...',
            textAlign: TextAlign.center,
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
            'Gagal memuat lokasi',
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

/// Angka koordinat tanpa nol berlebih, mis. `-7.797068`. Kosong bila null.
String _angkaKoordinat(double? value) {
  if (value == null) return '';
  return value
      .toStringAsFixed(6)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
}

/// Menerima koma desimal Indonesia. Kosong berarti null (tanpa koordinat).
double? _parseAngka(String raw) {
  final text = raw.trim().replaceAll(',', '.');
  if (text.isEmpty) return null;
  return double.tryParse(text);
}

/// Field sheet memakai sudut 16 px (§4) di semua keadaan.
InputDecoration _dekorasi({
  required String label,
  String? hint,
}) {
  OutlineInputBorder garis(Color color) {
    return OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: color, width: 1.5),
    );
  }

  return InputDecoration(
    labelText: label,
    hintText: hint,
    counterText: '',
    border: garis(SibasColors.border),
    enabledBorder: garis(SibasColors.border),
    focusedBorder: garis(SibasColors.leaf),
    errorBorder: garis(SibasColors.status.badText),
    focusedErrorBorder: garis(SibasColors.status.badText),
  );
}

/// Lat/long wajib diisi bersamaan dan berada di rentangnya.
String? _validasiKoordinat({
  required String? value,
  required String pasangan,
  required double min,
  required double max,
  required String label,
}) {
  final text = (value ?? '').trim();
  if (text.isEmpty) {
    return pasangan.trim().isEmpty ? null : 'Isi ${label.toLowerCase()} juga.';
  }

  final angka = _parseAngka(text);
  if (angka == null) return 'Masukkan angka yang valid.';
  if (angka < min || angka > max) {
    return '$label harus antara ${min.toInt()} dan ${max.toInt()}.';
  }
  return null;
}

/// Form tambah/ubah lokasi dalam sheet. Pop `true` bila tersimpan.
class _LocationFormSheet extends ConsumerStatefulWidget {
  final BankLocationModel? initial;

  const _LocationFormSheet({this.initial});

  @override
  ConsumerState<_LocationFormSheet> createState() =>
      _LocationFormSheetState();
}

class _LocationFormSheetState extends ConsumerState<_LocationFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _latitude;
  late final TextEditingController _longitude;
  final _tautan = TextEditingController();

  late bool _isActive;
  bool _saving = false;
  String? _error;
  String? _pesanKoordinat;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final lokasi = widget.initial;
    _name = TextEditingController(text: lokasi?.name ?? '');
    _address = TextEditingController(text: lokasi?.address ?? '');
    _latitude = TextEditingController(
      text: _angkaKoordinat(lokasi?.latitude),
    );
    _longitude = TextEditingController(
      text: _angkaKoordinat(lokasi?.longitude),
    );
    _isActive = lokasi?.isActive ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _latitude.dispose();
    _longitude.dispose();
    _tautan.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      await ref.read(bankLocationRepositoryProvider).simpan(
            id: widget.initial?.id,
            name: _name.text.trim(),
            address: _address.text.trim(),
            latitude: _parseAngka(_latitude.text),
            longitude: _parseAngka(_longitude.text),
            isActive: _isActive,
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        // Pesan server (mis. "Nama lokasi sudah dipakai.") tampil di sheet.
        _error = pesanKesalahan(error);
      });
    }
  }

  Widget _namaField() {
    return TextFormField(
      controller: _name,
      enabled: !_saving,
      maxLength: 80,
      textCapitalization: TextCapitalization.words,
      style: _fieldText,
      decoration: _dekorasi(
        label: 'Nama lokasi',
        hint: 'Contoh: Bank Sampah Poltekkes',
      ),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) return 'Nama lokasi wajib diisi.';
        if (text.length < 3) return 'Nama minimal 3 karakter.';
        if (text.length > 80) return 'Nama maksimal 80 karakter.';
        return null;
      },
    );
  }

  Widget _alamatField() {
    return TextFormField(
      controller: _address,
      enabled: !_saving,
      maxLength: 200,
      minLines: 2,
      maxLines: 3,
      textCapitalization: TextCapitalization.sentences,
      style: _fieldText,
      decoration: _dekorasi(label: 'Alamat', hint: 'Jalan, kelurahan, kota'),
      validator: (v) {
        final text = (v ?? '').trim();
        if (text.isEmpty) return 'Alamat wajib diisi.';
        if (text.length < 3) return 'Alamat minimal 3 karakter.';
        if (text.length > 200) return 'Alamat maksimal 200 karakter.';
        return null;
      },
    );
  }

  Widget _latitudeField() {
    return TextFormField(
      controller: _latitude,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      style: _fieldText,
      decoration: _dekorasi(label: 'Latitude', hint: '-7.797068'),
      validator: (v) => _validasiKoordinat(
        value: v,
        pasangan: _longitude.text,
        min: -90,
        max: 90,
        label: 'Latitude',
      ),
    );
  }

  Widget _longitudeField() {
    return TextFormField(
      controller: _longitude,
      enabled: !_saving,
      keyboardType: const TextInputType.numberWithOptions(
        decimal: true,
        signed: true,
      ),
      style: _fieldText,
      decoration: _dekorasi(label: 'Longitude', hint: '110.370529'),
      validator: (v) => _validasiKoordinat(
        value: v,
        pasangan: _latitude.text,
        min: -180,
        max: 180,
        label: 'Longitude',
      ),
    );
  }

  /// Sakelar aktif sebagai panel `subtle` di dalam sheet.
  Widget _aktifSwitch() {
    return SurfaceCard(
      tone: SurfaceTone.subtle,
      radius: 16,
      padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
      child: Row(
        children: [
          Icon(
            Icons.visibility_rounded,
            size: 18,
            color: SibasColors.leaf,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Lokasi aktif',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: SibasColors.text,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  'Nonaktif tetap tersimpan, tidak bisa dipilih.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.35,
                    color: SibasColors.muted,
                  ),
                ),
              ],
            ),
          ),
          Switch(
            value: _isActive,
            onChanged: _saving
                ? null
                : (value) => setState(() => _isActive = value),
          ),
        ],
      ),
    );
  }

  void _ambilKoordinat() {
    final hasil = koordinatDariTautan(_tautan.text);
    if (hasil == null) {
      setState(() {
        _pesanKoordinat =
            'Koordinat tidak ditemukan. Tempel tautan Google Maps yang '
            'memuat titik lokasi, atau isi manual.';
      });
      return;
    }
    _latitude.text = hasil.latitude;
    _longitude.text = hasil.longitude;
    setState(() => _pesanKoordinat = 'Koordinat terisi dari tautan.');
  }

  Widget _tautanField() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: TextField(
            controller: _tautan,
            style: TextStyle(fontSize: 16, color: SibasColors.text),
            decoration: const InputDecoration(
              labelText: 'Tautan Google Maps (opsional)',
              hintText: 'Tempel tautan berbagi lokasi di sini',
            ),
            onChanged: (_) {
              if (_pesanKoordinat != null) {
                setState(() => _pesanKoordinat = null);
              }
            },
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 56,
          child: OutlinedButton(
            onPressed: _ambilKoordinat,
            child: const Text('Ambil'),
          ),
        ),
      ],
    );
  }

  Widget _koordinatGroup() {
    final petunjuk = Text(
      'Isi latitude dan longitude bersamaan, atau kosongkan keduanya.',
      style: TextStyle(
        fontSize: 11.5,
        height: 1.35,
        color: SibasColors.muted,
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Koordinat (opsional)',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: SibasColors.text,
          ),
        ),
        const SizedBox(height: 8),
        _tautanField(),
        if (_pesanKoordinat != null) ...[
          const SizedBox(height: 6),
          Text(
            _pesanKoordinat!,
            style: TextStyle(fontSize: 11.5, color: SibasColors.muted),
          ),
        ],
        const SizedBox(height: 4),
        petunjuk,
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            // Di bawah 380 px dua field berbagi lebar terlalu sempit untuk
            // label dan tanda minus; tumpuk vertikal.
            if (constraints.maxWidth < 380) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _latitudeField(),
                  const SizedBox(height: 12),
                  _longitudeField(),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: _latitudeField()),
                const SizedBox(width: 12),
                Expanded(child: _longitudeField()),
              ],
            );
          },
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

  Widget _sheetBody() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _handle(),
        const SizedBox(height: 12),
        Text(
          _isEdit ? 'Ubah Lokasi' : 'Tambah Lokasi',
          style: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.3,
            color: SibasColors.text,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          _isEdit
              ? 'Perubahan langsung dipakai pada pengajuan berikutnya.'
              : 'Lokasi baru langsung bisa dipilih mahasiswa.',
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
              _alamatField(),
              const SizedBox(height: 12),
              _koordinatGroup(),
              const SizedBox(height: 16),
              _aktifSwitch(),
              if (_error != null) ...[
                const SizedBox(height: 12),
                SurfaceCard(
                  tone: SurfaceTone.subtle,
                  radius: 16,
                  color: SibasColors.status.rejectedBackground,
                  padding: const EdgeInsets.all(12),
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
                radius: 28,
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
