import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/utils/status_helper.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../providers/transaction_provider.dart';
import '../../core/theme/sibas_colors.dart';

/// Lebar kolom baca detail di desktop (§8).
const double _contentMaxWidth = 720;

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

final _dateTime = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

/// Angka uang, berat, dan waktu rata kolom (§3).
const List<FontFeature> _tabularFigures = [FontFeature.tabularFigures()];

/// Judul seksi Glass 2.0 (§3): 15.5 px, w700, tracking rapat.
TextStyle _sectionTitle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  color: SibasColors.text,
);

/// Rincian satu transaksi setoran: nominal, status, waktu, dan verifikator.
class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = transactionDetailRpcProvider(transactionId);
    final detailState = ref.watch(provider);
    final row = detailState.valueOrNull;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: SibasColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            // HeroHeader sudah memakai gutter sendiri, jadi cukup dibatasi
            // tanpa padding tambahan agar tepinya sejajar dengan isi di bawah.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _contentMaxWidth),
                child: HeroHeader(
                  title: 'Detail Transaksi',
                  subtitle: _text(row?['tx_code']) ?? 'Rincian setoran sampah',
                  trailing: const _BackButton(),
                  bottomContent: row == null ? null : _SummaryPanel(row: row),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.only(bottom: bottomInset),
              child: ContentWidth(
                maxWidth: _contentMaxWidth,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(0, 20, 0, 24),
                  child: detailState.when(
                    loading: () => const _LoadingPanel(),
                    error: (_, __) => _StatePanel(
                      icon: Icons.cloud_off_rounded,
                      title: 'Detail transaksi gagal dimuat',
                      message: 'Periksa koneksi Anda, lalu coba muat ulang.',
                      danger: true,
                      action: _StateAction(
                        label: 'Coba Lagi',
                        icon: Icons.refresh_rounded,
                        onPressed: () => ref.invalidate(provider),
                      ),
                    ),
                    data: (data) => data == null
                        ? _StatePanel(
                            icon: Icons.search_off_rounded,
                            title: 'Transaksi tidak ditemukan',
                            message: 'Data setoran ini tidak tersedia atau '
                                'sudah dihapus.',
                            action: _StateAction(
                              label: 'Kembali',
                              icon: Icons.arrow_back_rounded,
                              onPressed: () => _goBack(context),
                            ),
                          )
                        : _DetailBody(
                            row: data,
                            transactionId: transactionId,
                          ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kembali ke layar sebelumnya; `/history` jadi jaring pengaman deep link.
void _goBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/history');
  }
}

/// Angka/nominal dari database bisa int, double, atau null.
double? _num(dynamic value) => value is num ? value.toDouble() : null;

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

/// Bukti foto hanya dirender bila payload membawa URL yang aman.
Uri? _photoUri(Map<String, dynamic> row) {
  for (final key in const ['photo_url', 'proof_url', 'foto_url']) {
    final raw = _text(row[key]);
    if (raw == null) continue;
    final uri = Uri.tryParse(raw);
    if (uri == null) continue;
    if (uri.scheme == 'http' || uri.scheme == 'https') return uri;
  }
  return null;
}

/// Inisial pengaju untuk blok identitas: maksimal dua huruf.
String _initials(String name) {
  final words = name.trim().split(RegExp(r'\s+'));
  final buffer = StringBuffer();
  for (final word in words) {
    if (word.isEmpty) continue;
    buffer.write(word[0].toUpperCase());
    if (buffer.length == 2) break;
  }
  return buffer.isEmpty ? '?' : buffer.toString();
}

/// Ringkasan di dalam hero: nominal besar, lalu status tepat di bawahnya.
class _SummaryPanel extends StatelessWidget {
  final Map<String, dynamic> row;

  const _SummaryPanel({required this.row});

  @override
  Widget build(BuildContext context) {
    final status = _text(row['status']) ?? 'PENDING';
    final finalAmount = _num(row['final_amount']);
    final amount = finalAmount ?? _num(row['estimated_amount']) ?? 0;

    return SizedBox(
      width: double.infinity,
      child: GlassPanel(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              finalAmount == null ? 'Estimasi Nilai' : 'Nominal Final',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.9),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.3,
              ),
            ),
            const SizedBox(height: 8),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                _currency.format(amount),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.05,
                  fontFeatures: _tabularFigures,
                ),
              ),
            ),
            const SizedBox(height: 12),
            StatusBadge(
              status: status,
              customLabel: TransactionStatusHelper.toDisplayLabel(status),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Map<String, dynamic> row;
  final String transactionId;

  const _DetailBody({required this.row, required this.transactionId});

  @override
  Widget build(BuildContext context) {
    final categoryName = _text(row['trash_name']) ?? 'Sampah Daur Ulang';

    final weight = _num(row['weight']) ?? 0;
    final ratePerKg = _num(row['price_per_kg_snapshot']);
    final estimated = _num(row['estimated_amount']);
    final finalAmount = _num(row['final_amount']);
    final status = _text(row['status']) ?? 'PENDING';
    final normalized = status.toUpperCase();

    final createdAt = _date(row['created_at']);
    final verifiedAt = _date(row['verified_at']);
    final verifier = row['verifikator'];
    final verifierName = verifier is Map ? _text(verifier['full_name']) : null;
    final mahasiswa = row['mahasiswa'];
    final studentName = mahasiswa is Map ? _text(mahasiswa['full_name']) : null;
    final studentNim = mahasiswa is Map ? _text(mahasiswa['nim']) : null;
    // Objek `location` berasal dari RPC `detail_transaksi`; data lama bisa
    // null sehingga baris lokasi tidak dirender sama sekali.
    final lokasi = row['location'];
    final lokasiMap = lokasi is Map ? lokasi : null;
    final lokasiNama = _text(lokasiMap?['name']);
    final lokasiAlamat = _text(lokasiMap?['address']);
    final rejectionReason = _text(row['rejection_reason']);
    final audits = row['audits'];
    // QR hanya relevan selama menunggu verifikasi; kedaluwarsa tetap boleh
    // dibuka karena QrDisplayScreen memberi watermark.
    final qrToken = _text(row['qr_token']);
    final canShowQr = normalized == 'PENDING' && qrToken != null;
    final txCode = _text(row['tx_code']);
    final photo = _photoUri(row);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (canShowQr) ...[
          SizedBox(
            width: double.infinity,
            height: 44,
            child: OutlinedButton.icon(
              onPressed: () => context.push('/qr/$transactionId'),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('Tampilkan QR Setoran'),
              style: OutlinedButton.styleFrom(
                foregroundColor: SibasColors.primary,
                side: BorderSide(color: SibasColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        _Section(
          title: 'Pengaju',
          child: _StudentBlock(name: studentName, nim: studentNim),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Rincian Setoran',
          child: Column(
            children: [
              _InfoRow(label: 'Jenis Sampah', value: categoryName),
              _InfoRow(
                label: 'Berat',
                value: '${weight.toStringAsFixed(1)} kg',
                numbers: true,
              ),
              _InfoRow(
                label: 'Tarif per kg',
                value: (ratePerKg == null || ratePerKg <= 0)
                    ? 'Belum ada tarif'
                    : '${_currency.format(ratePerKg)} / kg',
                numbers: true,
                muted: ratePerKg == null || ratePerKg <= 0,
              ),
              _InfoRow(
                label: 'Estimasi Nilai',
                value: estimated == null ? '-' : _currency.format(estimated),
                numbers: true,
                muted: estimated == null,
              ),
              _InfoRow(
                label: 'Nominal Final',
                value: finalAmount == null
                    ? 'Belum ditetapkan'
                    : _currency.format(finalAmount),
                numbers: true,
                emphasis: finalAmount != null,
                muted: finalAmount == null,
                isLast: lokasiNama == null,
              ),
              if (lokasiNama != null)
                _InfoRow(
                  label: 'Lokasi',
                  value: lokasiNama,
                  secondary: lokasiAlamat,
                  isLast: true,
                ),
            ],
          ),
        ),
        if (photo != null) ...[
          const SizedBox(height: 16),
          _PhotoSection(uri: photo),
        ],
        const SizedBox(height: 16),
        _Section(
          title: 'Waktu & Petugas',
          child: Column(
            children: [
              _InfoRow(
                label: 'Kode Transaksi',
                value: txCode ?? '-',
                mono: true,
                muted: txCode == null,
              ),
              _InfoRow(
                label: 'Waktu Pengajuan',
                value: createdAt == null ? '-' : _dateTime.format(createdAt),
                numbers: true,
              ),
              _InfoRow(
                label: 'Waktu Verifikasi',
                value: verifiedAt == null
                    ? 'Belum diproses'
                    : _dateTime.format(verifiedAt),
                numbers: verifiedAt != null,
                muted: verifiedAt == null,
              ),
              _InfoRow(
                label: 'Diproses Oleh',
                value: verifierName ?? 'Belum diproses',
                muted: verifierName == null,
                isLast: true,
              ),
            ],
          ),
        ),
        if (rejectionReason != null) ...[
          const SizedBox(height: 16),
          _NoteBox(
            icon: Icons.error_outline_rounded,
            title: 'Alasan Penolakan',
            text: rejectionReason,
          ),
        ],
        if (normalized == 'EXPIRED') ...[
          const SizedBox(height: 16),
          const _NoteBox(
            icon: Icons.timer_off_rounded,
            title: 'Kode QR Kedaluwarsa',
            text: 'Batas waktu verifikasi sudah lewat sehingga kode QR tidak '
                'bisa dipindai admin. Silakan ajukan setoran baru.',
          ),
        ],
        if (audits is List) ...[
          const SizedBox(height: 16),
          _AuditTimeline(audits: audits),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 44,
          child: OutlinedButton(
            onPressed: () => _goBack(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: SibasColors.primary,
              side: BorderSide(color: SibasColors.border),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              textStyle: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
              ),
            ),
            child: const Text('Kembali'),
          ),
        ),
      ],
    );
  }
}

/// Kartu seksi: judul 15.5 w700, radius 20, border tipis (§4, §5).
class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: _sectionTitle),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// Blok identitas pengaju: inisial, nama, dan NIM.
class _StudentBlock extends StatelessWidget {
  final String? name;
  final String? nim;

  const _StudentBlock({this.name, this.nim});

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? 'Tidak diketahui';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: SibasColors.mintWash,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: SibasColors.border),
          ),
          child: Text(
            _initials(displayName),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: SibasColors.primary,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: name == null
                      ? SibasColors.muted
                      : SibasColors.text,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                nim == null ? 'NIM belum terisi' : 'NIM $nim',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: SibasColors.muted,
                  fontFeatures: _tabularFigures,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Baris label–nilai; angka uang dan berat memakai tabular figures (§3).
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  /// Baris kedua yang lebih redup, mis. alamat di bawah nama lokasi.
  final String? secondary;
  final bool numbers;
  final bool mono;
  final bool muted;
  final bool emphasis;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.secondary,
    this.numbers = false,
    this.mono = false,
    this.muted = false,
    this.emphasis = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    Color valueColor = SibasColors.text;
    if (muted) {
      valueColor = SibasColors.muted;
    } else if (emphasis) {
      valueColor = SibasColors.primary;
    }

    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 124,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: SibasColors.muted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  value,
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontFamily: mono ? 'monospace' : null,
                    letterSpacing: mono ? 0.2 : 0,
                    fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
                    color: valueColor,
                    fontFeatures: numbers ? _tabularFigures : null,
                  ),
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary!,
                    textAlign: TextAlign.right,
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: SibasColors.muted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Bukti foto setoran bila payload menyertakan URL yang valid.
class _PhotoSection extends StatelessWidget {
  final Uri uri;

