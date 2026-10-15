import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/colors.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/verification_provider.dart';

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
  final _weightController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isRejecting = false;
  bool _isLoading = false;

  final _currencyFormat = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  @override
  void initState() {
    super.initState();
    final initialWeight = (widget.transactionData['weight'] != null)
        ? (widget.transactionData['weight'] as num).toDouble()
        : 0.0;
    _weightController.text = initialWeight.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _weightController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _handleApprove() async {
    final verifiedWeight = double.tryParse(_weightController.text.replaceAll(',', '.'));
    if (verifiedWeight == null || verifiedWeight <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Berat aktual timbangan harus lebih dari 0 kg'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final admin = ref.read(currentUserProvider).valueOrNull;
    if (admin == null) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(verificationRepositoryProvider);
      final txId = widget.transactionData['id'] as String;

      await repo.approveTransaction(
        transactionId: txId,
        adminId: admin.id,
        verifiedWeightKg: verifiedWeight,
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onVerificationComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi BERHASIL disetujui & diverifikasi!'),
            backgroundColor: AppColors.primaryMain,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal verifikasi: ${e.toString()}'),
            backgroundColor: AppColors.danger,
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
        const SnackBar(
          content: Text('Alasan penolakan wajib diisi'),
          backgroundColor: AppColors.danger,
        ),
      );
      return;
    }

    final admin = ref.read(currentUserProvider).valueOrNull;
    if (admin == null) return;

    setState(() => _isLoading = true);
    try {
      final repo = ref.read(verificationRepositoryProvider);
      final txId = widget.transactionData['id'] as String;

      await repo.rejectTransaction(
        transactionId: txId,
        adminId: admin.id,
        reason: _reasonController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onVerificationComplete();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Transaksi telah ditolak.'),
            backgroundColor: AppColors.statusRejectedText,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menolak: ${e.toString()}'),
            backgroundColor: AppColors.danger,
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
    final category = widget.transactionData['waste_categories'] as Map<String, dynamic>?;

    final studentName = (profile?['full_name'] as String?) ?? 'Mahasiswa';
    final studentNim = (profile?['nim'] as String?) ?? '-';
    final categoryName = (category?['name'] as String?) ?? (widget.transactionData['category_name'] as String?) ?? 'Sampah Daur Ulang';
    final pricePerKg = (category?['price_per_kg'] != null) ? (category!['price_per_kg'] as num).toDouble() : 0.0;
    final txId = (widget.transactionData['id'] as String?) ?? '';

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
                  color: AppColors.borderLine,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Judul Modal
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Validasi Setoran Mahasiswa',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Identitas Mahasiswa
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.mintSoftBackground,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.mintAccent),
              ),
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primaryMain,
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
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: AppColors.primaryDark),
                        ),
                        Text(
                          'NIM: $studentNim • $categoryName',
                          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ID Transaksi
            Text(
              'ID Transaksi: $txId',
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11, color: AppColors.textMuted),
            ),
            const SizedBox(height: 16),

            if (!_isRejecting) ...[
              // Input Penimbangan Aktual (kg)
              const Text(
                'Berat Timbangan Aktual (kg)',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _weightController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  hintText: 'Contoh: 3.2',
                  prefixIcon: Icon(Icons.scale_rounded, color: AppColors.primaryMain),
                  suffixText: 'kg',
                ),
              ),
              const SizedBox(height: 8),
              if (pricePerKg > 0)
                Text(
                  'Tarif berlaku: ${_currencyFormat.format(pricePerKg)} / kg',
                  style: const TextStyle(fontSize: 12, color: AppColors.primaryMain, fontWeight: FontWeight.w600),
                ),
              const SizedBox(height: 24),

              // Tombol Setujui (RPC approve_transaction)
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _handleApprove,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.statusApprovedText,
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
                  child: const Text('Tolak Pengajuan Setoran', style: TextStyle(color: AppColors.danger, fontWeight: FontWeight.w700)),
                ),
              ),
            ] else ...[
              // Form Alasan Penolakan
              const Text(
                'Alasan Penolakan',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14, color: AppColors.danger),
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
                    backgroundColor: AppColors.danger,
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
