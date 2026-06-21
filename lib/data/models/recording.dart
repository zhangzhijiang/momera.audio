import 'package:path/path.dart' as p;

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

  const Recording({
    required this.path,
    required this.createdAt,
    required this.sizeBytes,
    this.duration,
    this.transcript,
  });

  /// File name including extension, e.g. `recording_20260620_143000.wav`.
  String get fileName => p.basename(path);

  /// Whether a non-empty transcript has been saved for this recording.
  bool get hasTranscript =>
      transcript != null && transcript!.trim().isNotEmpty;

  Recording copyWith({
    Duration? duration,
    String? transcript,
  }) {
    return Recording(
      path: path,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
      duration: duration ?? this.duration,
      transcript: transcript ?? this.transcript,
    );
  }
}
