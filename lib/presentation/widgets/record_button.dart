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
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: isRecording ? AppTheme.surface : AppTheme.recordRed,
          shape: BoxShape.circle,
          border: Border.all(
            color: isRecording ? AppTheme.recordRed : Colors.transparent,
            width: 4,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.recordRed.withValues(alpha: 0.35),
              blurRadius: 16,
              spreadRadius: isRecording ? 2 : 0,
            ),
          ],
        ),
        child: Center(
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: isRecording ? 26 : 30,
            height: isRecording ? 26 : 30,
            decoration: BoxDecoration(
              color: isRecording ? AppTheme.recordRed : Colors.white,
              borderRadius:
                  BorderRadius.circular(isRecording ? 6 : 30),
            ),
          ),
        ),
      ),
    );
  }
}
