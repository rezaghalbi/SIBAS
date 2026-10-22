import 'dart:async';

import 'package:flutter/material.dart';

/// Mengakhiri sesi setelah tidak ada interaksi selama [batas].
///
/// Dipasang di akar aplikasi: sesi bank sampah sebaiknya tidak menggantung
/// berhari-hari di komputer bersama. Hanya aktif saat [aktif] true (pengguna
/// sudah masuk), dan timer direset setiap kali ada sentuhan/klik.
///
/// ponytail: deteksi interaksi lewat pointer + siklus hidup aplikasi saja;
/// aktivitas keyboard murni (Tab/Enter) tidak dihitung. Naikkan cakupan dengan
/// `HardwareKeyboard` bila kelak perlu.
class SessionIdleWatcher extends StatefulWidget {
  final Widget child;
  final bool aktif;
  final Duration batas;
  final VoidCallback saatIdle;

  const SessionIdleWatcher({
    super.key,
    required this.child,
    required this.aktif,
    required this.saatIdle,
    this.batas = const Duration(minutes: 30),
  });

  @override
  State<SessionIdleWatcher> createState() => _SessionIdleWatcherState();
}

class _SessionIdleWatcherState extends State<SessionIdleWatcher>
    with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _reset();
  }

  @override
  void didUpdateWidget(covariant SessionIdleWatcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.aktif != widget.aktif || oldWidget.batas != widget.batas) {
      _reset();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Kembali dari latar belakang: beri waktu penuh, jangan langsung keluar.
    if (state == AppLifecycleState.resumed) _reset();
  }

  void _reset() {
    _timer?.cancel();
    if (!widget.aktif) return;
    _timer = Timer(widget.batas, widget.saatIdle);
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _reset(),
      child: widget.child,
    );
  }
}
