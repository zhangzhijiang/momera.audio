import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/audio/waveform.dart';
import '../../core/utils/app_theme.dart';

/// A recording's waveform, filled up to the current playback position.
///
/// The strip always spans the available width and represents the *whole*
/// recording; how long that recording is comes from the duration printed beside
/// it, not from the bar's physical length. Scaling width by duration was
/// considered and rejected — it would make a three-second memo a stub too small
/// to scrub and give a two-hour recording no room to be any longer.
class WaveformBar extends StatelessWidget {
  const WaveformBar({
    super.key,
    required this.peaks,
    required this.progress,
    this.height = 36,
  });

  /// Null while the peaks are still being computed, or if they could not be.
  /// Either way the painter draws a flat baseline, so nothing jumps when data
  /// arrives and nothing shouts when it never does.
  final PeakData? peaks;

  /// Played fraction, 0–1.
  final double progress;

  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _WaveformPainter(
          peaks: peaks,
          progress: progress.clamp(0.0, 1.0),
          // A painter has no BuildContext, so the palette is handed to it.
          colors: AppTheme.of(context),
        ),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  _WaveformPainter({
    required this.peaks,
    required this.progress,
    required this.colors,
  });

  final AppColors colors;

  final PeakData? peaks;
  final double progress;

  /// One bar every 3 dp: 2 dp of bar, 1 dp of gap.
  static const double _pitch = 3;
  static const double _barWidth = 2;

  /// Silence still reads as a line rather than nothing at all.
  static const double _minBarHeight = 2;

  @override
  void paint(Canvas canvas, Size size) {
    final barCount = math.max(1, size.width ~/ _pitch);
    final values = peaks?.values;
    final playedBars = (barCount * progress).round();

    final played = Paint()
      ..color = colors.accent
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _barWidth;
    final unplayed = Paint()
      ..color = colors.borderLight
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _barWidth;

    final centre = size.height / 2;

    for (var i = 0; i < barCount; i++) {
      final amplitude = values == null ? 0.0 : _amplitudeAt(values, i, barCount);
      // Display curve lives here, never in the stored bytes: speech peaks sit
      // low, and lifting them is a look that may want retuning later without
      // invalidating every cached file on every device.
      final shaped = math.pow(amplitude, 0.7).toDouble();
      final barHeight =
          math.max(_minBarHeight, shaped * (size.height - _minBarHeight));

      final x = i * _pitch + _barWidth / 2;
      canvas.drawLine(
        Offset(x, centre - barHeight / 2),
        Offset(x, centre + barHeight / 2),
        i < playedBars ? played : unplayed,
      );
    }
  }

  /// Peak for bar [i], taking the loudest stored bucket it covers.
  ///
  /// Group-max rather than sampling one bucket: a quiet bucket next to a loud
  /// one would otherwise make the bar flicker as the width changes.
  double _amplitudeAt(Uint8List values, int i, int barCount) {
    final from = i * values.length ~/ barCount;
    final to = math.max(from + 1, (i + 1) * values.length ~/ barCount);
    var peak = 0;
    for (var b = from; b < to && b < values.length; b++) {
      if (values[b] > peak) peak = values[b];
    }
    return peak / 255.0;
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress ||
      !identical(old.peaks, peaks) ||
      // Switching theme repaints every waveform on screen.
      old.colors != colors;
}
