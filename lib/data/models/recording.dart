import 'package:path/path.dart' as p;

import '../../core/services/transcription_service.dart';

/// A single saved audio recording on disk, plus its optional transcript.
///
/// Recordings are stored as 16 kHz mono WAV files in the app's `recordings`
/// directory. The transcript (once the user runs speech-to-text on the file)
/// is persisted as a sibling `<name>.txt` sidecar — see [RecordingRepository].
class Recording {
  /// Absolute path to the `.wav` audio file.
  final String path;

  /// When the recording was created (parsed from the filename timestamp, with
  /// the file's modified time as a fallback).
  final DateTime createdAt;

  /// On-disk size of the audio file, in bytes.
  final int sizeBytes;

  /// Playback duration. Computed cheaply from the WAV byte length for our fixed
  /// 16 kHz / mono / PCM16 format; null if it could not be determined.
  final Duration? duration;

  /// Transcribed text, or null if the file has not been transcribed yet.
  final String? transcript;

  /// Languages the recogniser detected while transcribing, in first-seen
  /// order. More than one means the speakers switched language mid-recording.
  /// Empty when the recording has no transcript, or was transcribed before
  /// languages were recorded.
  final List<TranscriptionLanguage> languages;

  const Recording({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
    this.duration,
    this.transcript,
    this.languages = const [],
  });

  /// File name including extension, e.g. `recording_20260620_143000.wav`.
  String get fileName => p.basename(path);

  /// File name without its extension.
  String get baseName => p.basenameWithoutExtension(path);

  /// Matches the auto-generated `recording_yyyyMMdd_HHmmss` form.
  static final RegExp _defaultNamePattern =
      RegExp(r'^recording_\d{8}_\d{6}$');

  /// The user-chosen name, or null when the file still has its generated one.
  ///
  /// Lets the UI show a name the user picked while continuing to show the
  /// timestamp for recordings that were never renamed — a generated filename
  /// is noise, not a title.
  String? get customName =>
      _defaultNamePattern.hasMatch(baseName) ? null : baseName;

  /// Whether a non-empty transcript has been saved for this recording.
  bool get hasTranscript =>
      transcript != null && transcript!.trim().isNotEmpty;

  /// True when speakers used more than one language in this recording.
  bool get isMultilingual => languages.length > 1;

  Recording copyWith({
    String? path,
    Duration? duration,
    String? transcript,
    List<TranscriptionLanguage>? languages,
  }) {
    return Recording(
      path: path ?? this.path,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
      duration: duration ?? this.duration,
      transcript: transcript ?? this.transcript,
      languages: languages ?? this.languages,
    );
  }
}
