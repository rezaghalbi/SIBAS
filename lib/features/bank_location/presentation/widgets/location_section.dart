import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/sibas_colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../domain/models/bank_location_model.dart';
import '../providers/bank_location_provider.dart';

/// Panel radius untuk kartu lokasi dan baris di dalamnya (§4).
const double _panelRadius = 16;

/// Blok pemilih lokasi bank sampah, dipakai layar setor dan tarik.
///
/// Status muat dan galat dibaca dari [bankLocationsProvider]; daftar lokasi
/// aktif diturunkan lewat [activeLocationsProvider] yang bernilai kosong saat
/// memuat, jadi tidak boleh dipakai sendirian untuk mendeteksi loading.
class LocationSection extends ConsumerStatefulWidget {
  final SurfaceTone tone;

  const LocationSection({super.key, this.tone = SurfaceTone.card});

  @override
  ConsumerState<LocationSection> createState() => _LocationSectionState();
}

class _LocationSectionState extends ConsumerState<LocationSection> {
  @override
  void initState() {
    super.initState();
    // Tulis provider setelah frame pertama: Riverpod melarang perubahan
    // state provider saat widget tree masih dibangun.
    WidgetsBinding.instance.addPostFrameCallback((_) => _selaraskanPilihan());
  }

  /// Isi otomatis bila hanya ada satu lokasi aktif, dan buang pilihan yang
  /// sudah tidak ada di daftar. Idempoten: selama pilihan masih valid tidak
  /// ada penulisan provider, sehingga tidak mungkin berputar (loop).
  void _selaraskanPilihan() {
    if (!mounted) return;

    final aktif = ref.read(activeLocationsProvider);
    final terpilih = ref.read(selectedLocationProvider);
    final masihValid = terpilih != null &&
        aktif.any((lokasi) => lokasi.id == terpilih.id);
    if (masihValid) return;

    final berikutnya = aktif.length == 1 ? aktif.first : null;
    if (berikutnya?.id == terpilih?.id) return;
    ref.read(selectedLocationProvider.notifier).state = berikutnya;
  }

  Future<void> _pilihLokasi(List<BankLocationModel> aktif) async {
    final terpilih = await showModalBottomSheet<BankLocationModel>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.32),
      builder: (_) => _LocationSheet(
        lokasi: aktif,
        terpilihId: ref.read(selectedLocationProvider)?.id,
      ),
    );
    if (terpilih == null || !mounted) return;
    ref.read(selectedLocationProvider.notifier).state = terpilih;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(bankLocationsProvider);
    // Data baru (termasuk hasil "Coba Lagi") ikut diselaraskan.
    ref.listen<AsyncValue<List<BankLocationModel>>>(
      bankLocationsProvider,
      (_, next) {
        if (next.hasValue) Future.microtask(_selaraskanPilihan);
      },
    );

    final aktif = ref.watch(activeLocationsProvider);
    final terpilih = ref.watch(selectedLocationProvider);

    return SurfaceCard(
      radius: _panelRadius,
      tone: widget.tone,
      padding: EdgeInsets.zero,
      child: _buildIsi(state, aktif, terpilih),
    );
  }

  Widget _buildIsi(
    AsyncValue<List<BankLocationModel>> state,
    List<BankLocationModel> aktif,
    BankLocationModel? terpilih,
  ) {
    if (state.isLoading && !state.hasValue) {
      return Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Memuat lokasi bank sampah…',
                style: TextStyle(fontSize: 13, color: SibasColors.muted),
              ),
            ),
          ],
        ),
      );
    }

    if (state.hasError && !state.hasValue) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: _LocationError(
          onRetry: () => ref.invalidate(bankLocationsProvider),
        ),
      );
    }

    if (aktif.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: _LocationEmpty(),
      );
    }

    // Satu lokasi aktif: tampil sebagai baris terpilih tanpa pemilih.
    if (aktif.length == 1) {
      return _LocationRow(lokasi: aktif.first, tetap: true);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LocationRow(
          lokasi: terpilih,
          tetap: false,
          onTap: () => _pilihLokasi(aktif),
        ),
        if (terpilih == null)
          Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: 16,
                  color: SibasColors.status.badText,
                ),
                SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'Lokasi belum dipilih. Pilih lokasi untuk melanjutkan.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: SibasColors.status.badText,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Satu baris lokasi: nama + alamat. Tinggi isi 40 px ditambah padding
/// membuat target sentuh tetap di atas 44 px.
class _LocationRow extends StatelessWidget {
  final BankLocationModel? lokasi;
  final bool tetap;
  final VoidCallback? onTap;

