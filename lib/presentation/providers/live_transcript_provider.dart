import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/live_transcription_service.dart';
import '../../core/services/transcription_service.dart';
import 'service_providers.dart';

/// One line of the live panel: what was heard.
@immutable
class LiveLine {
  const LiveLine({required this.segment});

  final TranscriptSegment segment;
}

/// Rolling live-transcript state.
@immutable
class LiveTranscriptState {
  const LiveTranscriptState({
    this.lines = const [],
    this.active = false,
    this.starting = false,
    this.dismissed = false,
  });

  /// Most recent first — the panel shows the newest line at the top so it does
  /// not have to auto-scroll while the user is holding a button.
  final List<LiveLine> lines;

  /// True while the user is holding the live button.
  final bool active;

  /// True between the press and the recogniser being ready.
  final bool starting;

  /// The user closed the panel. Purely presentational — the live pass is
  /// bounded by the held button, not by whether the panel is on screen.
  final bool dismissed;

  bool get isEmpty => lines.isEmpty;

  LiveTranscriptState copyWith({
    List<LiveLine>? lines,
    bool? active,
    bool? starting,
    bool? dismissed,
  }) {
    return LiveTranscriptState(
      lines: lines ?? this.lines,
      active: active ?? this.active,
      starting: starting ?? this.starting,
      dismissed: dismissed ?? this.dismissed,
    );
  }
}

/// Drives live transcription while the user holds the live button.
///
/// Kept in a provider rather than in `_HomeScreenState` so the transcript is
/// not lost when the user navigates to Settings and back mid-recording.
class LiveTranscriptNotifier extends Notifier<LiveTranscriptState> {
  /// How many lines to keep. This is a preview, not a transcript — the full
  /// text comes from the post-recording pass — so old lines are dropped rather
  /// than growing without bound during a long recording.
  static const int _maxLines = 40;

  LiveTranscriptionService? _live;

  /// Bumped every time the panel is cleared.
  ///
  /// Decodes are asynchronous now, so an utterance submitted before a [reset]
  /// can land after it. Without this guard the panel would repopulate itself
  /// with the previous recording's last phrase.
  int _generation = 0;

  @override
  LiveTranscriptState build() {
    ref.onDispose(() => _live?.dispose());
    return const LiveTranscriptState();
  }

  /// Begin a live pass. Returns false when it could not start — usually because
  /// the model is not downloaded, or a file transcription holds the recogniser.
  Future<bool> start({
    required int fromByteOffset,
    TranscriptionLanguage language = TranscriptionLanguage.auto,
  }) async {
    if (state.active || state.starting) return true;
    state = state.copyWith(starting: true);

    final service = _live ??=
        LiveTranscriptionService(ref.read(transcriptionServiceProvider));

    final ok = await service.start(
      fromByteOffset: fromByteOffset,
      language: language,
    );
    if (!ok) {
      state = state.copyWith(starting: false);
      return false;
    }

    state = state.copyWith(active: true, starting: false);
    return true;
  }

  /// Feed recorded audio. Safe to call when inactive — it does nothing.
  ///
  /// Deliberately returns void and does not await the decode: this runs inside
  /// the recorder's audio-chunk handler, so it has to hand control straight
  /// back. Lines appear when the worker isolate answers.
  void feed(Uint8List pcm) {
    final service = _live;
    if (service == null || !state.active) return;
    unawaited(_collect(service.feed(pcm)));
  }

  /// End the live pass, keeping whatever text was produced on screen.
  void stop() {
    final service = _live;
    if (service == null) return;
    state = state.copyWith(active: false, starting: false);
    // Trailing speech still has to be decoded; the panel fills in when it lands.
    unawaited(_collect(service.stop()));
  }

  /// Hide the panel without touching the transcript or the live pass.
  ///
  /// This is the verb the API was missing. [reset] over-clears — it wipes the
  /// panel's lines. [stop] under-clears — it kills a pass the held finger
  /// already bounds. Closing a panel is neither.
  void dismissPanel() => state = state.copyWith(dismissed: true);

  /// Bring the panel back.
  void showPanel() => state = state.copyWith(dismissed: false);

  /// Clear the panel, e.g. when a new recording starts.
  void reset() {
    _generation++;
    // Drain the pass and discard whatever comes back: any trailing utterance
    // belongs to the recording that just ended, not the one starting now.
    unawaited(_live?.stop().catchError((_) => const <TranscriptSegment>[]));
    // A fresh const state also clears `dismissed`, so a panel closed during one
    // recording comes back for the next without a separate un-set.
    state = const LiveTranscriptState();
  }

  /// Append segments once they finish decoding, unless the panel was cleared
  /// while they were in flight.
  Future<void> _collect(Future<List<TranscriptSegment>> pending) async {
    final generation = _generation;
    try {
      final segments = await pending;
      if (segments.isEmpty || generation != _generation) return;
      _appendAll(segments);
    } catch (e) {
      debugPrint('Live transcription: dropped a phrase: $e');
    }
  }

  void _appendAll(List<TranscriptSegment> segments) {
    final next = [
      for (final segment in segments.reversed) LiveLine(segment: segment),
      ...state.lines,
    ];
    state = state.copyWith(
      lines: next.length > _maxLines ? next.sublist(0, _maxLines) : next,
    );
  }

}

final liveTranscriptProvider =
    NotifierProvider<LiveTranscriptNotifier, LiveTranscriptState>(
  LiveTranscriptNotifier.new,
);
