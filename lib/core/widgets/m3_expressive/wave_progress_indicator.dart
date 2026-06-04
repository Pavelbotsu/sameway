import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Material 3 Expressive wave-form linear progress indicator.
///
/// Two modes:
///   - **determinate**: pass [value] in [0, 1]. The wave fills up to [value],
///     a tonal "remaining" track fills the rest, with a small notch gap
///     between them per the M3 spec.
///   - **indeterminate**: leave [value] null. A continuous sine wave travels
///     left-to-right, looping every [period].
///
/// The wave's vertical amplitude is reduced as `value` approaches 1.0 so the
/// indicator settles cleanly into a flat line on completion (matching the
/// reference behaviour of the Compose M3 implementation).
class WaveProgressIndicator extends StatefulWidget {
  final double? value;
  final double height;
  final double amplitude;
  final double wavelength;
  final Color? color;
  final Color? trackColor;
  final Duration period;

  const WaveProgressIndicator({
    super.key,
    this.value,
    this.height = 8,
    this.amplitude = 3,
    this.wavelength = 28,
    this.color,
    this.trackColor,
    this.period = const Duration(milliseconds: 1400),
  }) : assert(value == null || (value >= 0.0 && value <= 1.0));

  @override
  State<WaveProgressIndicator> createState() => _WaveProgressIndicatorState();
}

class _WaveProgressIndicatorState extends State<WaveProgressIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _phase;

  @override
  void initState() {
    super.initState();
    _phase = AnimationController(vsync: this, duration: widget.period)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant WaveProgressIndicator old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) {
      _phase
        ..duration = widget.period
        ..repeat();
    }
  }

  @override
  void dispose() {
    _phase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final color = widget.color ?? cs.primary;
    final track = widget.trackColor ?? cs.primary.withValues(alpha: 0.18);

    return SizedBox(
      height: widget.height + widget.amplitude * 2,
      width: double.infinity,
      child: AnimatedBuilder(
        animation: _phase,
        builder: (_, __) => CustomPaint(
          painter: _WavePainter(
            phase: _phase.value,
            value: widget.value,
            amplitude: widget.amplitude,
            wavelength: widget.wavelength,
            stroke: widget.height,
            color: color,
            track: track,
          ),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double phase; // 0..1 normalized
  final double? value;
  final double amplitude;
  final double wavelength;
  final double stroke;
  final Color color;
  final Color track;

  _WavePainter({
    required this.phase,
    required this.value,
    required this.amplitude,
    required this.wavelength,
    required this.stroke,
    required this.color,
    required this.track,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final centerY = size.height / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    // Damp amplitude as the bar approaches "full" to settle into a flat line.
    final v = value ?? 0.5;
    final endX = value == null ? size.width : size.width * v;
    final dampedAmp =
        value == null ? amplitude : amplitude * (1 - _smoothstep(0.85, 1.0, v));
    final notch = value == null ? 0.0 : 4.0;

    // Wave segment (active fill).
    final wave = Path();
    final offsetPx = phase * wavelength;
    for (double x = 0; x <= endX; x += 1) {
      final theta = (x + offsetPx) * 2 * math.pi / wavelength;
      final y = centerY + math.sin(theta) * dampedAmp;
      if (x == 0) {
        wave.moveTo(x, y);
      } else {
        wave.lineTo(x, y);
      }
    }
    paint.color = color;
    canvas.drawPath(wave, paint);

    // Determinate remaining track (with a small notch gap from the wave end).
    if (value != null && endX + notch < size.width) {
      paint.color = track;
      canvas.drawLine(
        Offset(endX + notch, centerY),
        Offset(size.width, centerY),
        paint,
      );
    }
  }

  static double _smoothstep(double a, double b, double x) {
    final t = ((x - a) / (b - a)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.phase != phase ||
      old.value != value ||
      old.amplitude != amplitude ||
      old.wavelength != wavelength ||
      old.color != color ||
      old.track != track ||
      old.stroke != stroke;
}
