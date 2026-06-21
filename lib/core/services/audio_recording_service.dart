import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// Records microphone audio to a 16 kHz mono WAV file.
///
/// WAV/PCM16 at 16 kHz is the format the offline speech-to-text model expects,
/// so a recording can later be transcribed directly from disk with no decoding
/// step (see [TranscriptionService]). Files are saved under the app documents
/// `recordings/` directory.
class AudioRecordingService {
  static const String _dirName = 'recordings';
  static const String _filePrefix = 'recording';
  static const int sampleRate = 16000;

  final AudioRecorder _recorder = AudioRecorder();

  bool _isRecording = false;
  String? _currentPath;

  bool get isRecording => _isRecording;
  String? get currentPath => _currentPath;

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<Directory> _recordingsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(dir.path, _dirName));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  /// Start recording. Returns the destination path, or null if already
  /// recording or microphone permission was denied.
  Future<String?> startRecording() async {
    if (_isRecording) return null;
    if (!await hasPermission()) return null;

    final dir = await _recordingsDir();
    final filename = '${_filePrefix}_${_formatTimestamp(DateTime.now())}.wav';
    _currentPath = p.join(dir.path, filename);

    await _recorder.start(
      const RecordConfig(
        encoder: AudioEncoder.wav,
        sampleRate: sampleRate,
        numChannels: 1,
      ),
      path: _currentPath!,
    );

    _isRecording = true;
    return _currentPath;
  }

  /// Stop recording and return the saved file path.
  Future<String?> stopRecording() async {
    if (!_isRecording) return null;
    await _recorder.stop();
    _isRecording = false;
    final savedPath = _currentPath;
    _currentPath = null;
    debugPrint('AudioRecordingService.stopRecording: saved=$savedPath');
    return savedPath;
  }

  /// Stop recording and delete the partial file.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    final path = _currentPath;
    await _recorder.stop();
    _isRecording = false;
    _currentPath = null;
    if (path != null) {
      final file = File(path);
      if (await file.exists()) await file.delete();
    }
  }

  void dispose() {
    _recorder.dispose();
  }

  String _formatTimestamp(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}'
        '_${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }
}
