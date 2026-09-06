import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
      final transcript = await _readTranscript(entry.path);
      recordings.add(
        Recording(
          path: entry.path,
          createdAt: _parseTimestamp(entry.path) ?? stat.modified,
          sizeBytes: stat.size,
          duration: _durationForWavBytes(stat.size),
          transcript: transcript,
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
    return total;
  }

  /// Delete a recording's audio file and its transcript sidecar.
  Future<void> delete(Recording recording) async {
    final audio = File(recording.path);
    if (await audio.exists()) await audio.delete();
    final sidecar = File(_transcriptPath(recording.path));
    if (await sidecar.exists()) await sidecar.delete();
  }

  /// Persist (or overwrite) the transcript for a recording.
  Future<void> saveTranscript(String audioPath, String text) async {
    await File(_transcriptPath(audioPath)).writeAsString(text);
  }

  // --- helpers --------------------------------------------------------------

  String _transcriptPath(String audioPath) =>
      p.setExtension(audioPath, '.txt');

  Future<String?> _readTranscript(String audioPath) async {
    final file = File(_transcriptPath(audioPath));
    if (!await file.exists()) return null;
    final text = await file.readAsString();
    return text.trim().isEmpty ? null : text;
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
