import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/services/transcription_service.dart';
import '../../core/translation/translation_service.dart';
import '../../core/translation/translator.dart';
import '../models/recording.dart';

/// Filesystem-backed store for [Recording]s.
///
/// There is no database: each recording is just a `.wav` file in the app's
/// `recordings` directory, and its transcript (if any) is a sibling `.txt`
/// sidecar with the same base name. Listing scans the directory; metadata such
/// as duration is derived from the WAV byte length.
class RecordingRepository {
  static const String _dirName = 'recordings';

  /// WAV format we record in — kept in sync with [AudioRecordingService].
  static const int _sampleRate = 16000;
  static const int _bytesPerSample = 2; // PCM16
  static const int _channels = 1;
  static const int _wavHeaderBytes = 44;

  Directory? _cachedDir;

  /// The directory that holds all recordings, creating it on first access.
  Future<Directory> directory() async {
    if (_cachedDir != null) return _cachedDir!;
    final appDir = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(appDir.path, _dirName));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return _cachedDir = dir;
  }

  /// All recordings, newest first.
  Future<List<Recording>> list() async {
    final dir = await directory();
    final entries = await dir.list().toList();

    final recordings = <Recording>[];
    for (final entry in entries) {
      if (entry is! File) continue;
      if (p.extension(entry.path).toLowerCase() != '.wav') continue;

      final stat = await entry.stat();
      final sidecar = await _readTranscript(entry.path);
      recordings.add(
        Recording(
          path: entry.path,
          createdAt: _parseTimestamp(entry.path) ?? stat.modified,
          sizeBytes: stat.size,
          duration: _durationForWavBytes(stat.size),
          transcript: sidecar?.text,
          languages: sidecar?.languages ?? const [],
          segments: sidecar?.segments ?? const [],
          translations: sidecar?.translations ?? const {},
        ),
      );
    }

    recordings.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return recordings;
  }

  /// Total bytes occupied by recordings and their transcript sidecars.
  ///
  /// Used to enforce the storage cap from settings, and to show usage on the
  /// settings screen.
  Future<int> totalBytes() async {
    final dir = await directory();
    var total = 0;
    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      total += await entry.length();
    }
    // Note: this deliberately counts an in-progress `.pcm` too, so the storage
    // cap accounts for audio being written right now.
    return total;
  }

  /// Rename a recording, moving its transcript sidecar with it.
  ///
  /// [newBaseName] is a display name without an extension. Returns the new
  /// `.wav` path.
  ///
  /// Throws [RenameCollisionException] if the target already exists — silently
  /// overwriting would destroy another recording.
  Future<String> rename(Recording recording, String newBaseName) async {
    final sanitized = sanitizeFileName(newBaseName);
    if (sanitized.isEmpty) {
      throw ArgumentError.value(newBaseName, 'newBaseName', 'empty after sanitizing');
    }

    final dir = p.dirname(recording.path);
    final target = p.join(dir, '$sanitized.wav');
    if (target == recording.path) return recording.path;
    if (await File(target).exists()) {
      throw const RenameCollisionException();
    }

    await File(recording.path).rename(target);

    // Carry the transcript across so renaming never loses it.
    final oldSidecar = File(_transcriptPath(recording.path));
    if (await oldSidecar.exists()) {
      await oldSidecar.rename(_transcriptPath(target));
    }
    return target;
  }

  /// Strips characters that are illegal or awkward in a filename on any of the
  /// platforms this app runs on, and trims to a sane length.
  static String sanitizeFileName(String input) {
    final cleaned = input
        .trim()
        // Path separators and characters Windows/macOS reject outright.
        .replaceAll(RegExp(r'[/\\:*?"<>|]'), '')
        // Control characters.
        .replaceAll(RegExp(r'[\x00-\x1F]'), '')
        // Collapse whitespace runs.
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        // A leading dot hides the file on Unix.
        .replaceFirst(RegExp(r'^\.+'), '')
        .trim();
    return cleaned.length > 100 ? cleaned.substring(0, 100).trim() : cleaned;
  }

  /// Delete a recording's audio file and its transcript sidecar.
  Future<void> delete(Recording recording) async {
    final audio = File(recording.path);
    if (await audio.exists()) await audio.delete();
    final sidecar = File(_transcriptPath(recording.path));
    if (await sidecar.exists()) await sidecar.delete();
  }

  /// Persist (or overwrite) the transcript for a recording, together with the
  /// languages the recogniser detected.
  ///
  /// Written as JSON. Sidecars written before languages were tracked are plain
  /// text, and [_readTranscript] still reads those.
  Future<void> saveTranscript(
    String audioPath,
    String text, {
    List<TranscriptionLanguage> languages = const [],
    List<TranscriptSegment> segments = const [],
    Map<TranslationLanguage, TranslationOutcome> translations = const {},
  }) async {
    final payload = jsonEncode({
      'text': text,
      'languages': [for (final l in languages) l.name],
      'segments': [for (final s in segments) s.toJson()],
      'translations': {
        for (final e in translations.entries) e.key.name: e.value.toJson(),
      },
    });
    await File(_transcriptPath(audioPath)).writeAsString(payload);
  }

  // --- helpers --------------------------------------------------------------

  String _transcriptPath(String audioPath) =>
      p.setExtension(audioPath, '.txt');

  /// Reads a transcript sidecar.
  ///
  /// Handles both the current JSON form and the plain-text form written before
  /// detected languages were stored, so an existing transcript is never lost to
  /// a format change.
  Future<_TranscriptSidecar?> _readTranscript(String audioPath) async {
    final file = File(_transcriptPath(audioPath));
    if (!await file.exists()) return null;

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) return null;

    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        final text = decoded['text'] as String? ?? '';
        if (text.trim().isEmpty) return null;
        final languages = <TranscriptionLanguage>[
          for (final name in (decoded['languages'] as List? ?? const []))
            TranscriptionLanguage.fromName(name as String?),
        ];
        final segments = <TranscriptSegment>[
          for (final raw in (decoded['segments'] as List? ?? const []))
            if (raw is Map<String, dynamic>) TranscriptSegment.fromJson(raw),
        ];
        final translations = <TranslationLanguage, TranslationOutcome>{};
        final rawTranslations = decoded['translations'];
        if (rawTranslations is Map<String, dynamic>) {
          for (final entry in rawTranslations.entries) {
            final language = TranslationLanguage.fromName(entry.key);
            final value = entry.value;
            if (language != null && value is Map<String, dynamic>) {
              translations[language] = TranslationOutcome.fromJson(value);
            }
          }
        }
        return _TranscriptSidecar(text, languages, segments, translations);
      }
    } on FormatException {
      // Not JSON — a legacy plain-text sidecar.
    }
    return _TranscriptSidecar(raw, const [], const [], const {});
  }

  /// Derive duration from the WAV byte length for our fixed recording format.
  Duration? _durationForWavBytes(int sizeBytes) {
    final dataBytes = sizeBytes - _wavHeaderBytes;
    if (dataBytes <= 0) return null;
    final bytesPerSecond = _sampleRate * _bytesPerSample * _channels;
    final millis = (dataBytes * 1000 / bytesPerSecond).round();
    return Duration(milliseconds: millis);
  }

  /// Recover the creation time from a `recording_yyyyMMdd_HHmmss.wav` name.
  DateTime? _parseTimestamp(String path) {
    final match = RegExp(r'(\d{8})_(\d{6})').firstMatch(p.basename(path));
    if (match == null) return null;
    final d = match.group(1)!;
    final t = match.group(2)!;
    return DateTime.tryParse(
      '${d.substring(0, 4)}-${d.substring(4, 6)}-${d.substring(6, 8)}'
      'T${t.substring(0, 2)}:${t.substring(2, 4)}:${t.substring(4, 6)}',
    );
  }
}


/// Thrown when renaming would overwrite an existing recording.
class RenameCollisionException implements Exception {
  const RenameCollisionException();
  @override
  String toString() => 'A recording with that name already exists.';
}

/// Parsed contents of a transcript sidecar.
class _TranscriptSidecar {
  const _TranscriptSidecar(
      this.text, this.languages, this.segments, this.translations);

  final String text;
  final List<TranscriptionLanguage> languages;
  final List<TranscriptSegment> segments;
  final Map<TranslationLanguage, TranslationOutcome> translations;
}
