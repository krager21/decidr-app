import 'dart:math';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:decidr_app/utils/wheel_math.dart';

void main() {
  group('WheelMath.selectedSegment', () {
    test('rotation of 0 resolves to a deterministic baseline segment', () {
      // Formula: (n - floor(rot / segAngle) - 1) mod n.
      // With rot = 0, that evaluates to n - 1.
      expect(WheelMath.selectedSegment(0, 8), 7);
      expect(WheelMath.selectedSegment(0, 4), 3);
    });

    test('full rotations return to the baseline segment', () {
      for (int n in [2, 4, 6, 8, 12]) {
        final baseline = WheelMath.selectedSegment(0, n);
        expect(WheelMath.selectedSegment(2 * pi, n), baseline,
            reason: 'n=$n full rotation');
        expect(WheelMath.selectedSegment(4 * pi, n), baseline,
            reason: 'n=$n two full rotations');
      }
    });

    test('rotating by one segment shifts the selection by -1 mod n', () {
      const n = 8;
      final segmentAngle = 2 * pi / n;
      // A clockwise rotation of one segment walks the selection backward.
      final first = WheelMath.selectedSegment(0, n);
      final second =
          WheelMath.selectedSegment(segmentAngle + 1e-6, n); // just past
      expect((first - second + n) % n, 1);
    });

    test('returns indices always within [0, n)', () {
      final rng = Random(42);
      for (int i = 0; i < 200; i++) {
        final rotation = rng.nextDouble() * 40 - 20; // [-20, 20]
        final n = 2 + rng.nextInt(20);
        final result = WheelMath.selectedSegment(rotation, n);
        expect(result, inInclusiveRange(0, n - 1),
            reason: 'rotation=$rotation, n=$n');
      }
    });

    test('negative rotations are handled (reverse spin)', () {
      // A negative rotation should still yield a valid segment,
      // and should be equivalent modulo 2π to the positive counterpart.
      const n = 6;
      final forward = WheelMath.selectedSegment(2 * pi + 0.1, n);
      final backward = WheelMath.selectedSegment(-2 * pi + 0.1, n);
      expect(forward, backward);
    });

    test('throws on non-positive segment count', () {
      expect(() => WheelMath.selectedSegment(0, 0), throwsArgumentError);
      expect(() => WheelMath.selectedSegment(0, -3), throwsArgumentError);
    });
  });

  group('WheelMath.snapDelta', () {
    test('already-aligned rotation returns zero delta', () {
      const n = 8;
      final segmentAngle = 2 * pi / n;
      for (int i = 0; i < n; i++) {
        final delta = WheelMath.snapDelta(i * segmentAngle, n);
        expect(delta, closeTo(0, 1e-9), reason: 'segment $i');
      }
    });

    test('snap never exceeds half a segment in magnitude', () {
      final rng = Random(7);
      for (int i = 0; i < 200; i++) {
        final rotation = rng.nextDouble() * 40 - 20;
        final n = 2 + rng.nextInt(20);
        final halfSegment = pi / n;
        final delta = WheelMath.snapDelta(rotation, n);
        // Round() can push up to exactly half a segment.
        expect(delta.abs(), lessThanOrEqualTo(halfSegment + 1e-9));
      }
    });

    test('applying the delta lands on a segment boundary', () {
      final rng = Random(99);
      const n = 10;
      final segmentAngle = 2 * pi / n;
      for (int i = 0; i < 50; i++) {
        final rotation = rng.nextDouble() * 10 - 5;
        final delta = WheelMath.snapDelta(rotation, n);
        final snapped = rotation + delta;
        final normalized = ((snapped % (2 * pi)) + 2 * pi) % (2 * pi);
        final remainder = normalized % segmentAngle;
        // Remainder should be near 0 or near segmentAngle (wrap).
        final distToBoundary =
            min(remainder, segmentAngle - remainder);
        expect(distToBoundary, closeTo(0, 1e-9));
      }
    });

    test('throws on non-positive segment count', () {
      expect(() => WheelMath.snapDelta(1.0, 0), throwsArgumentError);
    });
  });

  group('WheelMath.angleFromPosition', () {
    test('returns 0 for a point directly right of center', () {
      expect(
        WheelMath.angleFromPosition(
          const Offset(100, 100),
          const Offset(150, 100),
        ),
        closeTo(0, 1e-9),
      );
    });

    test('returns π/2 for a point directly below center', () {
      // Flutter's y-axis points down, so atan2(+dy, 0) = π/2.
      expect(
        WheelMath.angleFromPosition(
          const Offset(100, 100),
          const Offset(100, 150),
        ),
        closeTo(pi / 2, 1e-9),
      );
    });

    test('returns π for a point directly left of center', () {
      expect(
        WheelMath.angleFromPosition(
          const Offset(100, 100),
          const Offset(50, 100),
        ),
        closeTo(pi, 1e-9),
      );
    });
  });
}
