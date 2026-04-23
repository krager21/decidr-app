import 'dart:math';
import 'package:flutter/material.dart';
import '../utils/constants.dart';

/// Enhanced wheel painter with better visuals - Text Removed
class EnhancedWheelPainter extends CustomPainter {
  final List<String> suggestions;
  final int? selectedSegment;
  final List<Color> colors;

  /// Icons parallel to [suggestions]. Pre-computed by the caller so `paint`
  /// does not have to call into a provider or resolver on every frame.
  final List<IconData> icons;

  EnhancedWheelPainter({
    required this.suggestions,
    this.selectedSegment,
    required this.colors,
    required this.icons,
  }) : assert(icons.length == suggestions.length,
            'icons must be parallel to suggestions');

  @override
  void paint(Canvas canvas, Size size) {
    if (suggestions.isEmpty) return;
    
    double centerX = size.width / 2;
    double centerY = size.height / 2;
    Offset center = Offset(centerX, centerY);
    double radius = min(centerX, centerY);
    int n = suggestions.length;
    double sweepAngle = 2 * pi / n;
    double startAngle = -pi / 2 - (sweepAngle / 2);

    var fillPaint = Paint()..style = PaintingStyle.fill;
    var borderPaint = Paint()
      ..style = PaintingStyle.stroke
      ..color = Colors.white
      ..strokeWidth = WheelConstants.segmentBorderWidth;

    // Draw a circle as base
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = Colors.white,
    );

    for (int i = 0; i < n; i++) {
      bool isSelected = selectedSegment == i;
      
      // Get color for this segment
      Color baseColor = colors[i % colors.length];
      
      // Create a gradient for each segment for more depth
      fillPaint.shader = RadialGradient(
        center: const Alignment(0.0, 0.0),
        radius: 1.0,
        colors: [
          baseColor.withOpacity(isSelected ? 1.0 : 0.7),
          baseColor.withOpacity(isSelected ? 0.85 : 0.5),
        ],
        stops: const [0.4, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

      double segmentStart = startAngle + i * sweepAngle;

      // Draw the segment
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        segmentStart,
        sweepAngle,
        true,
        fillPaint,
      );

      // Draw glow for selected segment
      if (isSelected) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          segmentStart,
          sweepAngle,
          true,
          Paint()
            ..style = PaintingStyle.stroke
            ..color = baseColor.withOpacity(0.8)
            ..strokeWidth = 5
            ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 3),
        );
      }

      // Draw the white border
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        segmentStart,
        sweepAngle,
        true,
        borderPaint,
      );

      // Get suggestion and icon
      IconData iconData = icons[i];
      
      // Calculate icon position and angle - moved further out to center in segment
      double textAngle = segmentStart + sweepAngle / 2;
      double iconRadius = radius * WheelConstants.iconRadiusRatio;
      Offset iconPosition = Offset(
        centerX + iconRadius * cos(textAngle),
        centerY + iconRadius * sin(textAngle),
      );
      
      // Draw icon with rotation to keep it upright
      canvas.save();
      canvas.translate(iconPosition.dx, iconPosition.dy);
      canvas.rotate(textAngle + pi);
      
      // Create text painter for icon
      TextPainter iconPainter = TextPainter(
        text: TextSpan(
          text: String.fromCharCode(iconData.codePoint),
          style: TextStyle(
            fontSize: WheelConstants.iconSize,
            fontFamily: iconData.fontFamily,
            package: iconData.fontPackage,
            color: Colors.white,
            shadows: [
              Shadow(
                offset: const Offset(1, 1),
                blurRadius: 2,
                color: Colors.black.withOpacity(0.3),
              ),
            ],
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      
      iconPainter.layout();
      iconPainter.paint(canvas, Offset(-iconPainter.width / 2, -iconPainter.height / 2));
      canvas.restore();

      // Text drawing code removed to clean up the wheel
    }
    
    // Draw outer ring
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..color = Colors.grey.shade300
        ..strokeWidth = WheelConstants.outerRingWidth,
    );
  }

  @override
  bool shouldRepaint(EnhancedWheelPainter oldDelegate) =>
      oldDelegate.selectedSegment != selectedSegment ||
      oldDelegate.suggestions != suggestions ||
      oldDelegate.colors != colors ||
      oldDelegate.icons != icons;
}

/// Enhanced pointer painter with better styling
class EnhancedPointerPainter extends CustomPainter {
  final Color color;
  
  EnhancedPointerPainter({
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    var path = Path();
    
    // Draw a more stylized pointer
    path.moveTo(size.width / 2, 0);
    path.lineTo(size.width * 0.3, size.height * 0.4);
    path.quadraticBezierTo(
      size.width / 2, size.height,
      size.width * 0.7, size.height * 0.4,
    );
    path.close();
    
    // Add shadow for depth
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withOpacity(0.3)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3),
    );
    
    // Draw the pointer
    canvas.drawPath(path, paint);
    
    // Add highlight for metallic look
    var highlightPaint = Paint()
      ..color = Colors.white.withOpacity(0.5)
      ..style = PaintingStyle.fill;
    
    var highlightPath = Path();
    highlightPath.moveTo(size.width / 2, size.height * 0.2);
    highlightPath.lineTo(size.width * 0.4, size.height * 0.4);
    highlightPath.lineTo(size.width * 0.6, size.height * 0.4);
    highlightPath.close();
    
    canvas.drawPath(highlightPath, highlightPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => 
      oldDelegate is EnhancedPointerPainter && oldDelegate.color != color;
}