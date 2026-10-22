import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/utils/status_helper.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../providers/transaction_provider.dart';

/// Rincian satu transaksi setoran: nominal, status, waktu, dan verifikator.
class TransactionDetailScreen extends ConsumerWidget {
  final String transactionId;

  const TransactionDetailScreen({
    super.key,
    required this.transactionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(transactionDetailRpcProvider(transactionId));
    final row = detailState.valueOrNull;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: HeroHeader(
              title: 'Detail Transaksi',
              subtitle: (row?['tx_code'] as String?) ?? 'Rincian setoran sampah',
              trailing: const _BackButton(),
              bottomContent: row == null ? null : _SummaryPanel(row: row),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverToBoxAdapter(
              child: detailState.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (_, __) => _ErrorBox(
                  onRetry: () => ref.invalidate(
                    transactionDetailRpcProvider(transactionId),
                  ),
                ),
                data: (data) => data == null
                    ? const _NotFoundBox()
                    : _DetailCard(row: data),
              ),
            ),
          ),
        ],
      ),
    );
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

class _SummaryPanel extends StatelessWidget {
  final Map<String, dynamic> row;

  const _SummaryPanel({required this.row});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final status = _text(row['status']) ?? 'PENDING';
    final finalAmount = _num(row['final_amount']);

    return GlassPanel(
      padding: const EdgeInsets.all(20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  finalAmount == null ? 'Estimasi Nilai' : 'Nominal Final',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.9),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  currency.format(finalAmount ?? _num(row['estimated_amount']) ?? 0),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          StatusBadge(
            status: status,
            customLabel: TransactionStatusHelper.toDisplayLabel(status),
          ),
        ],
      ),
    );
  }
}

class _DetailCard extends StatelessWidget {
  final Map<String, dynamic> row;

  const _DetailCard({required this.row});

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    final categoryName = _text(row['trash_name']) ?? 'Sampah Daur Ulang';

    final weight = _num(row['weight']) ?? 0;
    final ratePerKg = _num(row['price_per_kg_snapshot']);
    final estimated = _num(row['estimated_amount']);
    final finalAmount = _num(row['final_amount']);
    final status = _text(row['status']) ?? 'PENDING';

