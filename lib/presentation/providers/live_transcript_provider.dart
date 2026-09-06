import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/live_transcription_service.dart';
import '../../core/services/transcription_service.dart';
import '../../core/translation/translator.dart';
import 'service_providers.dart';

/// One line of the live panel: what was heard, and optionally its translation.
@immutable
class LiveLine {
  const LiveLine({required this.segment, this.translation});

  final TranscriptSegment segment;
  final String? translation;

  LiveLine withTranslation(String value) =>
      LiveLine(segment: segment, translation: value);
}

/// Rolling live-transcript state.
@immutable
class LiveTranscriptState {
  const LiveTranscriptState({
    this.lines = const [],
    this.active = false,
    this.starting = false,
    this.translateTo,
    this.error,
  });

  /// Most recent first — the panel shows the newest line at the top so it does
  /// not have to auto-scroll while the user is holding a button.
  final List<LiveLine> lines;

  /// True while the user is holding the live button.
  final bool active;

  /// True between the press and the recogniser being ready.
  final bool starting;

  /// Target language for live translation, or null when it is off.
  final TranslationLanguage? translateTo;

  final String? error;

  bool get isEmpty => lines.isEmpty;

  LiveTranscriptState copyWith({
    List<LiveLine>? lines,
    bool? active,
    bool? starting,
    TranslationLanguage? translateTo,
    bool clearTranslateTo = false,
    String? error,
    bool clearError = false,
  }) {
    return LiveTranscriptState(
      lines: lines ?? this.lines,
      active: active ?? this.active,
      starting: starting ?? this.starting,
      translateTo: clearTranslateTo ? null : (translateTo ?? this.translateTo),
      error: clearError ? null : (error ?? this.error),
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
  Translator? _translator;

  @override
  LiveTranscriptState build() {
    ref.onDispose(() => _live?.dispose());
    return const LiveTranscriptState();
  }

  /// Begin a live pass. Returns false when it could not start — usually because
  /// the model is not downloaded, or a file transcription holds the recogniser.
  Future<bool> start({required int fromByteOffset}) async {
    if (state.active || state.starting) return true;
    state = state.copyWith(starting: true, clearError: true);

    final service = _live ??=
        LiveTranscriptionService(ref.read(transcriptionServiceProvider));

    final ok = await service.start(fromByteOffset: fromByteOffset);
    if (!ok) {
      state = state.copyWith(starting: false);
      return false;
    }

    state = state.copyWith(active: true, starting: false);
    return true;
  }

  /// Feed recorded audio. Safe to call when inactive — it does nothing.
  void feed(Uint8List pcm) {
    final service = _live;
    if (service == null || !state.active) return;

    final segments = service.feed(pcm);
    if (segments.isNotEmpty) _appendAll(segments);
  }

  /// End the live pass, keeping whatever text was produced on screen.
  void stop() {
    final service = _live;
    if (service == null) return;
    final trailing = service.stop();
    if (trailing.isNotEmpty) _appendAll(trailing);
    state = state.copyWith(active: false, starting: false);
  }

  /// Clear the panel, e.g. when a new recording starts.
  void reset() {
    stop();
    state = const LiveTranscriptState();
  }

  /// Turn live translation on (or off, with null) for the given target.
  ///
  /// The engine is resolved once here rather than per utterance: resolving it
  /// costs two or three platform round trips, which is wasteful once a phrase.
  Future<void> setTranslationTarget(TranslationLanguage? target) async {
    if (target == null) {
      _translator = null;
      state = state.copyWith(clearTranslateTo: true);
      return;
    }

    // ML Kit is preferred over Apple for live use even on iOS 18+: it caches
    // one native translator per language pair and reuses it, whereas the Apple
    // bridge mounts a fresh SwiftUI host and TranslationSession per call, which
    // would mean view-hierarchy churn on the main thread once per utterance.
    final engine = await ref
        .read(translationServiceProvider)
        .engineFor(target, preferReusable: true);
    _translator = engine;
    state = state.copyWith(translateTo: target, clearError: engine != null);
  }

  void _appendAll(List<TranscriptSegment> segments) {
    final next = [
      for (final segment in segments.reversed) LiveLine(segment: segment),
      ...state.lines,
    ];
    state = state.copyWith(
      lines: next.length > _maxLines ? next.sublist(0, _maxLines) : next,
    );
    final target = state.translateTo;
    if (target != null) {
      for (final segment in segments) {
        unawaited(_translateLine(segment, target));
      }
    }
  }

  /// Translate one utterance, using **that utterance's** detected language.
  ///
  /// Deliberately not `TranslationService.sourceFor`, which returns null as
  /// soon as a recording contains more than one language. Per segment the
  /// language is always singular, so live translation copes with a
  /// conversation that switches language — something the batch path refuses.
  Future<void> _translateLine(
    TranscriptSegment segment,
    TranslationLanguage target,
  ) async {
    final translator = _translator;
    final source = _sourceFor(segment.language);
    if (translator == null || source == null || source == target) return;
    // No on-device engine translates Cantonese; skip rather than route it
    // through Chinese and produce plausible but wrong text.
    if (source == TranslationLanguage.cantonese) return;

    try {
      final text =
          await translator.translate(segment.text, from: source, to: target);
      final updated = [
        for (final line in state.lines)
          identical(line.segment, segment) ? line.withTranslation(text) : line,
      ];
      state = state.copyWith(lines: updated);
    } catch (e) {
      debugPrint('Live translation failed: $e');
    }
  }

  static TranslationLanguage? _sourceFor(TranscriptionLanguage? detected) {
    switch (detected) {
      case TranscriptionLanguage.mandarin:
        return TranslationLanguage.chineseSimplified;
      case TranscriptionLanguage.cantonese:
        return TranslationLanguage.cantonese;
      case TranscriptionLanguage.english:
        return TranslationLanguage.english;
      case TranscriptionLanguage.japanese:
        return TranslationLanguage.japanese;
      case TranscriptionLanguage.korean:
        return TranslationLanguage.korean;
      case TranscriptionLanguage.auto:
      case null:
        return null;
    }
  }
}

final liveTranscriptProvider =
    NotifierProvider<LiveTranscriptNotifier, LiveTranscriptState>(
  LiveTranscriptNotifier.new,
);
