import 'dart:math';
import 'dart:ui';

/// Pure helpers for wheel geometry — no Flutter widget dependencies.
class WheelMath {
  WheelMath._();

  /// Compute which segment the pointer (at the top of the wheel) lands on
  /// after a rotation of [rotation] radians on a wheel with [segmentCount]
  /// equal segments.
  ///
  /// Returns an index in `[0, segmentCount)`. Throws [ArgumentError] if
  /// [segmentCount] is non-positive.
  static int selectedSegment(double rotation, int segmentCount) {
    if (segmentCount <= 0) {
      throw ArgumentError.value(segmentCount, 'segmentCount', 'must be > 0');
    }
    final twoPi = 2 * pi;
    final segmentAngle = twoPi / segmentCount;
    // Bring rotation into [0, 2π), handling negative rotations from reverse spins.
    final normalized = ((rotation % twoPi) + twoPi) % twoPi;
    final rawIndex = (normalized / segmentAngle).floor() % segmentCount;
    return (segmentCount - rawIndex - 1) % segmentCount;
  }

  /// Compute the rotation delta needed to snap [rotation] to the nearest
  /// segment boundary, for a wheel with [segmentCount] segments.
  ///
  /// Returns a value in roughly `(-segmentAngle/2, segmentAngle/2]`.
  static double snapDelta(double rotation, int segmentCount) {
    if (segmentCount <= 0) {
      throw ArgumentError.value(segmentCount, 'segmentCount', 'must be > 0');
    }
    final twoPi = 2 * pi;
    final segmentAngle = twoPi / segmentCount;
    final normalized = ((rotation % twoPi) + twoPi) % twoPi;
    final nearest = (normalized / segmentAngle).round();
    return nearest * segmentAngle - normalized;
  }

  /// Angle in radians from [center] to [position], measured with atan2.
  static double angleFromPosition(Offset center, Offset position) {
    final dx = position.dx - center.dx;
    final dy = position.dy - center.dy;
    return atan2(dy, dx);
  }
}