    final createdAt = _date(row['created_at']);
    final verifiedAt = _date(row['verified_at']);
    final verifier = row['verifikator'];
    final verifierName = verifier is Map ? _text(verifier['full_name']) : null;
    final mahasiswa = row['mahasiswa'];
    final studentName = mahasiswa is Map ? _text(mahasiswa['full_name']) : null;
    final studentNim = mahasiswa is Map ? _text(mahasiswa['nim']) : null;
    final rejectionReason = _text(row['rejection_reason']);
    final audits = row['audits'];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLine),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Rincian Setoran',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Divider(height: 20, color: AppColors.borderLine),
              _DetailRow(
                label: 'Kode Transaksi',
                value: _text(row['tx_code']) ?? '-',
                monospace: true,
              ),
              _DetailRow(
                label: 'Pengaju',
                value: studentName ?? 'Tidak diketahui',
                muted: studentName == null,
              ),
              _DetailRow(
                label: 'NIM',
                value: studentNim ?? '-',
                muted: studentNim == null,
              ),
              _DetailRow(label: 'Jenis Sampah', value: categoryName),
              _DetailRow(label: 'Berat', value: '${weight.toStringAsFixed(1)} kg'),
              _DetailRow(
                label: 'Tarif per kg',
                value: (ratePerKg == null || ratePerKg <= 0)
                    ? 'Belum ada tarif'
                    : '${currency.format(ratePerKg)} / kg',
                muted: ratePerKg == null || ratePerKg <= 0,
              ),
              _DetailRow(
                label: 'Estimasi Nilai',
                value: estimated == null ? '-' : currency.format(estimated),
              ),
              _DetailRow(
                label: 'Nominal Final',
                value: finalAmount == null
                    ? 'Belum ditetapkan'
                    : currency.format(finalAmount),
                highlight: finalAmount != null,
                muted: finalAmount == null,
              ),
              _DetailRow(
                label: 'Status',
                value: TransactionStatusHelper.toDisplayLabel(status),
              ),
              _DetailRow(
                label: 'Waktu Pengajuan',
                value: createdAt == null ? '-' : dateFormat.format(createdAt),
              ),
              _DetailRow(
                label: 'Waktu Verifikasi',
                value: verifiedAt == null
                    ? 'Belum diproses'
                    : dateFormat.format(verifiedAt),
                muted: verifiedAt == null,
              ),
              _DetailRow(
                label: 'Diproses Oleh',
                value: verifierName ?? 'Belum diproses',
                muted: verifierName == null,
              ),
            ],
          ),
        ),
        if (audits is List) ...[
          const SizedBox(height: 16),
          _AuditTimeline(audits: audits),
        ],
        if (rejectionReason != null) ...[
          const SizedBox(height: 16),
          _NoteBox(
            icon: Icons.error_outline_rounded,
            title: 'Alasan Penolakan',
            text: rejectionReason,
            background: AppColors.statusRejectedBg,
            foreground: AppColors.danger,
          ),
        ],
        if (status.toUpperCase() == 'EXPIRED') ...[
          const SizedBox(height: 16),
          const _NoteBox(
            icon: Icons.timer_off_rounded,
            title: 'Kode QR Kedaluwarsa',
            text: 'Batas waktu verifikasi sudah lewat sehingga kode QR tidak '
                'bisa dipindai admin. Silakan ajukan setoran baru.',
            background: AppColors.statusRejectedBg,
            foreground: AppColors.danger,
          ),
        ],
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/history');
              }
            },
            child: const Text('Kembali'),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  final bool monospace;
  final bool muted;
  final bool highlight;

  const _DetailRow({
    required this.label,
    required this.value,
    this.monospace = false,
    this.muted = false,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              label,
              style: const TextStyle(fontSize: 13, color: AppColors.textMuted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 13,
                fontFamily: monospace ? 'monospace' : null,
                fontWeight: muted ? FontWeight.w500 : FontWeight.w700,
                color: highlight
                    ? AppColors.primaryMain
                    : (muted ? AppColors.textMuted : AppColors.textPrimary),
              ),
            ),
          ),
        ],
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
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    final entries = audits.whereType<Map>().toList()
      ..sort((a, b) {
        final left = _date(a['created_at']);
        final right = _date(b['created_at']);
        if (left == null || right == null) return 0;
        return left.compareTo(right);
      });

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Riwayat Proses',
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const Divider(height: 20, color: AppColors.borderLine),
          if (entries.isEmpty)
            const Text(
              'Belum ada riwayat proses.',
              style: TextStyle(fontSize: 13, color: AppColors.textMuted),
            )
          else
            for (var i = 0; i < entries.length; i++)
              _AuditRow(
                entry: entries[i],
                isLast: i == entries.length - 1,
                dateFormat: dateFormat,
              ),
        ],
      ),
    );
  }
}

class _AuditRow extends StatelessWidget {
  final Map entry;
  final bool isLast;
  final DateFormat dateFormat;

  const _AuditRow({
    required this.entry,
    required this.isLast,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    final toStatus = entry['to_status']?.toString();
    final color = TransactionStatusHelper.getStatusColor(toStatus);
    final note = _text(entry['note']);
    final actor = _text(entry['actor_name']);
    final at = _date(entry['created_at']);

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
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    margin: const EdgeInsets.symmetric(vertical: 2),
                    color: AppColors.borderLine,
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
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  if (note != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      note,
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    [
                      if (actor != null) actor else 'Sistem',
                      if (at != null) dateFormat.format(at),
                    ].join(' • '),
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textMuted,
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
  final Color background;
  final Color foreground;

  const _NoteBox({
    required this.icon,
    required this.title,
    required this.text,
    required this.background,
    required this.foreground,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: foreground.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: foreground),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: foreground,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  text,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: foreground,
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

class _ErrorBox extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorBox({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.statusRejectedBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          const Text(
            'Gagal memuat detail transaksi. Periksa koneksi Anda.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(height: 6),
          TextButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Coba Lagi'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
          ),
        ],
      ),
    );
  }
}

class _NotFoundBox extends StatelessWidget {
  const _NotFoundBox();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLine),
      ),
      child: const Column(
        children: [
          Icon(Icons.search_off_rounded, size: 32, color: AppColors.textMuted),
          SizedBox(height: 10),
          Text(
            'Transaksi tidak ditemukan.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
          ),
        ],
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
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/history');
        }
      },
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
