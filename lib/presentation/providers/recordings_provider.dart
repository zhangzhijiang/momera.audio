import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/transcription_service.dart';
import '../../core/translation/translation_service.dart';
import '../../data/models/recording.dart';
import 'service_providers.dart';

/// Number of recordings recovered at startup after an interrupted session.
///
/// Read once by the home screen so the user is told why an unfamiliar recording
/// appeared, rather than finding it silently. Reset to 0 after being shown.
final recoveredCountProvider = StateProvider<int>((ref) => 0);

/// The list of saved recordings, newest first. Reloads from disk via [refresh].
class RecordingsNotifier extends AsyncNotifier<List<Recording>> {
  @override
  Future<List<Recording>> build() async {
    // Any `.pcm` left in the recordings directory is a recording that was
    // interrupted by a crash, a force quit or the battery dying. Finalise those
    // into playable `.wav` files before listing, so the audio that was already
    // flushed to disk is never lost.
    final recovered =
        await ref.read(audioRecordingServiceProvider).recoverInterrupted();
    if (recovered.isNotEmpty) {
      ref.read(recoveredCountProvider.notifier).state = recovered.length;
    }
    return ref.read(recordingRepositoryProvider).list();
  }

  /// Re-scan the recordings directory (e.g. after a new recording is saved).
  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(recordingRepositoryProvider).list(),
    );
  }

  Future<void> delete(Recording recording) async {
    await ref.read(recordingRepositoryProvider).delete(recording);
    await refresh();
  }

  /// Save a transcript for [recording], with the languages detected while
  /// producing it, and update the entry in place.
  Future<void> setTranscript(
    Recording recording,
    String transcript, {
    List<TranscriptionLanguage> languages = const [],
    List<TranscriptSegment> segments = const [],
  }) async {
    await ref.read(recordingRepositoryProvider).saveTranscript(
          recording.path,
          transcript,
          languages: languages,
          segments: segments,
        );
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final r in current)
        r.path == recording.path
            ? r.copyWith(
                transcript: transcript,
                languages: languages,
                segments: segments,
              )
            : r,
    ]);
  }

  /// Store a translation alongside the transcript and update it in place.
  Future<void> addTranslation(
    Recording recording,
    TranslationOutcome outcome,
  ) async {
    final merged = {...recording.translations, outcome.language: outcome};
    await ref.read(recordingRepositoryProvider).saveTranscript(
          recording.path,
          recording.transcript ?? '',
          languages: recording.languages,
          segments: recording.segments,
          translations: merged,
        );
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final r in current)
        r.path == recording.path ? r.copyWith(translations: merged) : r,
    ]);
  }

  /// Rename [recording] and refresh, so the list re-sorts and picks up the new
  /// filename.
  Future<void> rename(Recording recording, String newBaseName) async {
    await ref.read(recordingRepositoryProvider).rename(recording, newBaseName);
    await refresh();
  }
}

final recordingsProvider =
    AsyncNotifierProvider<RecordingsNotifier, List<Recording>>(
  RecordingsNotifier.new,
);
