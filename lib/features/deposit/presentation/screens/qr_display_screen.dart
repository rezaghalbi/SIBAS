import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../../core/constants/colors.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/status_badge.dart';
import '../providers/deposit_provider.dart';

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

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Kode QR Transaksi'),
        backgroundColor: AppColors.primaryMain,
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
                                ? AppColors.statusRejectedBg
                                : AppColors.mintSoftBackground,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isExpired ? AppColors.danger : AppColors.mintAccent,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.timer_outlined,
                                size: 18,
                                color: isExpired ? AppColors.danger : AppColors.primaryDark,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Masa Berlaku: ${_formatDuration(_remainingTime)}',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: isExpired ? AppColors.danger : AppColors.primaryDark,
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
                                border: Border.all(color: AppColors.mintAccent, width: 2),
                              ),
                              child: QrImageView(
                                data: tx?.qrToken ?? widget.transactionId,
                                version: QrVersions.auto,
                                size: 220,
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.square,
                                  color: AppColors.primaryDark,
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.square,
                                  color: AppColors.primaryMain,
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
                                              ? AppColors.statusApprovedText
                                              : AppColors.statusRejectedText,
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
                                              ? AppColors.statusApprovedText
                                              : AppColors.statusRejectedText,
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
                          style: const TextStyle(
                            fontSize: 12,
                            fontFamily: 'monospace',
                            color: AppColors.textMuted,
                          ),
                        ),
                        const SizedBox(height: 12),
                        StatusBadge(status: status),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Detail Rincian Setoran
                  GlassPanel(
                    radius: 18,
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Informasi Penyetoran',
                          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.textPrimary),
                        ),
                        const Divider(height: 20, color: AppColors.borderLine),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Jenis Sampah', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            Text(tx?.categoryName ?? 'Sampah Daur Ulang', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Berat Pengajuan', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            Text('${tx?.weight.toStringAsFixed(1) ?? "0.0"} kg', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Estimasi Nilai', style: TextStyle(color: AppColors.textMuted, fontSize: 13)),
                            Text(
                              tx?.estimatedAmount != null ? _currencyFormat.format(tx!.estimatedAmount) : 'Rp 0',
                              style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.primaryMain),
                            ),
                          ],
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
