import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/models/student_model.dart';
import '../../domain/student_filter.dart';
import '../providers/student_provider.dart';
import '../../../../core/theme/sibas_colors.dart';

/// Target sentuh minimum (§4).
const double _touch = 44;

/// Lebar maksimum sheet detail agar tetap terbaca di desktop.
const double _sheetWidth = 560;

/// Lebar konten: sama dengan `ContentWidth` agar hero sejajar (§4).
const double _maxContentWidth = 1120;

/// Saldo dan berat memakai lebar digit tetap (§3).
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

/// Daftar akun mahasiswa untuk admin (baca saja).
///
/// Pencarian dilakukan lokal lewat [saringMahasiswa]; tidak memakai filter
/// global admin agar state halaman lain tidak ikut berubah.
class AdminStudentsScreen extends ConsumerStatefulWidget {
  const AdminStudentsScreen({super.key});

  @override
  ConsumerState<AdminStudentsScreen> createState() =>
      _AdminStudentsScreenState();
}

class _AdminStudentsScreenState extends ConsumerState<AdminStudentsScreen> {
  static final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );
  static final _berat = NumberFormat('#,##0.##', 'id_ID');
  static final _tanggal = DateFormat('dd MMM yyyy', 'id_ID');

  final _cari = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _cari.dispose();
    super.dispose();
  }

  Future<void> _muatUlang() async {
    try {
      ref.invalidate(studentsProvider);
      await ref.read(studentsProvider.future);
    } catch (_) {
      // Pesan kegagalan sudah tampil pada kartu status.
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(studentsProvider);
    final inset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: SibasColors.background,
      body: RefreshIndicator(
        color: SibasColors.leaf,
        onRefresh: _muatUlang,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _hero()),
            SliverToBoxAdapter(
              child: ContentWidth(
                child: Padding(
                  padding: const EdgeInsets.only(top: 20),
                  child: _kolomCari(),
                ),
              ),
            ),
            ..._isi(state),
            // Nav mengambang tidak boleh menutup baris terakhir (§4).
            SliverToBoxAdapter(child: SizedBox(height: 96 + inset)),
          ],
        ),
      ),
    );
  }

  /// Hero memakai gutter sendiri; dibatasi lebar agar sejajar kartu isi.
  Widget _hero() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxContentWidth),
        child: HeroHeader(
          title: 'Data Mahasiswa',
          subtitle: 'Daftar akun mahasiswa',
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

  /// Kolom pencarian: field 16 px di atas panel kaca statis.
  Widget _kolomCari() {
    return SurfaceCard(
      tone: SurfaceTone.subtle,
      radius: 16,
      child: TextField(
        controller: _cari,
        onChanged: (value) => setState(() => _query = value),
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 16, color: SibasColors.text),
        decoration: InputDecoration(
          hintText: 'Cari nama, NIM, email, atau WA',
          hintMaxLines: 1,
          hintStyle: TextStyle(
            fontSize: 15,
            color: SibasColors.muted,
          ),
          prefixIcon: Icon(
            Icons.search_rounded,
            size: 20,
            color: SibasColors.leaf,
          ),
          prefixIconConstraints: const BoxConstraints(
            minWidth: _touch,
            minHeight: _touch,
          ),
          suffixIcon: _query.isEmpty
              ? null
              : IconButton(
                  tooltip: 'Hapus pencarian',
                  onPressed: () {
                    _cari.clear();
                    setState(() => _query = '');
                  },
                  icon: Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: SibasColors.muted,
                  ),
                ),
          filled: false,
          isDense: true,
          contentPadding: const EdgeInsets.fromLTRB(0, 14, 12, 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  List<Widget> _isi(AsyncValue<List<StudentModel>> state) {
    return state.when<List<Widget>>(
      loading: () => [_stateSliver(_loadingCard())],
      error: (error, _) => [
        _stateSliver(
          _kartuPesan(
            icon: Icons.cloud_off_rounded,
            judul: 'Gagal memuat data mahasiswa',
            pesan: pesanKesalahan(error),
            aksi: OutlinedButton.icon(
              onPressed: () => ref.invalidate(studentsProvider),
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
          ),
        ),
      ],
      data: (semua) {
        final data = saringMahasiswa(semua, _query);
        if (data.isEmpty) {
          return [
            _stateSliver(
              _kartuPesan(
                icon: _query.trim().isEmpty
                    ? Icons.people_outline_rounded
                    : Icons.search_off_rounded,
                judul: _query.trim().isEmpty
                    ? 'Belum ada mahasiswa'
                    : 'Mahasiswa tidak ditemukan',
                pesan: _query.trim().isEmpty
                    ? 'Akun mahasiswa yang mendaftar akan tampil di sini.'
                    : 'Coba kata kunci lain: nama, NIM, email, atau WA.',
              ),
            ),
          ];
        }

        return [
          SliverToBoxAdapter(
            child: ContentWidth(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Daftar mahasiswa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _sectionTitle,
                      ),
                    ),
                    Text(
                      '${data.length} akun',
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
            itemCount: data.length,
            itemBuilder: (_, i) => ContentWidth(
              child: _kartuMahasiswa(data[i]),
            ),
          ),
        ];
      },
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

  Widget _kartuMahasiswa(StudentModel m) {
    final nim = (m.nim ?? '').trim();

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.zero,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _bukaDetail(m),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _avatar(m.fullName, radius: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  m.fullName,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: _sectionTitle,
                                ),
                              ),
                              if (m.terhapus) ...[
                                const SizedBox(width: 6),
                                _badgeTerhapus(),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            nim.isEmpty ? 'NIM belum diisi' : 'NIM $nim',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: SibasColors.muted,
                              fontFeatures: _numbers,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: SibasColors.muted,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SurfaceCard(
                  tone: SurfaceTone.subtle,
                  radius: 12,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: _statistik(
                          'Saldo',
                          _currency.format(m.balance),
                          SibasColors.primary,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statistik(
                          'Total berat',
                          '${_berat.format(m.totalWeight)} kg',
                          SibasColors.text,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _statistik(String label, String nilai, Color warna) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 11, color: SibasColors.muted),
        ),
        const SizedBox(height: 2),
        Text(
          nilai,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
            color: warna,
            fontFeatures: _numbers,
          ),
        ),
      ],
    );
  }

  Widget _avatar(String nama, {double radius = 24}) {
    final huruf = nama.trim().isEmpty ? '?' : nama.trim()[0].toUpperCase();
    return CircleAvatar(
      radius: radius,
      backgroundColor: SibasColors.mintWash,
      child: Text(
        huruf,
        style: TextStyle(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w800,
          color: SibasColors.primary,
        ),
      ),
    );
  }

  Widget _badgeTerhapus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: SibasColors.status.rejectedBackground,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        'Terhapus',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: SibasColors.status.rejectedText,
        ),
      ),
    );
  }

  Widget _badgeStatus(StudentModel m) {
    final aktif = m.deletedAt == null;
    final ink = aktif
        ? SibasColors.status.approvedText
        : SibasColors.status.rejectedText;
    final surface = aktif
        ? SibasColors.status.approvedBackground
        : SibasColors.status.rejectedBackground;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        aktif ? 'Aktif' : 'Terhapus',
        style: TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w700,
          color: ink,
        ),
      ),
    );
  }

  Widget _kartuPesan({
    required IconData icon,
    required String judul,
    required String pesan,
    Widget? aksi,
  }) {
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
            child: Icon(icon, size: 26, color: SibasColors.leaf),
          ),
          const SizedBox(height: 14),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SibasColors.text,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pesan,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: SibasColors.muted,
            ),
          ),
          if (aksi != null) ...[const SizedBox(height: 16), aksi],
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
            'Memuat data mahasiswa...',
            style: TextStyle(fontSize: 12.5, color: SibasColors.muted),
          ),
        ],
      ),
    );
  }

  Future<void> _bukaDetail(StudentModel m) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      barrierColor: SibasColors.text.withValues(alpha: 0.36),
      builder: (ctx) => _detailSheet(ctx, m),
    );
  }

  Widget _detailSheet(BuildContext ctx, StudentModel m) {
    final insets = MediaQuery.viewInsetsOf(ctx);
    final height = MediaQuery.sizeOf(ctx).height - insets.bottom;
    final maxHeight = height * 0.9;
    final terhapus = m.deletedAt;
    final statusAkun = terhapus == null
        ? 'Aktif'
        : 'Terhapus · ${_tanggal.format(terhapus.toLocal())}';

    return Padding(
      padding: EdgeInsets.only(bottom: insets.bottom),
      child: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.bottomCenter,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: _sheetWidth,
              maxHeight: maxHeight,
            ),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: GlassPanel(
                tone: GlassTone.dense,
                radius: 24,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 36,
                          height: 4,
                          decoration: BoxDecoration(
                            color: SibasColors.border,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          _avatar(m.fullName),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  m.fullName,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: _sectionTitle,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _nilaiAtauStrip(m.email),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    color: SibasColors.muted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          _badgeStatus(m),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _ringkasan(
                              'Saldo',
                              _currency.format(m.balance),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _ringkasan(
                              'Total berat',
                              '${_berat.format(m.totalWeight)} kg',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SurfaceCard(
                        tone: SurfaceTone.subtle,
                        radius: 16,
                        padding: const EdgeInsets.fromLTRB(14, 14, 14, 2),
                        child: Column(
                          children: [
                            _barisDetail('NIM', _nilaiAtauStrip(m.nim)),
                            _barisDetail('Email', _nilaiAtauStrip(m.email)),
                            _barisDetail('Nomor WA', _nilaiAtauStrip(m.phone)),
                            _barisDetail(
                              'Tanggal daftar',
                              m.createdAt == null
                                  ? '-'
                                  : _tanggal.format(m.createdAt!.toLocal()),
                            ),
                            _barisDetail('Status akun', statusAkun),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: () {
                          Navigator.pop(ctx);
                          _openUbah(ctx, m);
                        },
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: SibasColors.leaf,
                          side: BorderSide(color: SibasColors.border),
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Ubah data mahasiswa'),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: FilledButton.styleFrom(
                            backgroundColor: SibasColors.leaf,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            minimumSize: const Size(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text('Tutup'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Form koreksi identitas mahasiswa oleh admin (nama, NIM, nomor WA).
  Future<void> _openUbah(BuildContext ctx, StudentModel m) async {
    final berhasil = await showModalBottomSheet<bool>(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: SibasColors.scrim,
      builder: (_) => _UbahMahasiswaSheet(mahasiswa: m),
    );
    if (berhasil == true && ctx.mounted) {
      ref.invalidate(studentsProvider);
    }
  }

  Widget _ringkasan(String label, String nilai) {
    return SurfaceCard(
      tone: SurfaceTone.subtle,
      radius: 12,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 11, color: SibasColors.muted),
          ),
          const SizedBox(height: 2),
          Text(
            nilai,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: SibasColors.text,
              fontFeatures: _numbers,
            ),
          ),
        ],
      ),
    );
  }

  Widget _barisDetail(String label, String nilai) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                color: SibasColors.muted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              nilai,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: SibasColors.text,
                fontFeatures: _numbers,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Nilai kosong tampil sebagai tanda hubung, bukan teks karangan.
String _nilaiAtauStrip(String? value) {
  final teks = value?.trim() ?? '';
  return teks.isEmpty ? '-' : teks;
}


/// Sheet koreksi identitas mahasiswa. Hanya nama, NIM, dan nomor WhatsApp;
/// peran, saldo, dan status akun tetap diatur server.
class _UbahMahasiswaSheet extends ConsumerStatefulWidget {
  const _UbahMahasiswaSheet({required this.mahasiswa});

  final StudentModel mahasiswa;

  @override
  ConsumerState<_UbahMahasiswaSheet> createState() =>
      _UbahMahasiswaSheetState();
}

class _UbahMahasiswaSheetState extends ConsumerState<_UbahMahasiswaSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nama;
  late final TextEditingController _nim;
  late final TextEditingController _wa;

  bool _menyimpan = false;
  String? _pesan;

  @override
  void initState() {
    super.initState();
    _nama = TextEditingController(text: widget.mahasiswa.fullName);
    _nim = TextEditingController(text: widget.mahasiswa.nim ?? '');
    _wa = TextEditingController(text: widget.mahasiswa.phone ?? '');
  }

  @override
  void dispose() {
    _nama.dispose();
    _nim.dispose();
    _wa.dispose();
    super.dispose();
  }

  Future<void> _simpan() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _menyimpan = true;
      _pesan = null;
    });
    try {
      await ref.read(studentRepositoryProvider).ubahMahasiswa(
            id: widget.mahasiswa.id,
            fullName: _nama.text.trim(),
            nim: _nim.text.trim().isEmpty ? null : _nim.text.trim(),
            phone: _wa.text.trim().isEmpty ? null : _wa.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _menyimpan = false;
        _pesan = pesanKesalahan(error);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: GlassPanel(
        tone: GlassTone.dense,
        radius: 28,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Ubah data mahasiswa',
                    style: TextStyle(
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.3,
                      color: SibasColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Peran, saldo, dan status akun tidak dapat diubah di sini.',
                    style: TextStyle(fontSize: 12.5, color: SibasColors.muted),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _nama,
                    textCapitalization: TextCapitalization.words,
                    style: TextStyle(fontSize: 16, color: SibasColors.text),
                    decoration: const InputDecoration(labelText: 'Nama lengkap'),
                    validator: (value) {
                      final nama = (value ?? '').trim();
                      if (nama.length < 2 || nama.length > 80) {
                        return 'Nama harus 2 sampai 80 karakter.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _nim,
                    style: TextStyle(fontSize: 16, color: SibasColors.text),
                    decoration: const InputDecoration(labelText: 'NIM'),
                    validator: (value) {
                      final nim = (value ?? '').trim();
                      if (nim.isEmpty) return null;
                      if (!RegExp(r'^[A-Za-z0-9]{3,20}$').hasMatch(nim)) {
                        return 'NIM hanya huruf dan angka, 3 sampai 20.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _wa,
                    keyboardType: TextInputType.phone,
                    style: TextStyle(fontSize: 16, color: SibasColors.text),
                    decoration: const InputDecoration(
                      labelText: 'Nomor WhatsApp',
                      hintText: '081234567890',
                    ),
                    validator: (value) {
                      final wa = (value ?? '').trim();
                      if (wa.isEmpty) return null;
                      if (!RegExp(r'^[0-9+][0-9 -]{7,19}$').hasMatch(wa)) {
                        return 'Nomor WhatsApp tidak valid.';
                      }
                      return null;
                    },
                  ),
                  if (_pesan != null) ...[
                    const SizedBox(height: 12),
                    SurfaceCard(
                      tone: SurfaceTone.subtle,
                      radius: 12,
                      color: SibasColors.status.rejectedBackground,
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        _pesan!,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: SibasColors.status.rejectedText,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed:
                              _menyimpan ? null : () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 48),
                            side: BorderSide(color: SibasColors.border),
                          ),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _menyimpan ? null : _simpan,
                          style: FilledButton.styleFrom(
                            backgroundColor: SibasColors.leaf,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 48),
                          ),
                          child: _menyimpan
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
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
              ),
            ),
          ),
        ),
      ),
    );
  }
}
