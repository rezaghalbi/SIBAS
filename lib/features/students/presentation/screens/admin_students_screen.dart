import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../domain/models/student_model.dart';
import '../../domain/student_filter.dart';
import '../providers/student_provider.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primaryMain,
        onRefresh: _muatUlang,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _header()),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 4),
              sliver: SliverToBoxAdapter(child: _kolomCari()),
            ),
            ..._isi(state),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return HeroHeader(
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
    );
  }

  /// Satu-satunya panel kaca di layar ini (1 blur); kartu daftar memakai
  /// permukaan solid agar tetap ringan saat digulir di web.
  Widget _kolomCari() {
    return GlassPanel(
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: TextField(
        controller: _cari,
        onChanged: (value) => setState(() => _query = value),
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
        decoration: InputDecoration(
          hintText: 'Cari nama, NIM, email, atau WA',
          prefixIcon: const Icon(
            Icons.search_rounded,
            size: 20,
            color: AppColors.textMuted,
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
          contentPadding: const EdgeInsets.symmetric(vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
      ),
    );
  }

  List<Widget> _isi(AsyncValue<List<StudentModel>> state) {
    return state.when<List<Widget>>(
      loading: () => const [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Center(child: CircularProgressIndicator()),
          ),
        ),
      ],
      error: (error, _) => [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
          sliver: SliverToBoxAdapter(
            child: _kartuPesan(
              icon: Icons.cloud_off_rounded,
              judul: 'Gagal memuat data mahasiswa',
              pesan: pesanKesalahan(error),
              aksi: ElevatedButton(
                onPressed: () => ref.invalidate(studentsProvider),
                child: const Text('Coba Lagi'),
              ),
            ),
          ),
        ),
      ],
      data: (semua) {
        final data = saringMahasiswa(semua, _query);
        if (data.isEmpty) {
          return [
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverToBoxAdapter(
                child: _kartuPesan(
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
            ),
          ];
        }

        return [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                '${data.length} mahasiswa',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textMuted,
                ),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
            sliver: SliverList.builder(
              itemCount: data.length,
              itemBuilder: (_, i) => _kartuMahasiswa(data[i]),
            ),
          ),
        ];
      },
    );
  }

  Widget _kartuMahasiswa(StudentModel m) {
    final nim = (m.nim ?? '').trim();
    final phone = (m.phone ?? '').trim();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _bukaDetail(m),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _avatar(m.fullName, radius: 21),
                    const SizedBox(width: 10),
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
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w800,
                                    color: AppColors.textPrimary,
                                  ),
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
                            _nilaiAtauStrip(nim),
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
                const SizedBox(height: 10),
                _barisInfo(
                  Icons.alternate_email_rounded,
                  _nilaiAtauStrip(m.email),
                ),
                const SizedBox(height: 6),
                _barisInfo(Icons.chat_outlined, _nilaiAtauStrip(phone)),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.mintSoftBackground,
                    borderRadius: BorderRadius.circular(12),
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
            fontSize: 13,
            fontWeight: FontWeight.w800,
            color: warna,
          ),
        ),
      ],
    );
  }

  Widget _barisInfo(IconData icon, String teks) {
    return Row(
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            teks,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted),
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

  Widget _kartuPesan({
    required IconData icon,
    required String judul,
    required String pesan,
    Widget? aksi,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.mintSoftBackground,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 24, color: AppColors.primaryMain),
          ),
          const SizedBox(height: 12),
          Text(
            judul,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
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

  Future<void> _bukaDetail(StudentModel m) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              0,
              20,
              20 + MediaQuery.viewInsetsOf(ctx).bottom,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
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
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: AppColors.borderLine),
                const SizedBox(height: 14),
                _barisDetail('Nama', m.fullName),
                _barisDetail('NIM', _nilaiAtauStrip(m.nim)),
                _barisDetail('Email', _nilaiAtauStrip(m.email)),
                _barisDetail('Nomor WA', _nilaiAtauStrip(m.phone)),
                _barisDetail('Saldo', _currency.format(m.balance)),
                _barisDetail(
                  'Total berat',
                  '${_berat.format(m.totalWeight)} kg',
                ),
                _barisDetail(
                  'Tanggal daftar',
                  m.createdAt == null
                      ? '-'
                      : _tanggal.format(m.createdAt!.toLocal()),
                ),
                _barisDetail(
                  'Status akun',
                  m.deletedAt == null
                      ? 'Aktif'
                      : 'Terhapus · ${_tanggal.format(m.deletedAt!.toLocal())}',
                  warna: m.deletedAt == null
                      ? AppColors.statusApprovedText
                      : AppColors.statusRejectedText,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _barisDetail(String label, String nilai, {Color? warna}) {
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
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: warna ?? AppColors.textPrimary,
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
