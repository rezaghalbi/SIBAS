import 'package:flutter/widgets.dart';

/// Lebar konten maksimal 1120 px dengan gutter responsif (§4, §10.5).
///
/// Gutter 16 px di layar sempit dan 32 px mulai 900 px. Nilai gutter dipakai
/// juga oleh `HeroHeader` lewat [gutterFor] agar tepi lapisan sejajar.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = 1120,
  });

  final Widget child;
  final double maxWidth;

  /// Gutter halaman untuk lebar layar tertentu (§4).
  static double gutterFor(double width) => width >= 900 ? 32.0 : 16.0;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: gutterFor(width)),
          child: child,
        ),
      ),
    );
  }
}
