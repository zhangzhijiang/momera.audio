import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/audio_playback_service.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/transcription_service.dart';
import '../../data/repositories/recording_repository.dart';

/// Filesystem store for recordings.
final recordingRepositoryProvider = Provider<RecordingRepository>((ref) {
  return RecordingRepository();
});

/// Microphone recorder.
final audioRecordingServiceProvider = Provider<AudioRecordingService>((ref) {
  final service = AudioRecordingService();
  ref.onDispose(service.dispose);
  return service;
});

/// Audio playback.
final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = AudioPlaybackService();
  ref.onDispose(service.dispose);
  return service;
});

/// Offline file transcription (SenseVoice + VAD).
final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  final service = TranscriptionService();
  ref.onDispose(service.dispose);
  return service;
});
