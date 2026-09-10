import 'package:flutter/material.dart';

import '../../core/utils/app_theme.dart';

/// The skip-silence toggle, pinned to the top right of the record panel.
///
/// Fixed there rather than in the row of round buttons: that row grows and
/// shrinks as pause and hold-for-live-text appear, so a control inside it would
/// move under the thumb. The panel's top-right corner does not move, and the
/// timer stays centred on the record button because the two are stacked, not
/// laid out side by side.
///
/// Icon only, so the state has to be carried by colour: accent on a filled disc
/// when on, plain grey when off. The tooltip and the popup shown on toggle carry
/// the words.
class SkipSilenceButton extends StatelessWidget {
  const SkipSilenceButton({
    super.key,
    required this.enabled,
    required this.tooltip,
    required this.onTap,
  });

  final bool enabled;

  /// Names the control for the tooltip and for screen readers, since nothing on
  /// screen says what the icon means.
  final String tooltip;

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);

    return Semantics(
      button: true,
      toggled: enabled,
      label: tooltip,
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkResponse(
            onTap: onTap,
            radius: 22,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: enabled ? colors.accentLight : Colors.transparent,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: CustomPaint(
                  size: const Size(22, 18),
                  painter: _SkipSilenceIcon(
                    color: enabled ? colors.accent : colors.textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A burst of sound, a skipped silence, a burst of sound.
///
/// Drawn rather than picked from the Material set, because the set has no glyph
/// for this. The obvious candidates are all wrong in a specific way: a crossed
/// speaker reads as "the microphone is muted" — close to the opposite of what
/// this does — and scissors or fast-forward describe editing and playback, not
/// what is being captured. Sound, silence, sound is the thing itself.
///
/// The bars step *down* towards the middle and back up out of it, so the shape
/// falls into the gap and rises out of it the way a waveform does. Two dots
/// stand in the gap rather than a line: dots read as an elision — something
/// left out — where a line joining the tall bars turned the whole glyph into a
/// dumbbell.
class _SkipSilenceIcon extends CustomPainter {
  const _SkipSilenceIcon({required this.color});

  final Color color;

  /// Half-heights as a fraction of the icon, outermost first on each side.
  static const double _tall = 0.92;
  static const double _short = 0.44;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.height / 2;
    final bar = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 2.1
      ..style = PaintingStyle.stroke;

    // Two bars a side, with a third of the width left empty between them so the
    // gap reads as a pause rather than as spacing.
    final step = size.width / 10;
    const heights = [_tall, _short, _short, _tall];
    final xs = [step * 0.9, step * 3.1, step * 6.9, step * 9.1];

    for (var i = 0; i < xs.length; i++) {
      final half = heights[i] * centre;
      canvas.drawLine(
        Offset(xs[i], centre - half),
        Offset(xs[i], centre + half),
        bar,
      );
    }

    // The silence, elided. One dot rather than an ellipsis of them: at the size
    // this is actually drawn, two dots merge into a blob.
    canvas.drawCircle(
      Offset(size.width / 2, centre),
      1.15,
      Paint()..color = color.withValues(alpha: 0.6),
    );
  }

  @override
  bool shouldRepaint(_SkipSilenceIcon old) => old.color != color;
}
