import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/recording.dart';
import 'service_providers.dart';

/// The list of saved recordings, newest first. Reloads from disk via [refresh].
class RecordingsNotifier extends AsyncNotifier<List<Recording>> {
  @override
  Future<List<Recording>> build() async {
    // Any `.pcm` left in the recordings directory is a recording that was
    // interrupted by a crash, a force quit or the battery dying. Finalise those
    // into playable `.wav` files before listing, so the audio that was already
    // flushed to disk is never lost.
    await ref.read(audioRecordingServiceProvider).recoverInterrupted();
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

  /// Save a transcript for [recording] and update it in place.
  Future<void> setTranscript(Recording recording, String transcript) async {
    await ref
        .read(recordingRepositoryProvider)
        .saveTranscript(recording.path, transcript);
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncData([
      for (final r in current)
        r.path == recording.path ? r.copyWith(transcript: transcript) : r,
    ]);
  }
}

final recordingsProvider =
    AsyncNotifierProvider<RecordingsNotifier, List<Recording>>(
  RecordingsNotifier.new,
);
