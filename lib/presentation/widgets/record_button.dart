import 'package:flutter/material.dart';

import '../../core/utils/app_theme.dart';

/// Large circular record / stop control shown at the bottom of the home screen.
class RecordButton extends StatelessWidget {
  const RecordButton({
    super.key,
    required this.isRecording,
    required this.onTap,
  });

  final bool isRecording;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: isRecording ? colors.surface : colors.recordRed,
          shape: BoxShape.circle,
          border: Border.all(
            color: isRecording ? colors.recordRed : Colors.transparent,
            width: 5,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.recordRed.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: isRecording ? 2 : 0,
            ),
          ],
        ),
        // A microphone at rest says what the button captures; a square while
        // recording says what tapping it does now. Deliberately not a mic in
        // both states — the stop affordance is the more useful thing to show
        // once recording is already under way.
        child: Center(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(scale: animation, child: child),
            ),
            child: isRecording
                ? Container(
                    key: const ValueKey('stop'),
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: colors.recordRed,
                      borderRadius: BorderRadius.circular(8),
                    ),
                  )
                : const Icon(
                    Icons.mic_rounded,
                    key: ValueKey('mic'),
                    color: Colors.white,
                    size: 40,
                  ),
          ),
        ),
      ),
    );
  }
}
