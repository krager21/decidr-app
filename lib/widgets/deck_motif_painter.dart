import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../data/deck_themes.dart';

/// Paints a deck's back-face motif in its accent color at low
/// opacity — subtle art behind the emblem, sized to the card.
class DeckMotifPainter extends CustomPainter {
  final DeckMotif motif;
  final Color accent;

  const DeckMotifPainter({required this.motif, required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = accent.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    final fill = Paint()..color = accent.withValues(alpha: 0.22);

    switch (motif) {
      case DeckMotif.classic:
        break; // the rings + emblem carry the classic look

      case DeckMotif.moonAndStars:
        // Crescent moon upper-left: full circle minus an offset circle.
        final moonCenter = Offset(size.width * 0.30, size.height * 0.22);
        final crescent = Path.combine(
          PathOperation.difference,
          Path()..addOval(Rect.fromCircle(center: moonCenter, radius: 11)),
          Path()
            ..addOval(Rect.fromCircle(
              center: moonCenter.translate(5, -3),
              radius: 10,
            )),
        );
        canvas.drawPath(crescent, fill);
        for (final (dx, dy, r) in [
          (0.68, 0.18, 2.2),
          (0.78, 0.32, 1.4),
          (0.25, 0.78, 1.8),
          (0.70, 0.82, 2.0),
        ]) {
          _star(canvas, fill,
              Offset(size.width * dx, size.height * dy), r * 2.4);
        }

      case DeckMotif.leaves:
        for (final (dx, dy, angle) in [
          (0.25, 0.20, -0.5),
          (0.75, 0.30, 0.7),
          (0.28, 0.80, 0.4),
          (0.72, 0.78, -0.6),
        ]) {
          canvas.save();
          canvas.translate(size.width * dx, size.height * dy);
          canvas.rotate(angle);
          final leaf = Path()
            ..moveTo(0, -9)
            ..quadraticBezierTo(7, -2, 0, 9)
            ..quadraticBezierTo(-7, -2, 0, -9);
          canvas.drawPath(leaf, stroke);
          canvas.drawLine(const Offset(0, -7), const Offset(0, 7), stroke);
          canvas.restore();
        }

      case DeckMotif.sunRays:
        // Half-sun on the lower edge with radiating rays.
        final center = Offset(size.width / 2, size.height * 0.92);
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: 14),
          math.pi,
          math.pi,
          false,
          stroke,
        );
        for (var i = 0; i < 7; i++) {
          final angle = math.pi + (i + 0.5) * math.pi / 7;
          final from = center + Offset.fromDirection(angle, 18);
          final to = center + Offset.fromDirection(angle, 30);
          canvas.drawLine(from, to, stroke);
        }

      case DeckMotif.geometric:
        // Concentric diamonds around the emblem.
        final center = Offset(size.width / 2, size.height / 2);
        for (final r in [40.0, 52.0, 64.0]) {
          final diamond = Path()
            ..moveTo(center.dx, center.dy - r)
            ..lineTo(center.dx + r * 0.7, center.dy)
            ..lineTo(center.dx, center.dy + r)
            ..lineTo(center.dx - r * 0.7, center.dy)
            ..close();
          canvas.drawPath(diamond, stroke);
        }
    }
  }

  /// Four-point sparkle star.
  void _star(Canvas canvas, Paint paint, Offset c, double r) {
    final path = Path()
      ..moveTo(c.dx, c.dy - r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx + r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + r)
      ..quadraticBezierTo(c.dx, c.dy, c.dx - r, c.dy)
      ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - r)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(DeckMotifPainter oldDelegate) =>
      oldDelegate.motif != motif || oldDelegate.accent != accent;
}
