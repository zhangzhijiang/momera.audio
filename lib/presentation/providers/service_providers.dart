import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/capabilities/device_capability_service.dart';
import '../../core/services/audio_playback_service.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/services/transcription_service.dart';
import '../../core/services/waveform_service.dart';
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

/// Whether a recording is in progress right now.
///
/// The recorder itself is not listenable, and `_HomeScreenState` cannot be
/// reached from a tile several screens away — but every recording tile, on the
/// home list and in History alike, has to know: playback is blocked while
/// capturing. On iOS `just_audio` activates its own `.playback` audio session,
/// which would take the session away from the recorder mid-recording; on
/// Android the speaker simply bleeds into the microphone. Kept in sync by the
/// home screen, which owns the recorder.
final isRecordingProvider = StateProvider<bool>((ref) => false);

/// Audio playback.
final audioPlaybackServiceProvider = Provider<AudioPlaybackService>((ref) {
  final service = AudioPlaybackService();
  ref.onDispose(service.dispose);
  return service;
});

/// What this device can actually run.
///
/// Recording is the baseline every device gets; transcription is offered only
/// where it works. See [DeviceCapabilityService].
final deviceCapabilityServiceProvider = Provider<DeviceCapabilityService>((ref) {
  return DeviceCapabilityService();
});

/// Offline file transcription (SenseVoice + VAD).
final transcriptionServiceProvider = Provider<TranscriptionService>((ref) {
  final service = TranscriptionService(
    capabilities: ref.read(deviceCapabilityServiceProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});


/// Waveform peaks for the recordings list.
final waveformServiceProvider = Provider<WaveformService>((ref) {
  return WaveformService();
});