  const _PhotoSection({required this.uri});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Bukti Foto',
      child: SurfaceCard(
        tone: SurfaceTone.subtle,
        radius: 16,
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Image.network(
            uri.toString(),
            fit: BoxFit.cover,
            semanticLabel: 'Bukti foto setoran',
            errorBuilder: (context, error, stackTrace) => Container(
              color: SibasColors.mintWash,
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.broken_image_outlined,
                    size: 28,
                    color: SibasColors.muted,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Foto tidak dapat dimuat',
                    style: TextStyle(
                      fontSize: 12.5,
                      color: SibasColors.muted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Riwayat perubahan status transaksi (audit) dalam urutan kronologis.
class _AuditTimeline extends StatelessWidget {
  final List<dynamic> audits;

  const _AuditTimeline({required this.audits});

  static String _statusLabel(dynamic status) {
    switch (status?.toString().toUpperCase()) {
      case 'APPROVED':
        return 'Disetujui';
      case 'REJECTED':
        return 'Ditolak';
      case 'EXPIRED':
        return 'Kedaluwarsa';
      case 'PENDING':
      default:
        return 'Menunggu';
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = audits.whereType<Map>().toList()
      ..sort((a, b) {
        final left = _date(a['created_at']);
        final right = _date(b['created_at']);
        if (left == null || right == null) return 0;
        return left.compareTo(right);
      });

    return _Section(
      title: 'Riwayat Proses',
      child: entries.isEmpty
          ? Text(
              'Belum ada riwayat proses.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: SibasColors.muted,
              ),
            )
          : SurfaceCard(
              tone: SurfaceTone.subtle,
              radius: 16,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (var i = 0; i < entries.length; i++)
                    _AuditRow(
                      entry: entries[i],
                      isLast: i == entries.length - 1,
                    ),
                ],
              ),
            ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  final Map entry;
  final bool isLast;

  const _AuditRow({
    required this.entry,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final toStatus = entry['to_status']?.toString();
    final color = TransactionStatusHelper.getStatusColor(toStatus);
    final note = _text(entry['note']);
    final actor = _text(entry['actor_name']);
    final at = _date(entry['created_at']);
    final meta = [
      actor ?? 'Sistem',
      if (at != null) _dateTime.format(at),
    ].join(' • ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Column(
            children: [
              Container(
                width: 10,
                height: 10,
                margin: const EdgeInsets.only(top: 4),
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 3),
                    color: SibasColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _AuditTimeline._statusLabel(toStatus),
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.1,
                      color: color,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      note,
                      style: TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: SibasColors.text,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: SibasColors.muted,
                      fontFeatures: _tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NoteBox extends StatelessWidget {
  final IconData icon;
  final String title;
  final String text;

  const _NoteBox({
    required this.icon,
    required this.title,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SurfaceCard(
        tone: SurfaceTone.subtle,
        radius: 16,
        padding: const EdgeInsets.all(16),
        color: SibasColors.status.rejectedBackground,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: SibasColors.status.badText),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: SibasColors.status.badText,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: SibasColors.status.badText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Keadaan memuat: spinner kecil, judul, dan satu kalimat penjelas.
class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SurfaceCard(
        padding: EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
            SizedBox(height: 16),
            Text(
              'Memuat detail transaksi',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: SibasColors.text,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Mengambil rincian setoran beserta riwayat prosesnya.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: SibasColors.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Aksi di dalam panel keadaan (coba lagi / kembali).
class _StateAction {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _StateAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });
}

/// Keadaan gagal atau kosong: ikon, satu kalimat, lalu satu aksi.
class _StatePanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final bool danger;
  final _StateAction? action;

  const _StatePanel({
    required this.icon,
    required this.title,
    required this.message,
    this.danger = false,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final accent = danger ? SibasColors.status.badText : SibasColors.primary;
    final badge =
        danger ? SibasColors.status.rejectedBackground : SibasColors.mintWash;

    return SizedBox(
      width: double.infinity,
      child: SurfaceCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: badge,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(icon, size: 26, color: accent),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: SibasColors.text,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: SibasColors.muted,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: 16),
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  onPressed: action!.onPressed,
                  icon: Icon(action!.icon, size: 18),
                  label: Text(action!.label),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: SibasColors.primary,
                    side: BorderSide(color: SibasColors.border),
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BackButton extends StatelessWidget {
  const _BackButton();

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: 'Kembali',
      onPressed: () => _goBack(context),
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
    );
  }
}
