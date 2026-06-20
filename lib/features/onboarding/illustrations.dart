import 'package:flutter/material.dart';

import '../../core/app_colors.dart';

/// Lightweight onboarding illustrations built purely from Flutter primitives
/// (no SVG asset pipeline). Each is a 220×220 composition keyed by a single
/// accent color so the slide preserves its existing color identity. The
/// shapes are deliberately simple — the goal is "this app was designed", not
/// "we hired an illustrator" — but the layered composition reads as something
/// more than the single-icon fallback the slides used before.
class OnboardingArt extends StatelessWidget {
  final OnboardingScene scene;
  final Color accent;
  const OnboardingArt({super.key, required this.scene, required this.accent});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 220,
      height: 220,
      child: CustomPaint(
        painter: _OnboardingPainter(scene: scene, accent: accent),
      ),
    );
  }
}

enum OnboardingScene { route, matching, co2, pickupCode }

class _OnboardingPainter extends CustomPainter {
  final OnboardingScene scene;
  final Color accent;
  _OnboardingPainter({required this.scene, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    // Soft glow disc behind every scene so the composition has weight against
    // the dark background. Single render path keeps the four scenes visually
    // consistent.
    final glow = Paint()
      ..shader = RadialGradient(
        colors: [
          accent.withValues(alpha: 0.22),
          accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromCircle(
          center: size.center(Offset.zero), radius: size.width * 0.55));
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.55, glow);

    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accent.withValues(alpha: 0.28);
    canvas.drawCircle(size.center(Offset.zero), size.width * 0.42, ring);

    switch (scene) {
      case OnboardingScene.route:
        _paintRoute(canvas, size);
        break;
      case OnboardingScene.matching:
        _paintMatching(canvas, size);
        break;
      case OnboardingScene.co2:
        _paintCo2(canvas, size);
        break;
      case OnboardingScene.pickupCode:
        _paintPickupCode(canvas, size);
        break;
    }
  }

  void _paintRoute(Canvas canvas, Size size) {
    // S-curve road with an origin pin (bottom-left) and dest pin (top-right).
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.78)
      ..cubicTo(
        size.width * 0.45, size.height * 0.62,
        size.width * 0.30, size.height * 0.42,
        size.width * 0.55, size.height * 0.32,
      )
      ..cubicTo(
        size.width * 0.78, size.height * 0.22,
        size.width * 0.82, size.height * 0.28,
        size.width * 0.82, size.height * 0.22,
      );
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..strokeCap = StrokeCap.round
        ..color = accent,
    );
    // Dashed shadow under the road, suggesting depth.
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = accent.withValues(alpha: 0.4)
        ..strokeCap = StrokeCap.round,
    );
    _drawPin(canvas, Offset(size.width * 0.18, size.height * 0.78), accent);
    _drawPin(canvas, Offset(size.width * 0.82, size.height * 0.22),
        AppColors.teal);
  }

  void _paintMatching(Canvas canvas, Size size) {
    // Two passenger/driver circles joined by a soft connector arc.
    final left = Offset(size.width * 0.30, size.height * 0.50);
    final right = Offset(size.width * 0.70, size.height * 0.50);
    final connect = Path()
      ..moveTo(left.dx + 24, left.dy)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.30,
        right.dx - 24,
        right.dy,
      );
    canvas.drawPath(
      connect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = accent.withValues(alpha: 0.55),
    );
    _drawAvatar(canvas, left, accent, Icons.person_rounded);
    _drawAvatar(canvas, right, AppColors.success, Icons.directions_car_rounded);
  }

  void _paintCo2(Canvas canvas, Size size) {
    // Leaf silhouette with a down-arrow signaling "reduced".
    final leafPath = Path()
      ..moveTo(size.width * 0.30, size.height * 0.62)
      ..quadraticBezierTo(
        size.width * 0.30, size.height * 0.30,
        size.width * 0.62, size.height * 0.30,
      )
      ..quadraticBezierTo(
        size.width * 0.65, size.height * 0.58,
        size.width * 0.30, size.height * 0.62,
      );
    canvas.drawPath(
      leafPath,
      Paint()
        ..color = accent.withValues(alpha: 0.18)
        ..style = PaintingStyle.fill,
    );
    canvas.drawPath(
      leafPath,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    // Stem
    canvas.drawLine(
      Offset(size.width * 0.30, size.height * 0.62),
      Offset(size.width * 0.46, size.height * 0.46),
      Paint()
        ..color = accent
        ..strokeWidth = 2.5,
    );
    // Down-arrow chip in the top-right
    final arrowCenter = Offset(size.width * 0.78, size.height * 0.30);
    canvas.drawCircle(
      arrowCenter,
      18,
      Paint()..color = accent.withValues(alpha: 0.22),
    );
    canvas.drawLine(
      arrowCenter.translate(0, -8),
      arrowCenter.translate(0, 8),
      Paint()
        ..color = accent
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      arrowCenter.translate(-6, 2),
      arrowCenter.translate(0, 8),
      Paint()
        ..color = accent
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawLine(
      arrowCenter.translate(6, 2),
      arrowCenter.translate(0, 8),
      Paint()
        ..color = accent
        ..strokeWidth = 2.6
        ..strokeCap = StrokeCap.round,
    );
  }

  void _paintPickupCode(Canvas canvas, Size size) {
    // 2×2 grid of "digit" tiles in the center, suggesting the pickup keypad.
    const cols = 2;
    const rows = 2;
    final tileSize = size.width * 0.18;
    final gap = 10.0;
    final gridW = cols * tileSize + (cols - 1) * gap;
    final gridH = rows * tileSize + (rows - 1) * gap;
    final originX = (size.width - gridW) / 2;
    final originY = (size.height - gridH) / 2 + 6;
    final tileFill = Paint()
      ..color = accent.withValues(alpha: 0.18);
    final tileStroke = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..color = accent.withValues(alpha: 0.55);
    for (var r = 0; r < rows; r++) {
      for (var c = 0; c < cols; c++) {
        final rect = Rect.fromLTWH(
          originX + c * (tileSize + gap),
          originY + r * (tileSize + gap),
          tileSize,
          tileSize,
        );
        final rrect = RRect.fromRectAndRadius(rect, const Radius.circular(10));
        canvas.drawRRect(rrect, tileFill);
        canvas.drawRRect(rrect, tileStroke);
        canvas.drawCircle(
          rect.center,
          tileSize * 0.16,
          Paint()..color = accent,
        );
      }
    }
  }

  void _drawPin(Canvas canvas, Offset pos, Color color) {
    canvas.drawCircle(
      pos,
      11,
      Paint()..color = color,
    );
    canvas.drawCircle(
      pos,
      11,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    canvas.drawCircle(
      pos,
      4,
      Paint()..color = Colors.white,
    );
  }

  void _drawAvatar(Canvas canvas, Offset pos, Color color, IconData icon) {
    canvas.drawCircle(
      pos,
      24,
      Paint()..color = color,
    );
    canvas.drawCircle(
      pos,
      24,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
    );
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(
          fontSize: 22,
          fontFamily: icon.fontFamily,
          color: Colors.white,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      pos - Offset(tp.width / 2, tp.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant _OnboardingPainter old) =>
      old.scene != scene || old.accent != accent;
}
