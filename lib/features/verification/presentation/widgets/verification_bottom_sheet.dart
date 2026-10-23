import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../bank_location/presentation/providers/bank_location_provider.dart';
import '../../../history/presentation/providers/transaction_provider.dart';
import '../providers/verification_provider.dart';
import '../../core/theme/sibas_colors.dart';

/// Teks lokasi dari payload; string kosong dianggap tidak ada.
String? _teksLokasi(Object? nilai) {
  final teks = nilai?.toString().trim();
  return (teks == null || teks.isEmpty) ? null : teks;
}

/// Modal Bottom Sheet untuk memvalidasi transaksi via RPC Supabase
class VerificationBottomSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> transactionData;
  final VoidCallback onVerificationComplete;

  const VerificationBottomSheet({
    super.key,
    required this.transactionData,
    required this.onVerificationComplete,
  });

  static Future<void> show(
    BuildContext context, {
    required Map<String, dynamic> transactionData,
    required VoidCallback onVerificationComplete,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.0)),
      ),
      builder: (context) => VerificationBottomSheet(
        transactionData: transactionData,
        onVerificationComplete: onVerificationComplete,
      ),
    );
  }

  @override
  ConsumerState<VerificationBottomSheet> createState() => _VerificationBottomSheetState();
}

class _VerificationBottomSheetState extends ConsumerState<VerificationBottomSheet> {
  final _reasonController = TextEditingController();
  bool _isRejecting = false;
  bool _isLoading = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove() async {
    setState(() => _isLoading = true);
    try {
      final repo = ref.read(verificationRepositoryProvider);
      final txId = widget.transactionData['id'] as String;

      final status = await repo.approveTransaction(transactionId: txId);

      if (mounted) {
        // Metrik, daftar admin, dan data mahasiswa ikut disegarkan setelah approve.
        ref.invalidate(adminMetricsProvider);
        ref.invalidate(adminTransactionsProvider);
        ref.invalidate(currentUserProvider);
        // Detail transaksi yang mungkin masih terbuka ikut disegarkan.
        ref.invalidate(transactionDetailRpcProvider);
        Navigator.pop(context);
        widget.onVerificationComplete();
        final approved = status == 'APPROVED';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              approved
                  ? 'Transaksi BERHASIL disetujui & diverifikasi!'
                  : 'QR sudah kedaluwarsa. Status menjadi EXPIRED; minta '
                      'mahasiswa mengajukan ulang.',
            ),
            backgroundColor:
                approved ? SibasColors.leaf : SibasColors.status.badText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal memverifikasi. Periksa koneksi lalu coba lagi.'),
            backgroundColor: SibasColors.status.badText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReject() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Alasan penolakan wajib diisi'),
          backgroundColor: SibasColors.status.badText,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(verificationRepositoryProvider);
      final txId = widget.transactionData['id'] as String;

      final status = await repo.rejectTransaction(
        transactionId: txId,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        ref.invalidate(adminMetricsProvider);
        ref.invalidate(adminTransactionsProvider);
        ref.invalidate(transactionDetailRpcProvider);
        Navigator.pop(context);
        widget.onVerificationComplete();
        final rejected = status == 'REJECTED';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              rejected
                  ? 'Transaksi telah ditolak.'
                  : 'QR sudah kedaluwarsa. Status menjadi EXPIRED.',
            ),
            backgroundColor:
                rejected ? SibasColors.status.rejectedText : SibasColors.status.badText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menolak transaksi. Periksa koneksi lalu coba lagi.'),
            backgroundColor: SibasColors.status.badText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = widget.transactionData['profiles'] as Map<String, dynamic>?;
    final category = widget.transactionData['trash_types'] as Map<String, dynamic>?;

    final studentName = (profile?['full_name'] as String?) ?? 'Mahasiswa';
    final studentNim = (profile?['nim'] as String?) ?? '-';
    final categoryName = (category?['name'] as String?) ?? (widget.transactionData['category_name'] as String?) ?? 'Sampah Daur Ulang';
    final pricePerKg = (category?['price_per_kg'] != null) ? (category!['price_per_kg'] as num).toDouble() : 0.0;
    final submittedWeight = (widget.transactionData['weight'] as num?)?.toDouble() ?? 0.0;
    final txId = (widget.transactionData['id'] as String?) ?? '';

    // Lokasi: objek `location` dari RPC, atau `location_id` pada baris daftar.
    // Null berarti data lama / payload tanpa lokasi, baris tidak dirender.
    final lokasiPayload = widget.transactionData['location'];
    final lokasiMap = lokasiPayload is Map ? lokasiPayload : null;
    final lokasiId = _teksLokasi(widget.transactionData['location_id']);
    final daftarLokasi = ref.watch(bankLocationsProvider).valueOrNull;
    String? lokasiNama = _teksLokasi(lokasiMap?['name']);
    if (lokasiNama == null && lokasiId != null && daftarLokasi != null) {
      for (final lokasi in daftarLokasi) {
        if (lokasi.id != lokasiId) continue;
        lokasiNama = _teksLokasi(lokasi.name);
        break;
      }
    }

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 24,
        right: 24,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Drag Handle bar
            Center(
              child: Container(
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: SibasColors.border,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Judul Modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Validasi Setoran Mahasiswa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: SibasColors.text,
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: SibasColors.muted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Identitas Mahasiswa
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: SibasColors.mintWash,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: SibasColors.mint),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: SibasColors.leaf,
                    foregroundColor: Colors.white,
                    child: Icon(Icons.person_rounded, size: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          studentName,
                          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: SibasColors.primary),
                        ),
                        Text(
                          'NIM: $studentNim • $categoryName',
                          style: TextStyle(fontSize: 12, color: SibasColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Lokasi setoran hanya tampil bila payload memuatnya.
            if (lokasiNama != null) ...[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    Icons.place_outlined,
                    size: 18,
                    color: SibasColors.leaf,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Lokasi Setoran',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.3,
                            color: SibasColors.muted,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          lokasiNama,
                          style: TextStyle(
                            fontSize: 13.5,
                            height: 1.4,
                            fontWeight: FontWeight.w700,
                            color: SibasColors.text,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],

            // ID Transaksi
            Text(
              'ID Transaksi: $txId',
              style: TextStyle(fontFamily: 'monospace', fontSize: 11, color: SibasColors.muted),
            ),
            const SizedBox(height: 16),

            if (!_isRejecting) ...[
              // Berat pengajuan ditampilkan apa adanya; admin tidak menimpanya.
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: SibasColors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: SibasColors.border),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Berat Pengajuan',
                      style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: SibasColors.text),
                    ),
                    Text(
                      '${submittedWeight.toStringAsFixed(2)} kg',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: SibasColors.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              if (pricePerKg > 0)
                Text(
                  'Tarif berlaku: ${_currencyFormat.format(pricePerKg)} / kg',
                  style: TextStyle(fontSize: 12, color: SibasColors.leaf, fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 24),

              // Tombol Setujui (RPC approve_transaction)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SibasColors.status.approvedText,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.check_circle_outline_rounded, size: 22),
                  label: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Setujui & Tambah Saldo (RPC)', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 12),

              // Opsi Tolak
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => setState(() => _isRejecting = true),
                  child: Text('Tolak Pengajuan Setoran', style: TextStyle(color: SibasColors.status.badText, fontWeight: FontWeight.w700)),
                ),
              ),
            ] else ...[
              // Form Alasan Penolakan
              Text(
                'Alasan Penolakan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: SibasColors.status.badText),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _reasonController,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'Tuliskan alasan penolakan (misal: sampah tercampur cairan/kotor)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),

              // Tombol Konfirmasi Tolak (RPC reject_transaction)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleReject,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: SibasColors.status.badText,
                    foregroundColor: Colors.white,
                  ),
                  icon: const Icon(Icons.cancel_outlined, size: 22),
                  label: _isLoading
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text('Konfirmasi Penolakan (RPC)', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 10),

              Center(
                child: TextButton(
                  onPressed: () => setState(() => _isRejecting = false),
                  child: const Text('Kembali ke Menu Persetujuan'),
                ),
              ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
