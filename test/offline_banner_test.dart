import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/core/network/api_guard.dart';
import 'package:sibas/core/widgets/offline_banner.dart';

void main() {
  const pesan = 'Tidak ada koneksi — data mungkin tidak terbaru';

  tearDown(() => offlineNotifier.value = false);

  testWidgets('banner tersembunyi saat online, muncul saat offline',
      (tester) async {
    offlineNotifier.value = false;
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: OfflineBanner())),
    );
    expect(find.text(pesan), findsNothing);

    offlineNotifier.value = true;
    await tester.pump();
    expect(find.text(pesan), findsOneWidget);

    offlineNotifier.value = false;
    await tester.pump();
    expect(find.text(pesan), findsNothing);
  });
}
