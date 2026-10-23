import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/colors.dart';
import '../../../../core/network/api_guard.dart';
import '../../../../core/widgets/content_width.dart';
import '../../../../core/widgets/glass_panel.dart';
import '../../../../core/widgets/hero_header.dart';
import '../../../../core/widgets/status_badge.dart';
import '../../../../core/widgets/surface_card.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/withdrawal_provider.dart';
import '../widgets/withdraw_qr_sheet.dart';

/// Lebar isi detail: cukup untuk dua kolom label–nilai di desktop.
const double _maxContentWidth = 720;

/// Target sentuh minimum (§4).
const double _touch = 44;

/// Tombol aksi utama (setujui/tolak) 48 px.
const double _action = 48;

/// Lebar label di baris nilai; tetap di ponsel 360 px.
const double _labelWidth = 124;

/// Nominal, tanggal, dan berat memakai lebar digit tetap (§3).
const List<FontFeature> _numbers = <FontFeature>[
  FontFeature.tabularFigures(),
];

/// Judul seksi: 15.5 w700, tracking -0.2 (§3).
const TextStyle _sectionTitle = TextStyle(
  fontSize: 15.5,
  fontWeight: FontWeight.w700,
  letterSpacing: -0.2,
  color: AppColors.textPrimary,
);

final _currency = NumberFormat.currency(
  locale: 'id_ID',
  symbol: 'Rp ',
  decimalDigits: 0,
);

/// Rincian satu pengajuan penarikan beserta riwayat proses dan aksi admin.
class WithdrawalDetailScreen extends ConsumerWidget {
  final String withdrawalId;

