import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/translation/translator.dart';
import '../../core/utils/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../providers/live_transcript_provider.dart';

/// Rolling live transcript shown while recording.
///
/// A leaf `Consumer` on purpose. The home screen's one-second elapsed timer
/// calls `setState` on the whole screen — which rebuilds the recordings list
/// and re-runs the search — so this panel watches its own provider instead, and
/// a new utterance rebuilds only this subtree.
class LiveTranscriptPanel extends ConsumerWidget {
  const LiveTranscriptPanel({super.key});

  /// Tall enough for a few phrases without crowding out the recordings list.
  static const double _maxHeight = 190;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(liveTranscriptProvider);

    return Container(
      constraints: const BoxConstraints(maxHeight: _maxHeight),
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(state: state, l10n: l10n),
          Flexible(
            child: state.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Text(
                      state.active ? l10n.liveListening : l10n.liveEmpty,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textHint,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    // Newest first, so the panel never has to auto-scroll while
                    // the user is holding a button with their thumb over it.
                    itemCount: state.lines.length,
                    itemBuilder: (context, i) => _Line(line: state.lines[i]),
                  ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state, required this.l10n});

  final LiveTranscriptState state;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final String label;
    if (state.starting) {
      label = l10n.liveStarting;
    } else if (state.active) {
      label = l10n.liveListening;
    } else {
      label = l10n.liveHold;
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
      child: Row(
        children: [
          Icon(
            state.active ? Icons.graphic_eq_rounded : Icons.subtitles_outlined,
            size: 14,
            color: state.active ? AppTheme.accent : AppTheme.textHint,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: state.active ? AppTheme.accent : AppTheme.textHint,
            ),
          ),
          const Spacer(),
          if (state.translateTo != null)
            Text(
              translationLanguageLabel(l10n, state.translateTo!),
              style: const TextStyle(fontSize: 11, color: AppTheme.textHint),
            ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.line});

  final LiveLine line;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            line.segment.text,
            style: const TextStyle(
              fontSize: 14,
              height: 1.35,
              color: AppTheme.textPrimary,
            ),
          ),
          // The translated line sits under its source, so a bilingual
          // conversation reads as pairs rather than as two separate columns.
          if (line.translation != null) ...[
            const SizedBox(height: 2),
            Text(
              line.translation!,
              style: const TextStyle(
                fontSize: 13,
                height: 1.35,
                color: AppTheme.accent,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
