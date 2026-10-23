import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/theme/app_palette.dart';
import '../../../../core/widgets/status_badge.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// Membuka QR penarikan agar bisa dipindai admin.
/// Token mentah tidak pernah ditampilkan sebagai teks.
Future<void> showWithdrawQrSheet(
  BuildContext context, {
  required String token,
  required double amount,
  String? status,
}) {

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _WithdrawQrSheet(
      token: token,
      amount: amount,
      status: status,
    ),
  );
}

class _WithdrawQrSheet extends StatelessWidget {
  final String token;
  final double amount;
  final String? status;

  const _WithdrawQrSheet({
    required this.token,
    required this.amount,
    this.status,
  });

  /// Status kosong dianggap belum diproses, sama seperti PENDING.
  bool get _processed =>
      (status ?? 'PENDING').trim().toUpperCase() != 'PENDING';

  @override
  Widget build(BuildContext context) {
    final p = AppPalette.of(context);


    final labelStatus = (status ?? 'PENDING').trim().toUpperCase();

    return Padding(
      padding: EdgeInsets.fromLTRB(
        24,
        16,
        24,
        MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: p.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    'QR Penarikan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: p.text,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(
                    Icons.close_rounded,
                    color: p.muted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Nominal Penarikan',
              style: TextStyle(fontSize: 12, color: p.muted),
            ),
            const SizedBox(height: 4),
            Text(
              _currency.format(amount),
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: p.text,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 20),
            if (_processed) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: p.mintWash,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.border),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 28,
                      color: p.primary,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Pengajuan ini sudah diproses.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: p.text,
                      ),
                    ),
                    const SizedBox(height: 10),
                    StatusBadge(status: labelStatus),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: Container(
                  decoration: BoxDecoration(
                    // QR wajib tetap di atas putih agar kontras pindai.
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.mint, width: 2),
                  ),
                  child: QrImageView(
                    data: token,
                    version: QrVersions.auto,
                    size: 220,
                    backgroundColor: Colors.white,
                    padding: const EdgeInsets.all(12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Tunjukkan QR ini ke admin untuk mencairkan dana.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: p.muted),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