  const WithdrawalDetailScreen({
    super.key,
    required this.withdrawalId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detailState = ref.watch(withdrawalDetailProvider(withdrawalId));
    final row = detailState.valueOrNull;
    final isAdmin =
        ref.watch(currentUserProvider).valueOrNull?.isAdmin ?? false;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            // HeroHeader sudah memakai gutter sendiri; cukup dibatasi lebar
            // agar tepinya sejajar dengan isi di bawah.
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: _maxContentWidth),
                child: HeroHeader(
                  title: 'Detail Penarikan',
                  subtitle: 'Rincian pengajuan pencairan saldo',
                  trailing: const _BackButton(),
                  bottomContent: row == null
                      ? null
                      : _SummaryPanel(
                          amount: _num(row['amount']),
                          status: _text(row['status']),
                        ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentWidth(
              maxWidth: _maxContentWidth,
              child: Padding(
                padding: EdgeInsets.fromLTRB(
                  0,
                  20,
                  0,
                  96 + bottomInset,
                ),
                child: detailState.when(
                  loading: () => const _LoadingPanel(),
                  error: (error, __) => _ErrorBox(
                    message: pesanKesalahan(error),
                    onRetry: () => ref.invalidate(
                      withdrawalDetailProvider(withdrawalId),
                    ),
                  ),
                  data: (data) => data == null
                      ? const _NotFoundBox()
                      : _DetailBody(
                          row: data,
                          withdrawalId: withdrawalId,
                          isAdmin: isAdmin,
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

double? _num(dynamic value) => value is num ? value.toDouble() : null;

String? _text(dynamic value) {
  final text = value?.toString().trim();
  return (text == null || text.isEmpty) ? null : text;
}

DateTime? _date(dynamic value) =>
    value is String ? DateTime.tryParse(value) : null;

Map? _map(dynamic value) => value is Map ? value : null;

/// Angka dari JSON bisa `num` atau string (PostgREST `numeric`).
double? _angka(Object? value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value.trim());
  return null;
}

/// Koordinat 6 desimal, mis. `-7.797068, 110.370529`. Null bila tidak
/// lengkap, supaya baris tidak menampilkan "null".
String? _koordinat(Map? lokasi) {
  final lat = _angka(lokasi?['latitude']);
  final lng = _angka(lokasi?['longitude']);
  if (lat == null || lng == null) return null;
  return '${lat.toStringAsFixed(6)}, ${lng.toStringAsFixed(6)}';
}

String _statusLabel(String status) => switch (status.toUpperCase()) {
      'APPROVED' => 'Disetujui',
      'REJECTED' => 'Ditolak',
      'EXPIRED' => 'Kedaluwarsa',
      'PENDING' => 'Menunggu',
      _ => 'Status diperbarui',
    };

Color _statusColor(String status) => switch (status.toUpperCase()) {
      'APPROVED' => AppColors.statusApprovedText,
      'REJECTED' => AppColors.statusRejectedText,
      'EXPIRED' => AppColors.statusExpired,
      _ => AppColors.statusPendingText,
    };

/// Inisial pengaju: maksimal dua huruf.
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

/// Ringkasan nominal dan status di dalam hero header.
class _SummaryPanel extends StatelessWidget {
  final double? amount;
  final String? status;

  const _SummaryPanel({required this.amount, required this.status});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: GlassPanel(
        tone: GlassTone.hero,
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Nominal Penarikan',
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
                _currency.format(amount ?? 0),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                  height: 1.05,
                  fontFeatures: _numbers,
                ),
              ),
            ),
            const SizedBox(height: 12),
            StatusBadge(status: status ?? 'PENDING'),
          ],
        ),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  final Map<String, dynamic> row;
  final String withdrawalId;
  final bool isAdmin;

  const _DetailBody({
    required this.row,
    required this.withdrawalId,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy, HH:mm', 'id_ID');

    final status = _text(row['status']) ?? 'PENDING';
    final isPending = status.toUpperCase() == 'PENDING';
    final createdAt = _date(row['created_at']);
    final verifiedAt = _date(row['verified_at']);
    final mahasiswa = _map(row['mahasiswa']);
    final verifikator = _map(row['verifikator']);
    final lokasi = _map(row['location']);
    final rejectionReason = _text(row['rejection_reason']);
    final qrToken = _text(row['qr_token']);

    final studentName = _text(mahasiswa?['full_name']) ?? '-';
    final studentNim = _text(mahasiswa?['nim']);
    final verifierName = _text(verifikator?['full_name']);
    final lokasiNama = _text(lokasi?['name']);
    final lokasiAlamat = _text(lokasi?['address']);
    final lokasiKoordinat = _koordinat(lokasi);

    final verifierLabel = switch (status.toUpperCase()) {
      'APPROVED' => 'Disetujui oleh',
      'REJECTED' => 'Ditolak oleh',
      _ => 'Diverifikasi oleh',
    };

    final audits = <Map>[];
    final rawAudits = row['audits'];
    if (rawAudits is List) {
      for (final entry in rawAudits) {
        if (entry is Map) audits.add(entry);
      }
    }
    audits.sort((a, b) {
      final first = _date(a['created_at']);
      final second = _date(b['created_at']);
      if (first == null || second == null) return 0;
      return first.compareTo(second);
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Section(
          title: 'Pengaju',
          child: _StudentBlock(name: studentName, nim: studentNim),
        ),
        const SizedBox(height: 16),
        _Section(
          title: 'Rincian Pengajuan',
          child: Column(
            children: [
              _InfoRow(
                label: 'Tanggal Diajukan',
                value: createdAt == null
                    ? '-'
                    : dateFormat.format(createdAt.toLocal()),
                numbers: true,
              ),
              _InfoRow(
                label: 'Status',
                value: _statusLabel(status),
                emphasis: true,
              ),
              if (verifiedAt != null || verifierName != null)
                _InfoRow(
                  label: verifierLabel,
                  value: verifierName ?? '-',
                  secondary: verifiedAt == null
                      ? null
                      : dateFormat.format(verifiedAt.toLocal()),
                  numbers: verifiedAt != null,
                  isLast: lokasiNama == null,
                ),
              if (lokasiNama != null)
                _LocationRow(
                  nama: lokasiNama,
                  alamat: lokasiAlamat,
                  koordinat: lokasiKoordinat,
                ),
            ],
          ),
        ),
        if (!isAdmin && isPending && qrToken != null) ...[
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => showWithdrawQrSheet(
                context,
                token: qrToken,
                amount: _num(row['amount']) ?? 0,
                status: status,
              ),
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text('Tampilkan QR Penarikan'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size(0, _action),
                side: const BorderSide(color: AppColors.borderLine),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ],
        if (rejectionReason != null) ...[
          const SizedBox(height: 16),
          _NoteBox(
            icon: Icons.error_outline_rounded,
            title: 'Alasan Penolakan',
            text: rejectionReason,
          ),
        ],
        if (isAdmin && isPending) ...[
          const SizedBox(height: 16),
          _ApprovalActions(
            withdrawalId: withdrawalId,
            amount: _num(row['amount']) ?? 0,
          ),
        ],
        const SizedBox(height: 16),
        _Timeline(audits: audits),
      ],
    );
  }
}

/// Kartu seksi: judul 15.5 w700, radius 20, border 1 px (§4, §5).
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
  final String name;
  final String? nim;

  const _StudentBlock({required this.name, this.nim});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: AppColors.mintSoftBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLine),
          ),
          child: Text(
            _initials(name),
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.4,
              color: AppColors.primaryDark,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                nim == null ? 'NIM belum terisi' : 'NIM $nim',
                style: const TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: AppColors.textMuted,
                  fontFeatures: _numbers,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Baris label–nilai; angka memakai lebar digit tetap (§3).
class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final String? secondary;
  final bool numbers;
  final bool emphasis;
  final bool isLast;

  const _InfoRow({
    required this.label,
    required this.value,
    this.secondary,
    this.numbers = false,
    this.emphasis = false,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: _labelWidth,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.4,
                    fontWeight: FontWeight.w700,
                    color: emphasis
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                    fontFeatures: numbers ? _numbers : null,
                  ),
                ),
                if (secondary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary!,
                    style: const TextStyle(
                      fontSize: 12,
                      height: 1.4,
                      color: AppColors.textMuted,
                      fontFeatures: _numbers,
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

/// Lokasi pengambilan; hanya dirender bila `detail_penarikan` membawanya.
/// Koordinat ditampilkan sebagai teks biasa, bukan peta.
class _LocationRow extends StatelessWidget {
  final String nama;
  final String? alamat;
  final String? koordinat;

  const _LocationRow({required this.nama, this.alamat, this.koordinat});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(
          width: _labelWidth,
          child: Text(
            'Lokasi',
            style: TextStyle(
              fontSize: 12.5,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: Icon(
                  Icons.place_outlined,
                  size: 15,
                  color: AppColors.primaryMain,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      nama,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (alamat != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        alamat!,
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                    if (koordinat != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        'Koordinat $koordinat',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.4,
                          color: AppColors.textMuted,
                          fontFeatures: _numbers,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Riwayat proses dari audit penarikan (urutan kronologis).
class _Timeline extends StatelessWidget {
  final List<Map> audits;

  const _Timeline({required this.audits});

  @override
  Widget build(BuildContext context) {
    return _Section(
      title: 'Riwayat Proses',
      child: audits.isEmpty
          ? const Text(
              'Belum ada catatan proses.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            )
          : SurfaceCard(
              tone: SurfaceTone.subtle,
              radius: 16,
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  for (var i = 0; i < audits.length; i++)
                    _TimelineItem(
                      audit: audits[i],
                      isLast: i == audits.length - 1,
                    ),
                ],
              ),
            ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final Map audit;
  final bool isLast;

  const _TimelineItem({required this.audit, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final status = _text(audit['to_status']) ?? '';
    final color = _statusColor(status);
    final note = _text(audit['note']);
    final actor = _text(audit['actor_name']) ?? 'Sistem';
    final at = _date(audit['created_at']);
    final meta = at == null
        ? actor
        : '$actor • ${DateFormat('dd MMM yyyy, HH:mm', 'id_ID').format(at)}';

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
                    _statusLabel(status),
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
                      style: const TextStyle(
                        fontSize: 12.5,
                        height: 1.45,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: const TextStyle(
                      fontSize: 11.5,
                      height: 1.4,
                      color: AppColors.textMuted,
                      fontFeatures: _numbers,
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

/// Tombol verifikasi admin untuk pengajuan yang masih menunggu.
class _ApprovalActions extends ConsumerStatefulWidget {
  final String withdrawalId;
  final double amount;

  const _ApprovalActions({
    required this.withdrawalId,
    required this.amount,
  });

  @override
  ConsumerState<_ApprovalActions> createState() => _ApprovalActionsState();
}

class _ApprovalActionsState extends ConsumerState<_ApprovalActions> {
  bool _busy = false;

  Future<void> _run(Future<bool> Function() action, String success) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);

    final ok = await action();
    if (!mounted) return;

    if (ok) {
      // Biarkan tombol nonaktif sampai detail termuat ulang.
      ref.invalidate(withdrawalDetailProvider(widget.withdrawalId));
      messenger.showSnackBar(SnackBar(content: Text(success)));
      return;
    }

    setState(() => _busy = false);
    final failure = ref.read(withdrawalControllerProvider).error;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          failure == null
              ? 'Tindakan gagal dikirim. Coba lagi.'
              : pesanKesalahan(failure),
        ),
      ),
    );
  }

  Future<void> _approve() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text('Setujui Penarikan'),
        content: Text(
          'Setujui penarikan ${_currency.format(widget.amount)}? '
          'Saldo mahasiswa akan dikurangi sebesar nominal tersebut.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            style: TextButton.styleFrom(
              minimumSize: const Size(0, _touch),
              foregroundColor: AppColors.textMuted,
            ),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.primaryMain,
              foregroundColor: Colors.white,
              minimumSize: const Size(0, _touch),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Setujui'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    await _run(
      () => ref
          .read(withdrawalControllerProvider.notifier)
          .approve(widget.withdrawalId),
      'Penarikan disetujui.',
    );
  }

  Future<void> _reject() async {
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => const _RejectDialog(),
    );
    if (reason == null || !mounted) return;

    await _run(
      () => ref
          .read(withdrawalControllerProvider.notifier)
          .reject(widget.withdrawalId, reason),
      'Penarikan ditolak.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: SurfaceCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Tindakan Admin', style: _sectionTitle),
            const SizedBox(height: 4),
            const Text(
              'Periksa pengajuan sebelum menyetujui atau menolak.',
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _busy ? null : _approve,
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: const Text('Setujui'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primaryMain,
                foregroundColor: Colors.white,
                elevation: 0,
                minimumSize: const Size(0, _action),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: _busy ? null : _reject,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const Text('Tolak'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                minimumSize: const Size(0, _action),
                side: const BorderSide(color: AppColors.danger),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 12),
              const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Memproses...',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RejectDialog extends StatefulWidget {
  const _RejectDialog();

  @override
  State<_RejectDialog> createState() => _RejectDialogState();
}

class _RejectDialogState extends State<_RejectDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final reason = _controller.text.trim();
    if (reason.isEmpty) {
      setState(() => _error = 'Alasan penolakan wajib diisi.');
      return;
    }
    Navigator.of(context).pop(reason);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: const Text('Tolak Penarikan'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Tulis alasan agar mahasiswa tahu mengapa pengajuan ditolak.',
            style: TextStyle(
              fontSize: 13,
              height: 1.4,
              color: AppColors.textMuted,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _controller,
            autofocus: true,
            maxLines: 3,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: 'Contoh: Nomor rekening belum lengkap',
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          style: TextButton.styleFrom(
            minimumSize: const Size(0, _touch),
            foregroundColor: AppColors.textMuted,
          ),
          child: const Text('Batal'),
        ),
        FilledButton(
          onPressed: _submit,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            minimumSize: const Size(0, _touch),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: const Text('Tolak'),
        ),
      ],
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
        color: AppColors.statusRejectedBg,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: AppColors.danger),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.danger,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12.5,
                      height: 1.45,
                      color: AppColors.danger,
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

/// Keadaan memuat: spinner kecil dan satu kalimat.
class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
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
              'Memuat detail penarikan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppColors.textPrimary,
              ),
            ),
            SizedBox(height: 4),
            Text(
              'Mengambil rincian pengajuan beserta riwayat prosesnya.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorBox({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.statusRejectedBg,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 26,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Detail penarikan gagal dimuat',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Coba Lagi'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size(0, _touch),
                side: const BorderSide(color: AppColors.borderLine),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotFoundBox extends StatelessWidget {
  const _NotFoundBox();

  @override
  Widget build(BuildContext context) {
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
                color: AppColors.mintSoftBackground,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(
                Icons.search_off_rounded,
                size: 26,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Penarikan tidak ditemukan',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Data pengajuan ini tidak tersedia atau sudah dihapus.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.5,
                color: AppColors.textMuted,
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/dashboard');
                }
              },
              icon: const Icon(Icons.arrow_back_rounded, size: 18),
              label: const Text('Kembali'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                minimumSize: const Size(0, _touch),
                side: const BorderSide(color: AppColors.borderLine),
                padding: const EdgeInsets.symmetric(horizontal: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                textStyle: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
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
      onPressed: () {
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/dashboard');
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
