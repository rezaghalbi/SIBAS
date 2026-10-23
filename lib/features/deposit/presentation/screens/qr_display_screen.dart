import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../bank_location/domain/models/bank_location_model.dart';
import '../../../bank_location/presentation/providers/bank_location_provider.dart';
import '../providers/deposit_provider.dart';
import '../../../../core/theme/sibas_colors.dart';

class QrDisplayScreen extends ConsumerStatefulWidget {
  final String transactionId;

  const QrDisplayScreen({
    super.key,
    required this.transactionId,
  });

  @override
  ConsumerState<QrDisplayScreen> createState() => _QrDisplayScreenState();
}

class _QrDisplayScreenState extends ConsumerState<QrDisplayScreen> {
  Timer? _timer;
  DateTime? _expiresAt;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  /// Sisa waktu dihitung dari `qr_expires_at` server, bukan dari durasi lokal.
  Duration get _remainingTime {
    final expiresAt = _expiresAt;
    if (expiresAt == null) return Duration.zero;
    final diff = expiresAt.difference(DateTime.now());
    return diff.isNegative ? Duration.zero : diff;
  }

  void _ensureCountdown(DateTime? expiresAt) {
    if (expiresAt == null || _expiresAt != null) return;
    _expiresAt = expiresAt;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _remainingTime.inSeconds <= 0) {
        timer.cancel();
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds <= 0) return '00:00:00 (Kedaluwarsa)';
    final hours = d.inHours.toString().padLeft(2, '0');
    final minutes = (d.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    final txDetail = ref.watch(transactionDetailProvider(widget.transactionId));
    // Dipakai sebagai cadangan nama lokasi; nilainya cache dari pemilih lokasi
    // di layar setor, jadi tidak menambah beban berarti.
    final daftarLokasi =
        ref.watch(bankLocationsProvider).valueOrNull ??
            const <BankLocationModel>[];

    return Scaffold(
      backgroundColor: SibasColors.background,
      appBar: AppBar(
        title: const Text('Kode QR Transaksi'),
        backgroundColor: SibasColors.leaf,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.go('/dashboard'),
        ),
      ),
      body: SafeArea(
        child: txDetail.when(
          data: (tx) {
            _ensureCountdown(tx?.qrExpiresAt);
            final namaLokasi = _namaLokasi(
              tx?.locationName,
              tx?.locationId,
              daftarLokasi,
            );
            // Evaluasi status transaksi
            final status = tx?.status ?? 'PENDING';
            final isPending = status.toUpperCase() == 'PENDING';
            final isExpired = _remainingTime.inSeconds <= 0 || status.toUpperCase() == 'EXPIRED';
            final isApproved = status.toUpperCase() == 'APPROVED';
            final isRejected = status.toUpperCase() == 'REJECTED';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                children: [
                  // Card QR Utama
                  GlassPanel(
                    radius: 24,
                    padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 20),
                    child: Column(
                      children: [
                        // Countdown Timer Card
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(
                            color: isExpired
                                ? SibasColors.status.rejectedBackground
                                : SibasColors.mintWash,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isExpired ? SibasColors.status.badText : SibasColors.mint,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: isExpired ? SibasColors.status.badText : SibasColors.primary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Masa Berlaku: ${_formatDuration(_remainingTime)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isExpired ? SibasColors.status.badText : SibasColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Container QR dengan Watermark / Overlay jika status tidak aktif
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: SibasColors.mint, width: 2),
                              ),
                              child: QrImageView(
                                data: tx?.qrToken ?? widget.transactionId,
                                version: QrVersions.auto,
                                size: 220,
                                eyeStyle: QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: SibasColors.primary,
                                ),
                                dataModuleStyle: QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: SibasColors.leaf,
                                ),
                              ),
                            ),

                            // Watermark jika status APPROVED, REJECTED, atau EXPIRED
                            if (!isPending || isExpired)
                              Container(
                                width: 240,
                                height: 240,
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Transform.rotate(
                                    angle: -0.2,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: isApproved
                                              ? SibasColors.status.approvedText
                                              : SibasColors.status.rejectedText,
                                          width: 3,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        isApproved
                                            ? 'TERVERIFIKASI'
                                            : isRejected
                                                ? 'DITOLAK'
                                                : 'KEDALUWARSA',
                                        style: TextStyle(
                                          color: isApproved
                                              ? SibasColors.status.approvedText
                                              : SibasColors.status.rejectedText,
                                          fontSize: 20,
                                          fontWeight: FontWeight.w900,
                                          letterSpacing: 2,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 20),

                        // Kode transaksi (bukan UUID internal)
                        Text(
                          tx?.txCode ?? 'ID: ${widget.transactionId}',
                          style: TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: SibasColors.muted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StatusBadge(status: status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Detail Rincian Setoran
                  SurfaceCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Informasi Penyetoran',
                          style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                            color: SibasColors.text,
                          ),
                        ),
                        Divider(height: 20, color: SibasColors.border),
                        _InfoRow(
                          label: 'Jenis Sampah',
                          value: tx?.categoryName ?? 'Sampah Daur Ulang',
                        ),
                        _InfoRow(
                          label: 'Berat Pengajuan',
                          value: tx == null
                              ? '0.0 kg'
                              : '${tx.weight.toStringAsFixed(1)} kg',
                          numbers: true,
                        ),
                        _InfoRow(
                          label: 'Estimasi Nilai',
                          value: _currencyFormat.format(
                            tx?.estimatedAmount ?? 0,
                          ),
                          numbers: true,
                          emphasis: tx?.estimatedAmount != null,
                          isLast: namaLokasi == null,
                        ),
                        if (namaLokasi != null)
                          _InfoRow(
                            label: 'Lokasi',
                            value: namaLokasi,
                            isLast: true,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Tombol Kembali ke Beranda
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go('/dashboard'),
                      child: const Text('Kembali ke Dashboard'),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: Padding(padding: EdgeInsets.all(32.0), child: CircularProgressIndicator())),
          error: (err, _) => Center(child: Text('Gagal memuat detail transaksi: $err')),
        ),
      ),
    );
  }
}

/// Nama lokasi dari payload transaksi. `getTransactionById` hanya mengirim
/// `location_id`, jadi nama dicocokkan dengan daftar lokasi yang dimuat.
String? _namaLokasi(
  String? namaPayload,
  String? id,
  List<BankLocationModel> daftar,
) {
  final langsung = namaPayload?.trim();
  if (langsung != null && langsung.isNotEmpty) return langsung;
  if (id == null) return null;

  for (final lokasi in daftar) {
    if (lokasi.id != id) continue;
    final nama = lokasi.name.trim();
    if (nama.isNotEmpty) return nama;
  }
  return null;
}

/// Baris label–nilai kartu ringkasan. Nilai panjang dibungkus di kolom kanan
/// agar layar 360 px tidak meluber.
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool numbers;
  final bool emphasis;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.numbers = false,
    this.emphasis = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              color: SibasColors.muted,
              fontSize: 12.5,
              height: 1.4,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                fontWeight: FontWeight.w700,
                color: emphasis
                    ? SibasColors.leaf
                    : SibasColors.text,
                fontFeatures:
                    numbers ? const [FontFeature.tabularFigures()] : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
