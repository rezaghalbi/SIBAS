import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';
import '../providers/verification_provider.dart';
import '../widgets/verification_bottom_sheet.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

enum _ScanMode { setoran, penarikan }

/// Layar Pemindai QR Admin dengan integrasi kamera mobile_scanner, input kode QR
/// manual, dan fallback unggah file galeri. Mendukung dua mode: setoran dan
/// penarikan (persetujuan lewat token QR).
class AdminScanScreen extends ConsumerStatefulWidget {
  const AdminScanScreen({super.key});

  @override
  ConsumerState<AdminScanScreen> createState() => _AdminScanScreenState();
}

class _AdminScanScreenState extends ConsumerState<AdminScanScreen> {
  // mobile_scanner 5.x mendukung web (kamera peramban); controller dipakai semua platform.
  late final MobileScannerController _scannerController;
  final _uuidInputController = TextEditingController();
  final ImagePicker _imagePicker = ImagePicker();

  _ScanMode _mode = _ScanMode.setoran;
  bool _isProcessing = false;
  bool _torchEnabled = false;

  /// Token yang sudah disetujui; kamera tidak memproses ulang QR yang sama.
  String? _approvedToken;

  bool get _isWithdrawal => _mode == _ScanMode.penarikan;

  @override
  void initState() {
    super.initState();
    _scannerController = MobileScannerController();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _uuidInputController.dispose();
    super.dispose();
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.danger),
    );
  }

  /// Senter tidak tersedia di web dan tidak semua perangkat punya torch.
  Future<void> _toggleTorch() async {
    try {
      await _scannerController.toggleTorch();
      if (mounted) setState(() => _torchEnabled = !_torchEnabled);
    } catch (_) {
      // Jangan tampilkan exception mentah; cukup biarkan senter mati.
      if (mounted) setState(() => _torchEnabled = false);
    }
  }

  /// Panel ramah saat kamera gagal/inisialisasi atau izin ditolak.
  Widget _cameraErrorPanel() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: GlassPanel(
          tint: Colors.black,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 56,
                color: AppColors.mintAccent,
              ),
              const SizedBox(height: 14),
              const Text(
                'Izin kamera diperlukan',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Kamera tidak dapat diakses. Izinkan akses kamera di pengaturan '
                'peramban/perangkat, lalu muat ulang halaman. Sementara itu '
                'gunakan tombol ketik manual atau unggah gambar di bawah.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _processRawValue(String rawValue, {bool notify = true}) {
    if (_isWithdrawal) {
      _processWithdrawalQr(rawValue, notify: notify);
    } else {
      _processTransactionId(rawValue);
    }
  }

  Future<void> _processTransactionId(String txId) async {
    final cleanId = txId.trim();
    if (cleanId.isEmpty || _isProcessing) return;

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(verificationRepositoryProvider);
      final txData = await repo.getTransactionForVerification(cleanId);

      if (!mounted) return;

      if (txData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('ID Transaksi tidak ditemukan atau format QR tidak valid.'),
            backgroundColor: AppColors.danger,
          ),
        );
        setState(() => _isProcessing = false);
        return;
      }

      // Tampilkan Bottom Sheet Validasi
      await VerificationBottomSheet.show(
        context,
        transactionData: txData,
        onVerificationComplete: () {
          ref.invalidate(adminMetricsProvider);
          ref.invalidate(adminTransactionsProvider);
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Transaksi tidak dapat diproses. Periksa koneksi lalu coba lagi.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Mode penarikan: token QR (UUID 36 karakter) → data pengajuan → setujui.
  Future<void> _processWithdrawalQr(String rawValue, {bool notify = true}) async {
    final token = rawValue.trim();
    if (token.isEmpty || _isProcessing) return;

    if (token == _approvedToken) {
      // Kamera bisa terus melihat QR yang sama; jangan spam pesan.
      if (notify) _showError('QR penarikan ini sudah disetujui.');
      return;
    }
    if (token.length != 36) {
      _showError(
        'Token QR penarikan tidak valid. Pastikan QR berasal dari pengajuan '
        'penarikan mahasiswa.',
      );
      return;
    }

    setState(() => _isProcessing = true);
    try {
      final repo = ref.read(withdrawalRepositoryProvider);
      final data = await repo.getWithdrawalByQr(token);
      if (!mounted) return;

      final status = data['status']?.toString().trim().toUpperCase();
      if (status != null && status.isNotEmpty && status != 'PENDING') {
        _showError('Pengajuan ini tidak lagi menunggu persetujuan.');
        return;
      }

      final approved = await _WithdrawalConfirmSheet.show(
        context,
        data: data,
        token: token,
      );
      if (!mounted || approved != true) return;

      _approvedToken = token;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Penarikan disetujui.'),
          backgroundColor: AppColors.primaryMain,
        ),
      );
    } catch (error) {
      if (mounted) _showError(pesanKesalahan(error));
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Fallback Pemindaian QR menggunakan Unggah File Gambar (Aturan PRD)
  Future<void> _pickImageFallback() async {
    try {
      final XFile? image = await _imagePicker.pickImage(source: ImageSource.gallery);
      if (image == null) return;

      // Gambar tidak didekode otomatis di perangkat ini; jangan mengarang kode.
      // Admin mengetik token QR yang tampil di layar mahasiswa.
      _showManualInputDialog(
        catatan: _isWithdrawal
            ? 'Gambar tidak dapat dibaca otomatis. Masukkan token QR penarikan '
                'yang tertera pada layar mahasiswa.'
            : 'Gambar tidak dapat dibaca otomatis. Masukkan kode QR yang '
                'tertera pada layar mahasiswa.',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal membuka galeri. Periksa izin penyimpanan lalu coba lagi.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  void _showManualInputDialog({String? catatan}) {
    final isWithdrawal = _isWithdrawal;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isWithdrawal ? 'Input Token QR Penarikan' : 'Input Kode QR',
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              catatan ??
                  (isWithdrawal
                      ? 'Masukkan token QR penarikan (36 karakter) yang tampil '
                          'pada layar mahasiswa:'
                      : 'Masukkan kode QR (bukan UUID transaksi) yang tampil pada '
                          'layar mahasiswa:'),
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _uuidInputController,
              decoration: InputDecoration(
                hintText: isWithdrawal
                    ? 'Tempel token QR penarikan'
                    : 'Contoh: f7296dec17934e57a0dc79bb057da1ab',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal', style: TextStyle(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              _processRawValue(_uuidInputController.text);
            },
            child: Text(isWithdrawal ? 'Cari Penarikan' : 'Cari Transaksi'),
          ),
        ],
      ),
    );
  }

  Widget _modeSelector() {
    return Container(
      color: Colors.black,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
      child: SegmentedButton<_ScanMode>(
        // Bagi lebar penuh agar label "Penarikan" tidak terpotong di layar sempit.
        expandedInsets: EdgeInsets.zero,
        segments: const [
          ButtonSegment<_ScanMode>(
            value: _ScanMode.setoran,
            label: Text('Setoran'),
          ),
          ButtonSegment<_ScanMode>(
            value: _ScanMode.penarikan,
            label: Text('Penarikan'),
          ),
        ],
        selected: {_mode},
        showSelectedIcon: false,
        onSelectionChanged: _isProcessing
            ? null
            : (selection) => setState(() => _mode = selection.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.selected)
                ? AppColors.primaryMain
                : Colors.black.withValues(alpha: 0.6);
          }),
          foregroundColor: const WidgetStatePropertyAll<Color>(Colors.white),
          side: WidgetStatePropertyAll(
            BorderSide(color: Colors.white.withValues(alpha: 0.3)),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(
          _isWithdrawal ? 'Pindai QR Penarikan' : 'Pindai QR Setoran',
          // Tegaskan warna agar judul tidak ikut warna teks tema gelap/terang.
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
        actions: [
          // Senter tidak tersedia di web; tombol hanya untuk Android/iOS.
          if (!kIsWeb)
            IconButton(
              icon: Icon(_torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded),
              onPressed: _toggleTorch,
            ),
        ],
      ),
      body: Column(
        children: [
          _modeSelector(),
          Expanded(
            child: Stack(
              children: [
                // 1. Kamera Scanner View — mobile_scanner 5.x jalan di web (izin peramban).
                MobileScanner(
                  controller: _scannerController,
                  errorBuilder: (context, error, child) => _cameraErrorPanel(),
                  placeholderBuilder: (context, child) => const Center(
                    child: CircularProgressIndicator(color: AppColors.mintAccent),
                  ),
                  // Bingkai hanya tampil saat pratinjau kamera hidup, jadi
                  // panel izin kamera tidak tertutup garis bingkai.
                  overlayBuilder: (context, constraints) => Center(
                    child: Container(
                      width: 260,
                      height: 260,
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.accent, width: 3),
                        borderRadius: BorderRadius.circular(24),
                      ),
                    ),
                  ),
                  onDetect: (capture) {
                    final barcodes = capture.barcodes;
                    for (final barcode in barcodes) {
                      final rawValue = barcode.rawValue;
                      if (rawValue != null && !_isProcessing) {
                        _processRawValue(rawValue, notify: false);
                        break;
                      }
                    }
                  },
                ),

                // 2. Tombol Aksi Bawah (Manual Input & Upload Fallback)
                Positioned(
                  bottom: 30,
                  left: 20,
                  right: 20,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _isWithdrawal
                                  ? 'Arahkan kamera ke QR penarikan di layar mahasiswa, '
                                      'atau masukkan token/unggah gambar'
                                  : 'Arahkan kamera ke QR mahasiswa, atau masukkan '
                                      'kode/unggah gambar',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                            if (kIsWeb)
                              Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  'Peramban akan meminta izin kamera.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.7),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          // Tombol Unggah File Gambar (Fallback Kamera)
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _pickImageFallback,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.primaryDark,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.photo_library_outlined, size: 20),
                              label: const Text('Unggah Gambar', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // Tombol input kode QR manual
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showManualInputDialog(),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primaryMain,
                                foregroundColor: Colors.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                              ),
                              icon: const Icon(Icons.keyboard_outlined, size: 20),
                              label: Text(
                                _isWithdrawal ? 'Ketik Token QR' : 'Ketik Kode QR',
                                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                if (_isProcessing)
                  Container(
                    color: Colors.black.withValues(alpha: 0.6),
                    child: const Center(
                      child: CircularProgressIndicator(color: AppColors.mintAccent),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Konfirmasi admin sebelum menyetujui penarikan dari token QR.
class _WithdrawalConfirmSheet extends ConsumerStatefulWidget {
  final Map<String, dynamic> data;
  final String token;

  const _WithdrawalConfirmSheet({required this.data, required this.token});

  static Future<bool?> show(
    BuildContext context, {
    required Map<String, dynamic> data,
    required String token,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _WithdrawalConfirmSheet(data: data, token: token),
    );
  }

  @override
  ConsumerState<_WithdrawalConfirmSheet> createState() =>
      _WithdrawalConfirmSheetState();
}

class _WithdrawalConfirmSheetState
    extends ConsumerState<_WithdrawalConfirmSheet> {
  bool _busy = false;
  String? _error;

  double get _amount {
    final value = widget.data['amount'];
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? get _status {
    final text = widget.data['status']?.toString().trim();
    return (text == null || text.isEmpty) ? null : text.toUpperCase();
  }

  Future<void> _approve() async {
    setState(() {
      _busy = true;
      _error = null;
    });

    final ok = await ref
        .read(withdrawalControllerProvider.notifier)
        .approveByQr(widget.token);
    if (!mounted) return;

    if (!ok) {
      final failure = ref.read(withdrawalControllerProvider).error;
      setState(() {
        _busy = false;
        _error = failure == null
            ? 'Persetujuan gagal dikirim. Coba lagi.'
            : pesanKesalahan(failure);
      });
      return;
    }

    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final mahasiswa = widget.data['mahasiswa'];
    final student = mahasiswa is Map ? mahasiswa : null;
    final String name = student?['full_name']?.toString().trim() ?? '';
    final String nim = student?['nim']?.toString().trim() ?? '';

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
                  color: AppColors.borderLine,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Konfirmasi Penarikan',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Tutup',
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(
                    Icons.close_rounded,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
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
                          name.isEmpty ? 'Mahasiswa' : name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        Text(
                          'NIM ${nim.isEmpty ? '-' : nim}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Nominal Penarikan',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              _currency.format(_amount),
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            if (_status != null) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: StatusBadge(status: _status!),
              ),
              const SizedBox(height: 12),
            ],
            const Text(
              'Saldo mahasiswa berkurang setelah penarikan disetujui.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.statusRejectedBg,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.35),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline_rounded,
                      size: 18,
                      color: AppColors.danger,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.danger,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _busy ? null : _approve,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_circle_outline_rounded, size: 18),
                label: const Text('Setujui'),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 48,
              child: OutlinedButton(
                onPressed: _busy ? null : () => Navigator.of(context).pop(),
                child: const Text('Tutup'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
