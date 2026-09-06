import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../audio/wav.dart';
import 'recording_session_channel.dart';

/// Why a recording stopped.
enum RecordingStopReason {
  /// The user tapped stop.
  user,

  /// The storage cap from settings was reached. Audio up to that point is kept.
  storageFull,

  /// The microphone stream ended or errored. Audio up to that point is kept.
  interrupted,
}

/// Outcome of a finished recording.
@immutable
class RecordingResult {
  const RecordingResult({
    required this.path,
    required this.reason,
    required this.duration,
  });

  final String path;
  final RecordingStopReason reason;
  final Duration duration;
}

/// Records microphone audio to a 16 kHz mono WAV file, and keeps recording
/// while the app is backgrounded or the screen is locked.
///
/// **Why raw PCM on disk instead of letting the plugin write a WAV.**
/// Audio is streamed from the microphone and appended to a `.pcm` sidecar,
/// flushed to disk on the interval from settings. Only when the recording is
/// finalised is a WAV header prepended and the file renamed to `.wav`. This
/// means:
///
/// * A crash, a force quit or a battery death loses at most one flush interval
///   — everything already flushed is recoverable by [recoverInterrupted],
///   because a partial raw stream needs no repair, just a header.
/// * The storage cap can be enforced continuously, since the exact byte count
///   is known as it is written.
///
/// **Staying alive in the background** is delegated to
/// [RecordingSessionChannel]: an Android foreground service with a persistent
/// notification, and an iOS audio session under `UIBackgroundModes: audio`.
class AudioRecordingService {
  AudioRecordingService({RecordingSessionChannel? session})
      : _session = session ?? const RecordingSessionChannel();

  static const String _dirName = 'recordings';
  static const String _filePrefix = 'recording';
  static const int sampleRate = 16000;
  static const int channels = 1;

  /// Raw PCM extension, used while a recording is in progress. A file with this
  /// extension left behind at launch is an interrupted recording.
  static const String pcmExtension = '.pcm';

  final AudioRecorder _recorder = AudioRecorder();
  final RecordingSessionChannel _session;

  StreamSubscription<Uint8List>? _subscription;
  IOSink? _sink;
  File? _pcmFile;
  Timer? _flushTimer;
  Completer<RecordingResult?>? _finished;

  bool _isRecording = false;
  bool _isPaused = false;
  int _bytesWritten = 0;
  int _byteBudget = 0;

  bool get isRecording => _isRecording;

  /// Paused mid-recording: the session and the file stay open, and audio
  /// arriving from the platform is discarded until [resume].
  bool get isPaused => _isPaused;

  /// Bytes of audio captured in the current recording.
  int get bytesWritten => _bytesWritten;

  /// Duration captured so far, derived from the byte count rather than a wall
  /// clock, so it stays truthful if the stream stalls.
  Duration get elapsed => durationForPcmBytes(_bytesWritten,
      sampleRate: sampleRate, channels: channels);

  Future<bool> hasPermission() => _recorder.hasPermission();

