import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/transcription_service.dart';
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
    // Look the entry up by path rather than trusting the handle the caller
    // captured before a multi-second transcription: it may since have had its
    // transcript removed, and writing here would recreate the sidecar the user
    // just deleted.
    final current = state.valueOrNull;
    if (current == null) return;
    final live = _byPath(current, recording.path);
    if (live == null) return;

    await ref.read(recordingRepositoryProvider).saveTranscript(
          recording.path,
          transcript,
          languages: languages,
          segments: segments,
        );
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

  /// The current entry for [path], or null if it is gone.
  Recording? _byPath(List<Recording> recordings, String path) {
    for (final r in recordings) {
      if (r.path == path) return r;
    }
    return null;
  }

  /// Delete a recording's transcript, keeping the audio.
  ///
  /// Mutates in place rather than calling [refresh]: an `AsyncLoading` flash
  /// would re-sort the list and blink the very tile the user just acted on.
  Future<void> removeTranscript(Recording recording) async {
    await ref.read(recordingRepositoryProvider).removeTranscript(recording.path);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final r in current)
        r.path == recording.path ? r.copyWith(clearTranscript: true) : r,
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

/// The recordings made today, newest first.
///
/// "Today" is the device's local calendar day, not the last 24 hours: a
/// recording made last night is yesterday's the moment midnight passes, which
/// is what a person means by the word. The home screen shows exactly this list;
/// everything else is reached through History.
///
/// [now] is injectable so the boundary can be tested without waiting for
/// midnight.
List<Recording> recordedToday(List<Recording> all, {DateTime? now}) {
  final today = now ?? DateTime.now();
  return [
    for (final r in all)
      if (isSameDay(r.createdAt, today)) r,
  ];
}

/// Whether two local timestamps fall on the same calendar day.
bool isSameDay(DateTime a, DateTime b) =>
    a.year == b.year && a.month == b.month && a.day == b.day;
