import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../constants/colors.dart';
import '../utils/status_helper.dart';
import 'status_badge.dart';

/// Item baris transaksi dengan ikon jenis sampah, berat (kg), estimasi saldo, tanggal, dan StatusBadge
class TxListItem extends StatelessWidget {
  final String categoryName;
  final double weightKg;
  final double? amountRp;
  final String status;
  final DateTime createdAt;
  final VoidCallback? onTap;

  /// NIM mahasiswa; hanya tampil bila [showNim] true (dipakai layar admin)
  final String? nim;
  final bool showNim;

  /// Waktu verifikasi; bila tidak null tampil sebagai teks kecil
  final DateTime? verifiedAt;

  /// Aksi cepat "Tampilkan QR" di bawah baris; hanya dipakai layar riwayat.
  final bool canShowQr;
  final VoidCallback? onShowQr;

  const TxListItem({
    super.key,
    required this.categoryName,
    required this.weightKg,
    this.amountRp,
    required this.status,
    required this.createdAt,
    this.onTap,
    this.nim,
    this.showNim = false,
    this.verifiedAt,
    this.canShowQr = false,
    this.onShowQr,
  });

  /// Batas lebar kolom metrik kanan (badge + kg + nominal).
  ///
  /// Isi baris di layar 360 px: 360 - (2 x 16 gutter) - (2 x 16 padding
  /// kartu) - 48 ikon - 14 jarak = 234 px. Badge terpanjang ("Menunggu
  /// Verifikasi") +/- 147 px, jadi 172 px masih menampungnya utuh dan
  /// menyisakan +/- 62 px untuk kolom teks kiri.
  static const double _metricsMaxWidth = 172;

  IconData _getCategoryIcon(String category) {
    final lower = category.toLowerCase();
    if (lower.contains('plastik')) return Icons.local_drink_rounded;
    if (lower.contains('kertas') || lower.contains('karton')) return Icons.description_rounded;
    if (lower.contains('logam') || lower.contains('kaleng')) return Icons.hardware_rounded;
    if (lower.contains('kaca') || lower.contains('botol')) return Icons.wine_bar_rounded;
    if (lower.contains('elektronik')) return Icons.memory_rounded;
    return Icons.recycling_rounded;
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final showQrAction = canShowQr && onShowQr != null;

    // Berat dan nominal memakai angka tabular agar kolom kanan tidak
    // bergoyang saat nilai berubah.
    const nominal = <FontFeature>[FontFeature.tabularFigures()];
    const metricsConstraints = BoxConstraints(maxWidth: _metricsMaxWidth);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLine, width: 1.0),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    // Ikon Sampah dengan Lingkaran Mint
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: AppColors.mintSoftBackground,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(
                        _getCategoryIcon(categoryName),
                        color: AppColors.primaryMain,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),

                    // Kategori, NIM (opsional), Tanggal, Waktu verifikasi (opsional)
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            categoryName,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (showNim && nim != null && nim!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'NIM: $nim',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            dateFormat.format(createdAt),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.textMuted,
                            ),
                          ),
                          if (verifiedAt != null) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Diverifikasi ${dateFormat.format(verifiedAt!)}',
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),

                    // Metrik Berat, Saldo, dan Badge Status
                    ConstrainedBox(
                      constraints: metricsConstraints,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Label resmi dari TransactionStatusHelper
                          StatusBadge(
                            status: status,
                            customLabel:
                                TransactionStatusHelper.toDisplayLabel(status),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${weightKg.toStringAsFixed(1)} kg',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  fontFeatures: nominal,
                                ),
                              ),
                              if (amountRp != null && amountRp! > 0) ...[
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    '• ${currencyFormat.format(amountRp)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.primaryMain,
                                      fontFeatures: nominal,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (showQrAction)
              Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                  child: SizedBox(
                    height: 40,
                    child: OutlinedButton.icon(
                      onPressed: onShowQr,
                      icon: const Icon(Icons.qr_code_2_rounded, size: 18),
                      label: const Text('Tampilkan QR'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primaryMain,
                        minimumSize: const Size(0, 40),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        textStyle: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                        ),
                        side: BorderSide(
                          color: AppColors.primaryMain.withValues(alpha: 0.45),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
