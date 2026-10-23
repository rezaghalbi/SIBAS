import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/core/theme/app_palette.dart';
import 'package:sibas/core/widgets/glass_panel.dart';

void main() {
  // Tema minimal dengan token yang sama seperti `AppTheme.lightTheme`.
  // `AppTheme.lightTheme` memakai GoogleFonts yang ingin memuat berkas font
  // saat test; yang diuji di sini hanya tone kaca, bukan tipografi.
  ThemeData theme() => ThemeData(
        useMaterial3: true,
        extensions: const [AppPalette.light],
      );

  Widget wrap(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      theme: theme(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            disableAnimations: disableAnimations,
          ),
          child: Scaffold(body: Center(child: child)),
        ),
      ),
    );
  }

  testWidgets('ketiga tone ter-build tanpa exception', (tester) async {
    for (final tone in GlassTone.values) {
      await tester.pumpWidget(
        wrap(GlassPanel(tone: tone, child: const Text('kaca'))),
      );

      expect(tester.takeException(), isNull, reason: 'tone $tone gagal');
      expect(find.text('kaca'), findsOneWidget);
      expect(
        find.byType(BackdropFilter),
        findsOneWidget,
        reason: 'tone $tone tetap memakai satu blur',
      );
    }
  });

  testWidgets('disableAnimations tidak memakai BackdropFilter',
      (tester) async {
    await tester.pumpWidget(
      wrap(
        const GlassPanel(child: Text('kaca')),
        disableAnimations: true,
      ),
    );

    expect(find.byType(BackdropFilter), findsNothing);
    expect(find.text('kaca'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('tone dense memakai radius 24', (tester) async {
    await tester.pumpWidget(
      wrap(const GlassPanel(tone: GlassTone.dense, child: Text('kaca'))),
    );

    final clips = tester.widgetList<ClipRRect>(
      find.ancestor(of: find.text('kaca'), matching: find.byType(ClipRRect)),
    );

    expect(
      clips.any((clip) => clip.borderRadius == BorderRadius.circular(24)),
      isTrue,
    );
  });

  testWidgets('tone subtle tetap memakai radius 20', (tester) async {
    await tester.pumpWidget(
      wrap(const GlassPanel(child: Text('kaca'))),
    );

    final clips = tester.widgetList<ClipRRect>(
      find.ancestor(of: find.text('kaca'), matching: find.byType(ClipRRect)),
    );

    expect(
      clips.any((clip) => clip.borderRadius == BorderRadius.circular(20)),
      isTrue,
    );
  });
}
