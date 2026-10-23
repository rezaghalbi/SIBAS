import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/models/student_model.dart';
import '../../domain/student_filter.dart';
import '../providers/student_provider.dart';

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
const TextStyle _sectionTitle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  color: AppColors.textPrimary,
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
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primaryMain,
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
        style: const TextStyle(fontSize: 16, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Cari nama, NIM, email, atau WA',
          hintMaxLines: 1,
          hintStyle: const TextStyle(
            fontSize: 15,
            color: AppColors.textMuted,
          ),
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.primaryMain,
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
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 18,
                    color: AppColors.textMuted,
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
                foregroundColor: AppColors.primaryMain,
                side: const BorderSide(color: AppColors.borderLine),
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
                    const Expanded(
                      child: Text(
                        'Daftar mahasiswa',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _sectionTitle,
                      ),
                    ),
                    Text(
                      '${data.length} akun',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textMuted,
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
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                              fontFeatures: _numbers,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: AppColors.textMuted,
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
                          AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _statistik(
                          'Total berat',
                          '${_berat.format(m.totalWeight)} kg',
                          AppColors.textPrimary,
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
          style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
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
      backgroundColor: AppColors.mintSoftBackground,
      child: Text(
        huruf,
        style: TextStyle(
          fontSize: radius * 0.85,
          fontWeight: FontWeight.w800,
          color: AppColors.primaryDark,
        ),
      ),
    );
  }

  Widget _badgeTerhapus() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: const Text(
        'Terhapus',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: AppColors.statusRejectedText,
        ),
      ),
    );
  }

  Widget _badgeStatus(StudentModel m) {
    final aktif = m.deletedAt == null;
    final ink = aktif
        ? AppColors.statusApprovedText
        : AppColors.statusRejectedText;
    final surface = aktif
        ? AppColors.statusApprovedBg
        : AppColors.statusRejectedBg;

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
              color: AppColors.mintSoftBackground,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 26, color: AppColors.primaryMain),
          ),
          const SizedBox(height: 14),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            pesan,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          if (aksi != null) ...[const SizedBox(height: 16), aksi],
        ],
      ),
    );
  }

  Widget _loadingCard() {
    return const SurfaceCard(
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
            style: TextStyle(fontSize: 12.5, color: AppColors.textMuted),
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
      barrierColor: AppColors.textPrimary.withValues(alpha: 0.36),
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
                            color: AppColors.borderLine,
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
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    color: AppColors.textMuted,
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
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primaryMain,
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
            style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
          ),
          const SizedBox(height: 2),
          Text(
            nilai,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
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
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              nilai,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
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
