import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(liveTranscriptProvider);

    return Container(
      constraints: const BoxConstraints(maxHeight: _maxHeight),
      width: double.infinity,
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderLight)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(
            state: state,
            l10n: l10n,
            // Closing also explains how to get it back: the hold button
            // carries no label of its own, and this header was the affordance.
            onClose: () {
              ref.read(liveTranscriptProvider.notifier).dismissPanel();
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(l10n.livePanelHidden)),
              );
            },
          ),
          Flexible(
            child: state.isEmpty
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Text(
                      state.active ? l10n.liveListening : l10n.liveEmpty,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.textHint,
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
  const _Header({
    required this.state,
    required this.l10n,
    required this.onClose,
  });

  final LiveTranscriptState state;
  final AppLocalizations l10n;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
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
            color: state.active ? colors.accent : colors.textHint,
          ),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.4,
              color: state.active ? colors.accent : colors.textHint,
            ),
          ),
          const Spacer(),
          // Without this the panel has no way out: releasing the hold button
          // stops the pass but deliberately keeps the text on screen, so the
          // last phrases stay readable — which left the panel there for the
          // rest of the recording. Closing is the missing half of that.
          IconButton(
            icon: const Icon(Icons.close_rounded),
            iconSize: 16,
            color: colors.textHint,
            tooltip: l10n.hideLiveText,
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 28, height: 28),
            onPressed: onClose,
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
    final colors = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        line.segment.text,
        style: TextStyle(
          fontSize: 14,
          height: 1.35,
          color: colors.textPrimary,
        ),
      ),
    );
  }
}
