import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

/// The Momera mark, painted rather than drawn from a PNG so its bars can move.
///
/// Every constant below was measured off `assets/icon/momera_recording_logo.png`
/// and is normalised to the mark's **width**, with the origin at the top-left of
/// its bounding box — the same box the iOS `LaunchImage` PNGs are cropped to. At
/// [blend] `0` this paints that artwork exactly, which is what lets the native
/// launch screen hand over to Flutter without a visible jump. Regenerate the
/// source assets with `tool/icon/extract_mark.py`.
///
/// The five bars are stadium shapes (corner radius = half width) sitting on a
/// common axis, with a round-capped arc cradling them.
const double _kAspect = 0.87675;
const _kCx = <double>[0.06513, 0.24265, 0.50000, 0.75735, 0.93487];
const _kW = <double>[0.12185, 0.12255, 0.28291, 0.12255, 0.12185];
const _kCy = <double>[0.37045, 0.34804, 0.34734, 0.34804, 0.37045];

/// Bar heights in the resting pose — i.e. the logo itself.
const _kH = <double>[0.25630, 0.42157, 0.68627, 0.42157, 0.25630];

const double _kArcCx = 0.49748;
const double _kArcCy = 0.53459;
const double _kArcR = 0.29104;
const double _kArcStroke = 0.09384;
const double _kArcStartDeg = 27.1;
const double _kArcSweepDeg = 125.8;

/// The arc's own bounding band, used to place its gradient.
///
/// `_kArcCy + _kArcR + _kArcStroke / 2 == _kAspect` — the arc's outer edge is
/// the bottom of the mark. If you retune the arc and that identity breaks, it
/// has left the baseline.
const double _kArcGradTop = 0.62024;
const double _kArcGradBottom = 0.87255;

/// One vertical gradient shared by all five bars, spanning the whole mark.
///
/// Deliberately global rather than per bar: sampling the source art shows the
/// same y is the same colour in every bar, so a short bar shows only the slice
/// of the ramp it occupies. Giving each bar its own copy of the full ramp would
/// make the short ones far more saturated than the artwork.
const Color _kBarTop = Color(0xFF1EB8FE);
const Color _kBarBottom = Color(0xFFBD18F8);

/// The arc carries a separate, much shallower ramp — it does not continue the
/// bars' gradient, which by its y would already be deep magenta.
const Color _kArcTop = Color(0xFF4A73FC);
const Color _kArcBottom = Color(0xFF8C5FF6);

/// Equalizer travel. Bars grow about their own fixed centre so the mark's
/// optical centre never drifts away from the native launch image.
///
/// The maxima are bounded by collision, not taste: the arc's highest point is
/// y `0.62024`, right under the two medium bars, and the centre bar's resting
/// pose already touches the top of the box. Raising these will punch a bar
/// through the arc or clip it at the top edge.
const _kEqMin = <double>[0.13, 0.16, 0.30, 0.16, 0.13];
const _kEqMax = <double>[0.44, 0.52, 0.68, 0.52, 0.44];

/// Integers only — a non-integer frequency does not complete a whole number of
/// cycles per period, so the repeating clock visibly jumps as it wraps.
const _kFreq = <double>[2, 3, 1, 3, 2];
const _kPhase = <double>[0.00, 0.37, 0.68, 0.12, 0.55];

/// The logo mark, optionally animating as an equalizer.
class AnimatedLogoMark extends StatelessWidget {
  const AnimatedLogoMark({
    super.key,
    required this.pulse,
    required this.blend,
    required this.width,
  });

  /// Free-running 0→1 clock driving the equalizer.
  final Animation<double> pulse;

  /// 0 paints the logo exactly; 1 paints the equalizer.
  final Animation<double> blend;

  final double width;

  /// Height as a fraction of width. Callers laying the mark out by hand need
  /// this to reserve the right box.
  static const double aspectRatio = _kAspect;

  @override
  Widget build(BuildContext context) {
    final size = Size(width, width * _kAspect);
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: Listenable.merge([pulse, blend]),
        builder: (context, child) => CustomPaint(
          size: size,
          painter: _MarkPainter(pulse: pulse.value, blend: blend.value),
        ),
      ),
    );
  }
}

double _eqHeight(int i, double t) {
  final phase = 0.5 + 0.5 * math.sin(2 * math.pi * (_kFreq[i] * t + _kPhase[i]));
  return _kEqMin[i] + (_kEqMax[i] - _kEqMin[i]) * phase;
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({required this.pulse, required this.blend});

  final double pulse;
  final double blend;

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width;

    final bars = Paint()
      ..isAntiAlias = true
      ..shader = ui.Gradient.linear(
        Offset.zero,
        Offset(0, _kAspect * u),
        const [_kBarTop, _kBarBottom],
      );

    for (var i = 0; i < 5; i++) {
      final h = ui.lerpDouble(_kH[i], _eqHeight(i, pulse), blend)!;
      final w = _kW[i] * u;
      final rect = Rect.fromCenter(
        center: Offset(_kCx[i] * u, _kCy[i] * u),
        width: w,
        // Never shorter than it is wide, so a bar bottoms out as a circle
        // rather than collapsing into a sliver.
        height: math.max(h * u, w),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(w / 2)),
        bars,
      );
    }

    // Static: the arc is part of the mark's identity and must be identical in
    // frame 0 to the native launch image. Animating it adds a way for that to
    // drift out of sync for no expressive gain.
    final arc = Paint()
      ..isAntiAlias = true
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _kArcStroke * u
      ..shader = ui.Gradient.linear(
        Offset(0, _kArcGradTop * u),
        Offset(0, _kArcGradBottom * u),
        const [_kArcTop, _kArcBottom],
      );
    canvas.drawArc(
      Rect.fromCircle(
        center: Offset(_kArcCx * u, _kArcCy * u),
        radius: _kArcR * u,
      ),
      _kArcStartDeg * math.pi / 180,
      _kArcSweepDeg * math.pi / 180,
      false,
      arc,
    );
  }

  @override
  bool shouldRepaint(_MarkPainter oldDelegate) =>
      oldDelegate.pulse != pulse || oldDelegate.blend != blend;
}
