import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sibas/core/theme/app_palette.dart';
import 'package:sibas/core/widgets/glass_panel.dart';
import 'package:sibas/core/widgets/surface_card.dart';

void main() {
  // Tema minimal tanpa GoogleFonts: yang diuji hanya permukaan kaca, bukan
  // tipografi.
  ThemeData theme() => ThemeData(
        useMaterial3: true,
        extensions: const [AppPalette.light],
      );

  Widget wrap(Widget child) {
    return MaterialApp(
      theme: theme(),
      home: Scaffold(
        backgroundColor: AppPalette.light.background,
        body: Center(child: child),
      ),
    );
  }

  testWidgets('SurfaceCard statis: tanpa BackdropFilter', (tester) async {
    await tester.pumpWidget(
      wrap(const SurfaceCard(child: Text('kartu'))),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('kartu'), findsOneWidget);
    expect(
      find.byType(BackdropFilter),
      findsNothing,
      reason: 'kartu konten tidak boleh menambah blur',
    );
    expect(find.byType(ClipRRect), findsWidgets);
    expect(find.byType(DecoratedBox), findsWidgets);
  });

  testWidgets('GlassPanel memakai border 1.0', (tester) async {
    await tester.pumpWidget(
      wrap(const GlassPanel(child: Text('kaca'))),
    );

    final boxes = tester.widgetList<DecoratedBox>(
      find.byType(DecoratedBox),
    );

    final widths = <double>[];
    for (final box in boxes) {
      final decoration = box.decoration;
      if (decoration is BoxDecoration) {
        final border = decoration.border;
        if (border is Border) {
          widths.add(border.top.width);
        }
      }
    }

    expect(
      widths,
      contains(1.0),
      reason: 'border semua tone diseragamkan ke 1.0',
    );
  });
}
