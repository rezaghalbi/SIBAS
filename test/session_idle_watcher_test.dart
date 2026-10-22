import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/core/widgets/session_idle_watcher.dart';

const kunciIsi = Key('isi');

Widget bungkus({required bool aktif, required VoidCallback saatIdle}) {
  return MaterialApp(
    home: SessionIdleWatcher(
      aktif: aktif,
      batas: const Duration(minutes: 30),
      saatIdle: saatIdle,
      child: const SizedBox(key: kunciIsi, width: 100, height: 100),
    ),
  );
}

void main() {
  testWidgets('A: callback dipanggil setelah batas, belum sebelum', (tester) async {
    var panggilan = 0;
    await tester.pumpWidget(bungkus(aktif: true, saatIdle: () => panggilan++));

    await tester.pump(const Duration(minutes: 29));
    expect(panggilan, 0);

    await tester.pump(const Duration(minutes: 2));
    expect(panggilan, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('B: interaksi mereset timer', (tester) async {
    var panggilan = 0;
    await tester.pumpWidget(bungkus(aktif: true, saatIdle: () => panggilan++));

    await tester.pump(const Duration(minutes: 20));
    await tester.tap(find.byKey(kunciIsi));

    // 15 menit sejak reset: total 35 menit, tapi belum lewat 30 menit sejak tap.
    await tester.pump(const Duration(minutes: 15));
    expect(panggilan, 0);

    await tester.pump(const Duration(minutes: 16));
    expect(panggilan, 1);

    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('C: tidak aktif berarti callback tidak pernah dipanggil',
      (tester) async {
    var panggilan = 0;
    await tester.pumpWidget(bungkus(aktif: false, saatIdle: () => panggilan++));

    await tester.pump(const Duration(hours: 2));
    expect(panggilan, 0);

    await tester.pumpWidget(const SizedBox());
  });
}
