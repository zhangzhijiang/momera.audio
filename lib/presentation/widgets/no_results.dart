import 'package:flutter/material.dart';

import '../../core/utils/app_theme.dart';

/// "Nothing matches that" state for a searched recording list.
///
/// [hint] carries the reason the search may have missed — which differs by
/// screen, since the home list only searches today while History searches the
/// whole archive.
class NoResults extends StatelessWidget {
  const NoResults({super.key, required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    // A search is typed with the keyboard up, which on a short screen can leave
    // this pane shorter than the message itself. Scrolling instead of
    // overflowing keeps the hint reachable — and the hint is the point, since
    // it explains the most likely reason for the miss. The minimum height keeps
    // the block centred whenever there is room for it.
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.search_off_rounded,
                      size: 48, color: colors.textHint),
                  const SizedBox(height: 12),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    hint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 12, color: colors.textHint),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