  const _LocationRow({
    required this.lokasi,
    required this.tetap,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final kosong = lokasi == null;
    final alamat = lokasi?.address.trim() ?? '';
    final keterangan = alamat.isNotEmpty
        ? alamat
        : (tetap
            ? 'Satu-satunya lokasi aktif.'
            : 'Ketuk untuk melihat daftar lokasi.');

    final isi = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: SibasColors.mintWash,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.place_rounded,
              size: 20,
              color: kosong ? SibasColors.muted : SibasColors.leaf,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  lokasi?.name ?? 'Pilih lokasi bank sampah',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: kosong
                        ? SibasColors.muted
                        : SibasColors.text,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  keterangan,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: SibasColors.muted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (tetap)
            const _TerpilihBadge()
          else
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: SibasColors.muted,
            ),
        ],
      ),
    );

    if (onTap == null) return isi;

    return Semantics(
      button: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_panelRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(onTap: onTap, child: isi),
      ),
    );
  }
}

/// Penanda lokasi tunggal yang sudah terpilih otomatis.
class _TerpilihBadge extends StatelessWidget {
  const _TerpilihBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: SibasColors.leaf.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Titik penanda status (§2): jangan andalkan warna saja.
          SizedBox(
            width: 5,
            height: 5,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: SibasColors.leaf,
                shape: BoxShape.circle,
              ),
            ),
          ),
          SizedBox(width: 6),
          Text(
            'Terpilih',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.1,
              color: SibasColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Tidak ada lokasi aktif: pengajuan belum bisa dilakukan.
class _LocationEmpty extends StatelessWidget {
  const _LocationEmpty();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.location_off_rounded,
              size: 20,
              color: SibasColors.muted,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Belum ada lokasi bank sampah aktif.',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SibasColors.text,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Setoran dan penarikan belum bisa diajukan sampai admin '
                    'mengaktifkan lokasi.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: SibasColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        const SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: null,
            child: Text('Pilih Lokasi'),
          ),
        ),
      ],
    );
  }
}

/// Gagal memuat daftar lokasi; pengguna bisa mencoba lagi.
class _LocationError extends StatelessWidget {
  final VoidCallback onRetry;

  const _LocationError({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: SibasColors.status.badText,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Lokasi bank sampah gagal dimuat.',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: SibasColors.status.badText,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          'Periksa koneksi lalu coba lagi.',
          style: TextStyle(fontSize: 12, color: SibasColors.muted),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onRetry,
            style: TextButton.styleFrom(
              foregroundColor: SibasColors.leaf,
              minimumSize: const Size(0, 44),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
          ),
        ),
      ],
    );
  }
}

/// Sheet pilihan lokasi. Kaca hanya dipakai di lapisan mengambang ini.
class _LocationSheet extends StatelessWidget {
  final List<BankLocationModel> lokasi;
  final String? terpilihId;

  const _LocationSheet({required this.lokasi, this.terpilihId});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      heightFactor: 1,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: GlassPanel(
          tone: GlassTone.dense,
          radius: _sheetRadius,
          padding: EdgeInsets.zero,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const SizedBox(height: 10),
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: SibasColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 8, 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Pilih Lokasi Bank Sampah',
                          style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            height: 1.15,
                            color: SibasColors.text,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Tutup',
                        onPressed: () => Navigator.of(context).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: SibasColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                    itemCount: lokasi.length,
                    itemBuilder: (context, index) {
                      final item = lokasi[index];
                      return _LocationOption(
                        lokasi: item,
                        dipilih: item.id == terpilihId,
                        onTap: () => Navigator.of(context).pop(item),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Satu pilihan lokasi di dalam sheet; tinggi baris 60 px.
class _LocationOption extends StatelessWidget {
  final BankLocationModel lokasi;
  final bool dipilih;
  final VoidCallback onTap;

  const _LocationOption({
    required this.lokasi,
    required this.dipilih,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final alamat = lokasi.address.trim();

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Material(
        color: dipilih
            ? SibasColors.leaf.withValues(alpha: 0.10)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(_panelRadius),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: SibasColors.mintWash,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.place_rounded,
                    size: 18,
                    color: SibasColors.leaf,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        lokasi.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: SibasColors.text,
                        ),
                      ),
                      if (alamat.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          alamat,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.35,
                            color: SibasColors.muted,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (dipilih) ...[
                  const SizedBox(width: 8),
                  Icon(
                    Icons.check_circle_rounded,
                    size: 20,
                    color: SibasColors.leaf,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