  Future<Directory> recordingsDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final recordingsDir = Directory(p.join(dir.path, _dirName));
    if (!await recordingsDir.exists()) {
      await recordingsDir.create(recursive: true);
    }
    return recordingsDir;
  }

  /// Start recording.
  ///
  /// [availableBytes] is how many bytes this recording may consume before it
  /// stops itself — the storage cap from settings minus what is already used.
  /// Returns the destination `.wav` path, or null if permission was denied,
  /// a recording is already running, or there is no space at all.
  ///
  /// [onStopped] fires when the recording ends for a reason other than the user
  /// tapping stop, so the UI can react (and explain) without polling.
  Future<String?> startRecording({
    required int availableBytes,
    required Duration flushInterval,
    RecordingNotificationText? notification,
    void Function(RecordingResult result)? onStopped,
  }) async {
    if (_isRecording) return null;
    if (availableBytes <= 0) return null;
    if (!await hasPermission()) return null;

    final dir = await recordingsDir();
    final stamp = _formatTimestamp(DateTime.now());
    final basePath = p.join(dir.path, '${_filePrefix}_$stamp');
    final pcmFile = File('$basePath$pcmExtension');

    final Stream<Uint8List> stream;
    try {
      stream = await _recorder.startStream(
        const RecordConfig(
          encoder: AudioEncoder.pcm16bits,
          sampleRate: sampleRate,
          numChannels: channels,
          // "Keep recording until the user taps stop" means surviving a phone
          // call. The plugin's default (`pause`) stops on interruption and
          // waits for a manual resume that never comes, silently ending the
          // recording; `pauseResume` picks capture back up by itself.
          audioInterruption: AudioInterruptionMode.pauseResume,
          iosConfig: IosRecordConfig(
            // A ringing call no longer interrupts — only actually answering
            // one does.
            allowHapticsAndSystemSoundsDuringRecording: true,
          ),
        ),
      );
    } catch (e) {
      debugPrint('AudioRecordingService: could not start stream: $e');
      return null;
    }

    _pcmFile = pcmFile;
    _sink = pcmFile.openWrite();
    _isPaused = false;
    _bytesWritten = 0;
    _byteBudget = availableBytes;
    _isRecording = true;
    _finished = Completer<RecordingResult?>();

    // Keep running while backgrounded / screen-locked.
    await _session.start(notification);

    _subscription = stream.listen(
      (chunk) => _onChunk(chunk, onStopped),
      onError: (Object e, StackTrace _) {
        debugPrint('AudioRecordingService: stream error: $e');
        _finish(RecordingStopReason.interrupted, onStopped);
      },
      onDone: () {
        // The platform ended the stream without us asking (e.g. an audio
        // interruption we could not recover from). Keep what we have.
        if (_isRecording) {
          _finish(RecordingStopReason.interrupted, onStopped);
        }
      },
      cancelOnError: true,
    );

    // Periodic flush is the crash-safety guarantee: at most one interval of
    // audio can be lost.
    _flushTimer = Timer.periodic(flushInterval, (_) => _flush());

    return '$basePath.wav';
  }

  void _onChunk(
    Uint8List chunk,
    void Function(RecordingResult result)? onStopped,
  ) {
    if (!_isRecording) return;
    // While paused the microphone stream is left running and its audio is
    // dropped. Stopping the platform recorder instead would end the stream and
    // tear down the session, which on iOS also drops the background audio
    // assertion — the app would stop being allowed to run with the screen
    // locked, and could not resume.
    if (_isPaused) return;

    final remaining = _byteBudget - _bytesWritten;
    if (remaining <= 0) {
      _finish(RecordingStopReason.storageFull, onStopped);
      return;
    }

    // Trim the final chunk so the cap is honoured exactly rather than
    // overshooting by up to one buffer.
    final toWrite =
        chunk.length <= remaining ? chunk : Uint8List.sublistView(chunk, 0, remaining);
    _sink?.add(toWrite);
    _bytesWritten += toWrite.length;
    _session.updateElapsed(elapsed);

    if (_bytesWritten >= _byteBudget) {
      _finish(RecordingStopReason.storageFull, onStopped);
    }
  }

  Future<void> _flush() async {
    try {
      await _sink?.flush();
    } catch (e) {
      debugPrint('AudioRecordingService: flush failed: $e');
    }
  }

  /// Pause capture. Audio arriving while paused is discarded; the file and the
  /// background session stay open so [resume] is instant.
  void pause() {
    if (!_isRecording || _isPaused) return;
    _isPaused = true;
    // Flush now so a crash while paused keeps everything up to this point.
    _flush();
  }

  void resume() {
    if (!_isRecording || !_isPaused) return;
    _isPaused = false;
  }

  /// Stop recording at the user's request and finalise the WAV.
  Future<RecordingResult?> stopRecording() async {
    if (!_isRecording) return null;
    return _finish(RecordingStopReason.user, null);
  }

  /// Shared teardown for every way a recording can end.
  Future<RecordingResult?> _finish(
    RecordingStopReason reason,
    void Function(RecordingResult result)? onStopped,
  ) async {
    if (!_isRecording) return _finished?.future;
    _isRecording = false;

    _flushTimer?.cancel();
    _flushTimer = null;

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _recorder.stop();
    } catch (e) {
      debugPrint('AudioRecordingService: recorder.stop failed: $e');
    }

    await _session.stop();

    final pcmFile = _pcmFile;
    _pcmFile = null;

    await _sink?.flush();
    await _sink?.close();
    _sink = null;

    RecordingResult? result;
    if (pcmFile != null) {
      final wavPath = await finalisePcm(pcmFile);
      if (wavPath != null) {
        result = RecordingResult(
          path: wavPath,
          reason: reason,
          duration: durationForPcmBytes(_bytesWritten,
              sampleRate: sampleRate, channels: channels),
        );
      }
    }

    _bytesWritten = 0;
    _isPaused = false;
    _finished?.complete(result);

    if (result != null && reason != RecordingStopReason.user) {
      onStopped?.call(result);
    }
    return result;
  }

  /// Turn a raw `.pcm` file into a playable `.wav` by prepending a header.
  ///
  /// Returns the `.wav` path, or null if there was no audio worth keeping.
  /// The `.pcm` is removed once the `.wav` is written.
  static Future<String?> finalisePcm(File pcmFile) async {
    if (!await pcmFile.exists()) return null;

    final dataBytes = await pcmFile.length();
    if (dataBytes <= 0) {
      await pcmFile.delete();
      return null;
    }

    final wavPath = p.setExtension(pcmFile.path, '.wav');
    final wavFile = File(wavPath);
    final sink = wavFile.openWrite();
    try {
      sink.add(buildWavHeader(
        dataBytes: dataBytes,
        sampleRate: sampleRate,
        channels: channels,
      ));
      await sink.addStream(pcmFile.openRead());
      await sink.flush();
    } finally {
      await sink.close();
    }

    await pcmFile.delete();
    return wavPath;
  }

  /// Recover recordings interrupted by a crash or force quit.
  ///
  /// Any `.pcm` left in the recordings directory is audio that was flushed but
  /// never finalised. Call this at startup, before listing recordings.
  /// Returns the paths of the recovered `.wav` files.
  Future<List<String>> recoverInterrupted() async {
    final dir = await recordingsDir();
    final recovered = <String>[];
    final inProgress = _pcmFile?.path;

    await for (final entry in dir.list()) {
      if (entry is! File) continue;
      if (p.extension(entry.path).toLowerCase() != pcmExtension) continue;
      // Never finalise the file being written right now — that would pull the
      // recording out from under the active sink.
      if (inProgress != null && entry.path == inProgress) continue;
      try {
        final wavPath = await finalisePcm(entry);
        if (wavPath != null) recovered.add(wavPath);
      } catch (e) {
        debugPrint('Could not recover ${entry.path}: $e');
      }
    }

    if (recovered.isNotEmpty) {
      debugPrint('Recovered ${recovered.length} interrupted recording(s)');
    }
    return recovered;
  }

  /// Stop recording and discard the audio.
  Future<void> cancelRecording() async {
    if (!_isRecording) return;
    final pcmFile = _pcmFile;
    await _finish(RecordingStopReason.user, null);
    // _finish converts the pcm to a wav; drop that result entirely.
    if (pcmFile != null) {
      final wav = File(p.setExtension(pcmFile.path, '.wav'));
      if (await wav.exists()) await wav.delete();
    }
  }

  void dispose() {
    _flushTimer?.cancel();
    _subscription?.cancel();
    _sink?.close();
    _recorder.dispose();
  }

  /// `yyyyMMdd_HHmmss`, matching the fixed 24-hour timestamp the UI displays.
  String _formatTimestamp(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}'
        '_${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }
}
