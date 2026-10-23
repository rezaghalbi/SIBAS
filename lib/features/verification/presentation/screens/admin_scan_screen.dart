import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../withdrawal/presentation/providers/withdrawal_provider.dart';
import '../providers/verification_provider.dart';
import '../widgets/verification_bottom_sheet.dart';
import '../../../../core/theme/sibas_colors.dart';

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// Lebar maksimum kendali pemindai di layar lebar (§8).
const double _chromeMaxWidth = 560;

/// Panel izin kamera tidak perlu selebar layar desktop.
const double _panelMaxWidth = 380;

/// Ruang bawah agar nav mengambang tidak menutup tombol (§4).
const double _bottomReserve = 96;

/// Lebar maksimum isi sheet konfirmasi penarikan.
const double _sheetMaxWidth = 560;

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

  IconData get _torchIcon =>
      _torchEnabled ? Icons.flash_on_rounded : Icons.flash_off_rounded;

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
      SnackBar(content: Text(message), backgroundColor: SibasColors.status.badText),
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
  ///
  /// Satu-satunya kaca di layar ini; `tint: Colors.black` menahan kontras
  /// teks putih di atas pratinjau kamera (§7.2).
  Widget _cameraErrorPanel() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _panelMaxWidth),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: GlassPanel(
            tint: Colors.black,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.18),
                    ),
                  ),
                  child: Icon(
                    Icons.no_photography_outlined,
                    size: 26,
                    color: SibasColors.mint,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Izin kamera diperlukan',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Izinkan akses kamera di pengaturan peramban atau '
                  'perangkat, lalu muat ulang halaman.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12.5,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Sementara itu, gunakan tombol ketik atau unggah gambar '
                  'di bawah.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12,
                    height: 1.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
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
          SnackBar(
            content: Text(
                'ID Transaksi tidak ditemukan atau format QR tidak valid.'),
            backgroundColor: SibasColors.status.badText,
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
            content: Text(
                'Transaksi tidak dapat diproses. Periksa koneksi lalu coba lagi.'),
            backgroundColor: SibasColors.status.badText,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  /// Mode penarikan: token QR (UUID 36 karakter) → data pengajuan → setujui.
  Future<void> _processWithdrawalQr(String rawValue,
      {bool notify = true}) async {
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
        SnackBar(
          content: Text('Penarikan disetujui.'),
          backgroundColor: SibasColors.leaf,
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
      final XFile? image =
          await _imagePicker.pickImage(source: ImageSource.gallery);
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
            content: Text(
                'Gagal membuka galeri. Periksa izin penyimpanan lalu coba lagi.'),
            backgroundColor: SibasColors.status.badText,
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
        backgroundColor: SibasColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
        contentPadding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
        actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 20),
        title: Text(
          isWithdrawal ? 'Input Token QR Penarikan' : 'Input Kode QR',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
            color: SibasColors.text,
          ),
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
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: SibasColors.muted,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _uuidInputController,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.2,
                color: SibasColors.text,
              ),
              decoration: InputDecoration(
                hintText: isWithdrawal
                    ? 'Tempel token QR penarikan'
                    : 'Contoh: f7296dec17934e57a0dc79bb057da1ab',
                hintStyle: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w400,
                  color: SibasColors.muted,
                ),
                filled: true,
                fillColor: SibasColors.mintWash,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: SibasColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(color: SibasColors.border),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: SibasColors.leaf,
                    width: 1.4,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          SizedBox(
            height: 44,
            child: TextButton(
              onPressed: () => Navigator.pop(ctx),
              style: TextButton.styleFrom(
                foregroundColor: SibasColors.muted,
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: const Text('Batal'),
            ),
          ),
          SizedBox(
            height: 44,
            child: FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _processRawValue(_uuidInputController.text);
              },
              style: FilledButton.styleFrom(
                backgroundColor: SibasColors.leaf,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              child: Text(isWithdrawal ? 'Cari Penarikan' : 'Cari Transaksi'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _modeSelector(double gutter) {
    return Container(
      color: Colors.black,
      padding: EdgeInsets.fromLTRB(gutter, 8, gutter, 12),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: _chromeMaxWidth),
          child: SegmentedButton<_ScanMode>(
            // Lebar penuh agar label "Penarikan" tidak terpotong di layar kecil
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
              minimumSize: const WidgetStatePropertyAll<Size>(Size(0, 44)),
              textStyle: const WidgetStatePropertyAll<TextStyle>(
                TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.1,
                ),
              ),
              backgroundColor: WidgetStateProperty.resolveWith((states) {
                return states.contains(WidgetState.selected)
                    ? SibasColors.leaf
                    : Colors.black.withValues(alpha: 0.6);
              }),
              foregroundColor: const WidgetStatePropertyAll(Colors.white),
              side: WidgetStatePropertyAll(
                BorderSide(color: Colors.white.withValues(alpha: 0.3)),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottomActions() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HintCard(isWithdrawal: _isWithdrawal),
        const SizedBox(height: 12),
        Row(
          children: [
            // Tombol Unggah File Gambar (Fallback Kamera)
            Expanded(
              child: _ActionButton(
                icon: Icons.photo_library_outlined,
                label: 'Unggah Gambar',
                background: Colors.white,
                foreground: SibasColors.primary,
                onPressed: _isProcessing ? null : _pickImageFallback,
              ),
            ),
            const SizedBox(width: 12),
            // Tombol input kode QR manual
            Expanded(
              child: _ActionButton(
                icon: Icons.keyboard_outlined,
                label: _isWithdrawal ? 'Ketik Token QR' : 'Ketik Kode QR',
                background: SibasColors.leaf,
                foreground: Colors.white,
                onPressed:
                    _isProcessing ? null : () => _showManualInputDialog(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final gutter = ContentWidth.gutterFor(MediaQuery.sizeOf(context).width);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleSpacing: gutter,
        title: Text(
          _isWithdrawal ? 'Pindai QR Penarikan' : 'Pindai QR Setoran',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          // Tegaskan warna agar judul tidak ikut warna teks tema gelap/terang.
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        actions: [
          // Senter tidak tersedia di web; tombol hanya untuk Android/iOS.
          if (!kIsWeb)
            IconButton(
              tooltip: _torchEnabled ? 'Matikan senter' : 'Nyalakan senter',
              icon: Icon(_torchIcon),
              onPressed: _toggleTorch,
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          _modeSelector(gutter),
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                // 1. Kamera Scanner View — mobile_scanner 5.x jalan di web (izin peramban).
                MobileScanner(
                  controller: _scannerController,
                  errorBuilder: (context, error, child) => _cameraErrorPanel(),
                  placeholderBuilder: (context, child) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 26,
                          height: 26,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.4,
                            color: SibasColors.mint,
                          ),
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Menyiapkan kamera…',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bingkai hanya tampil saat pratinjau kamera hidup, jadi
                  // panel izin kamera tidak tertutup garis bingkai.
                  overlayBuilder: (context, constraints) =>
                      _ScanFrame(constraints: constraints),
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

                // 2. Fade gelap di bawah supaya teks kontrol tetap terbaca.
                IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          Colors.black.withValues(alpha: 0.78),
                        ],
                        stops: const [0.42, 1],
                      ),
                    ),
                  ),
                ),

                // 3. Tombol Aksi Bawah (Manual Input & Upload Fallback)
                Positioned.fill(
                  child: SafeArea(
                    top: false,
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(
                        gutter,
                        12,
                        gutter,
                        _bottomReserve,
                      ),
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: _chromeMaxWidth,
                          ),
                          // Layar pendek (mis. lanskap): kontrol digulir,
                          // bukan meluber keluar area kamera.
                          child: SingleChildScrollView(
                            // Berlabuh di bawah: tombol utama selalu terlihat.
                            reverse: true,
                            child: _bottomActions(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                if (_isProcessing) const _ProcessingOverlay(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bingkai bidik: sisi mengikuti tinggi pratinjau agar tidak menabrak tombol.
class _ScanFrame extends StatelessWidget {
  final BoxConstraints constraints;

  const _ScanFrame({required this.constraints});

  @override
  Widget build(BuildContext context) {
    final side = (constraints.maxHeight * 0.34).clamp(160.0, 260.0).toDouble();

    return Padding(
      padding: const EdgeInsets.only(bottom: _bottomReserve + 24),
      child: Center(
        child: Container(
          width: side,
          height: side,
          decoration: BoxDecoration(
            border: Border.all(color: SibasColors.lime, width: 3),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Petunjuk singkat di atas tombol aksi.
class _HintCard extends StatelessWidget {
  final bool isWithdrawal;

  const _HintCard({required this.isWithdrawal});

  @override
  Widget build(BuildContext context) {
    return SurfaceCard(
      // Panel pratinjau kamera: tetap gelap agar teks putih terbaca.
      tone: SurfaceTone.subtle,
      radius: 16,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: Colors.black.withValues(alpha: 0.72),
      child: Column(
        children: [
          Text(
            isWithdrawal
                ? 'Arahkan kamera ke QR penarikan di layar mahasiswa, '
                    'atau masukkan token/unggah gambar'
                : 'Arahkan kamera ke QR mahasiswa, atau masukkan '
                    'kode/unggah gambar',
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12.5,
              height: 1.45,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 4),
            Text(
              'Peramban akan meminta izin kamera.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.86),
                fontSize: 11.5,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Tombol aksi kamera: tinggi 48 px, label satu baris.
class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 48,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: background,
          foregroundColor: foreground,
          disabledBackgroundColor: background.withValues(alpha: 0.45),
          disabledForegroundColor: foreground.withValues(alpha: 0.7),
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w700,
          ),
        ),
        icon: Icon(icon, size: 18),
        label: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}

/// Penanda proses: scrim + satu kalimat, tanpa kaca tambahan.
class _ProcessingOverlay extends StatelessWidget {
  const _ProcessingOverlay();

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black.withValues(alpha: 0.62),
      child: Center(
        child: SurfaceCard(
          tone: SurfaceTone.subtle,
          radius: 16,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          color: Colors.black.withValues(alpha: 0.72),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: SibasColors.mint,
                ),
              ),
              SizedBox(width: 12),
              Text(
                'Memproses data QR…',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
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
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _sheetMaxWidth),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: SibasColors.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Konfirmasi Penarikan',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                          color: SibasColors.text,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Tutup',
                      onPressed:
                          _busy ? null : () => Navigator.of(context).pop(),
                      icon: Icon(
                        Icons.close_rounded,
                        color: SibasColors.muted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                SurfaceCard(
                  tone: SurfaceTone.subtle,
                  radius: 16,
                  padding: const EdgeInsets.all(16),
                  color: SibasColors.mintWash,
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SibasColors.leaf,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.person_rounded,
                          size: 22,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name.isEmpty ? 'Mahasiswa' : name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                                height: 1.3,
                                color: SibasColors.text,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'NIM ${nim.isEmpty ? '-' : nim}',
                              style: TextStyle(
                                fontSize: 12.5,
                                height: 1.4,
                                color: SibasColors.muted,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nominal Penarikan',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                    color: SibasColors.muted,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _currency.format(_amount),
                  style: TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.8,
                    height: 1.1,
                    color: SibasColors.text,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: StatusBadge(status: _status!),
                  ),
                ],
                const SizedBox(height: 12),
                Text(
                  'Saldo mahasiswa berkurang setelah penarikan disetujui.',
                  style: TextStyle(
                    fontSize: 12.5,
                    height: 1.5,
                    color: SibasColors.muted,
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  SurfaceCard(
                    tone: SurfaceTone.subtle,
                    radius: 16,
                    padding: const EdgeInsets.all(12),
                    color: SibasColors.status.rejectedBackground,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons.error_outline_rounded,
                          size: 18,
                          color: SibasColors.status.badText,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                              color: SibasColors.status.badText,
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
                        : const Icon(
                            Icons.check_circle_outline_rounded,
                            size: 18,
                          ),
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
        ),
      ),
    );
  }
}
