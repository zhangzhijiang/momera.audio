import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../audio/silence_gate.dart';
import '../audio/wav.dart';
import 'recording_session_channel.dart';
import 'vad_speech_detector.dart';

/// Why a recording stopped.
enum RecordingStopReason {
  /// The user tapped stop.
  user,

  /// The storage cap from settings was reached. Audio up to that point is kept.
  storageFull,

  /// The recording hit the largest payload a WAV file can describe (about 37
  /// hours at our format). Audio up to that point is kept; the limit is the
  /// container's, not the user's settings, so it is reported separately from
  /// [storageFull] rather than blaming a cap the user could raise.
  fileSizeLimit,

  /// The microphone stream ended, errored, or went silently dead and could not
  /// be rebuilt. Audio up to that point is kept.
  interrupted,

  /// Audio could not be written to disk. Audio already flushed is kept.
  ///
  /// Separate from [storageFull], which is the app's own configurable cap: this
  /// is the filesystem refusing a write, so there is no setting to raise and
  /// nothing the user can delete inside the app to fix it.
  writeFailed,
}

/// The microphone, behind a seam.
///
/// Exists so the stall watchdog can be tested. The failure it guards against —
/// a capture stream that goes quiet without erroring and without ending — is by
/// definition one the platform never announces, so it cannot be provoked from a
/// real [AudioRecorder] on demand. A fake source can simply stop emitting,
/// which is exactly the situation that used to freeze a recording for good.
///
/// The default implementation is the `record` plugin and behaves identically to
/// the direct calls this replaced.
abstract class CaptureSource {
  Future<bool> hasPermission();

  /// Begin capture and return the stream of PCM buffers.
  Future<Stream<Uint8List>> start(RecordConfig config);

  Future<void> stop();

  void dispose();
}

class _RecordPluginCapture implements CaptureSource {
  final AudioRecorder _recorder = AudioRecorder();

  @override
  Future<bool> hasPermission() => _recorder.hasPermission();

  @override
  Future<Stream<Uint8List>> start(RecordConfig config) =>
      _recorder.startStream(config);

  @override
  Future<void> stop() => _recorder.stop();

  @override
  void dispose() => _recorder.dispose();
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
/// **Skipping silence** is optional and off by default. When on, a [SilenceGate]
/// filters each chunk before anything else sees it, so the byte budget, the
/// elapsed time and the live transcript's offsets all continue to describe the
/// file that is actually being written — the recording is simply shorter than
/// the session that produced it.
///
/// **Staying alive in the background** is delegated to
/// [RecordingSessionChannel]: an Android foreground service with a persistent
/// notification, and an iOS audio session under `UIBackgroundModes: audio`.
class AudioRecordingService {
  AudioRecordingService({
    RecordingSessionChannel? session,
    Future<SpeechDetector?> Function()? detectorFactory,
    CaptureSource? capture,
    Duration? stallTimeout,
    Duration? watchdogInterval,
    int? maxCaptureRestarts,
  })  : _session = session ?? const RecordingSessionChannel(),
        _detectorFactory = detectorFactory ?? VadSpeechDetector.tryCreate,
        _capture = capture ?? _RecordPluginCapture(),
        _stallTimeout = stallTimeout ?? _defaultStallTimeout,
        _watchdogInterval = watchdogInterval ?? _defaultWatchdogInterval,
        _maxCaptureRestarts = maxCaptureRestarts ?? _defaultMaxCaptureRestarts;

  static const String _dirName = 'recordings';
  static const String _filePrefix = 'recording';
  static const int sampleRate = 16000;
  static const int channels = 1;

  /// Raw PCM extension, used while a recording is in progress. A file with this
  /// extension left behind at launch is an interrupted recording.
  static const String pcmExtension = '.pcm';

  /// How capture is configured, on the first attempt and on every rebuild after
  /// an interruption.
  static const RecordConfig _captureConfig = RecordConfig(
    encoder: AudioEncoder.pcm16bits,
    sampleRate: sampleRate,
    numChannels: channels,
    // "Keep recording until the user taps stop" means surviving a phone call.
    // The plugin's default (`pause`) stops on interruption and waits for a
    // manual resume that never comes, silently ending the recording;
    // `pauseResume` picks capture back up by itself.
    audioInterruption: AudioInterruptionMode.pauseResume,
    iosConfig: IosRecordConfig(
      // A ringing call no longer interrupts — only actually answering one does.
      allowHapticsAndSystemSoundsDuringRecording: true,
    ),
  );

  /// How many times capture may be rebuilt before a recording gives up.
  ///
  /// Bounded on purpose: a microphone taken by another app, or a permission
  /// revoked mid-recording, will never come back, and retrying forever would
  /// burn the battery of a device whose owner thinks they are recording.
  static const int _defaultMaxCaptureRestarts = 20;

  /// Longest wait between attempts, once the backoff has grown into it.
  static const Duration _maxRestartBackoff = Duration(seconds: 3);

  /// How long capture may deliver nothing at all before it is treated as dead.
  ///
  /// This is the load-bearing number for the whole recovery story. An
  /// interrupted microphone very often signals **neither** an error nor an end
  /// of stream — the platform simply stops handing over buffers, most commonly
  /// when another app takes the microphone or an aggressive ROM freezes this
  /// process in the background. Nothing in a `listen()` callback can observe
  /// that, so without a clock nobody ever calls [_restartCapture] and the
  /// recording is frozen for good while still looking live.
  ///
  /// Six seconds is far longer than any legitimate gap — buffers arrive tens of
  /// times a second — while still being short enough that the user sees
  /// "reconnecting" rather than a dead timer.
  static const Duration _defaultStallTimeout = Duration(seconds: 6);

  /// How often the stall check runs.
  static const Duration _defaultWatchdogInterval = Duration(seconds: 2);

  final CaptureSource _capture;
  final RecordingSessionChannel _session;

  /// Watchdog timings, overridable so a test can provoke a stall in
  /// milliseconds instead of waiting out the real six seconds.
  final Duration _stallTimeout;
  final Duration _watchdogInterval;

  /// Retry budget, overridable for the same reason: exhausting twenty attempts
  /// at the real backoff takes over a minute.
  final int _maxCaptureRestarts;

  /// Builds the speech detector behind the silence gate. Injectable so tests
  /// can exercise both the working path and the unsupported-device path without
  /// a native library.
  final Future<SpeechDetector?> Function() _detectorFactory;

  StreamSubscription<Uint8List>? _subscription;
  IOSink? _sink;
  File? _pcmFile;
  Timer? _flushTimer;
  Completer<RecordingResult?>? _finished;

  /// Watches for capture going quiet. See [_stallTimeout].
  Timer? _watchdog;

  /// Wall-clock time the platform last handed over a buffer.
  ///
  /// Deliberately wall-clock and deliberately stamped for *every* buffer —
  /// including ones dropped because the recording is paused or because the
  /// silence gate rejected them. The question this answers is "is capture
  /// alive", which is not the same question as "are bytes being written": with
  /// silence-skipping on, a quiet room legitimately writes nothing for minutes.
  DateTime? _lastChunkAt;

  /// True between rebuilding capture and the first buffer arriving on the new
  /// stream, i.e. while a recovery is claimed but not yet proven.
  bool _awaitingFirstChunk = false;

  /// Restart attempts spent since capture last actually delivered audio.
  ///
  /// Held across calls rather than being a loop-local counter, because the
  /// watchdog can call [_restartCapture] repeatedly. A per-call counter would
  /// hand each call a fresh budget and retry a dead microphone forever.
  int _restartAttemptsUsed = 0;

  /// Where a recording that ends by itself is reported. Held as a field so the
  /// watchdog can end a recording it started no part of.
  void Function(RecordingStopReason reason, RecordingResult? result)?
      _onStopped;

  /// Drops silence before it is written, when the user has asked for that.
  /// Null means every sample is kept, which is the default.
  SilenceGate? _gate;

  /// What the user asked for, which is not the same as what is running: the
  /// detector is built asynchronously, and a device that cannot build one keeps
  /// recording everything.
  bool _skipSilenceWanted = false;

  bool _isRecording = false;
  bool _isPaused = false;
  int _bytesWritten = 0;
  int _byteBudget = 0;

  /// True when [_byteBudget] came from the WAV container limit rather than the
  /// user's storage cap, so running out is reported as the right kind of stop.
  bool _cappedByFileSize = false;

  /// True while capture is being rebuilt after an interruption.
  bool _restarting = false;

  /// How many times capture has been rebuilt during this recording. Exposed for
  /// diagnostics: a recording that survived three interruptions is worth being
  /// able to see.
  int _captureRestarts = 0;
  int get captureRestarts => _captureRestarts;

  /// Fires when capture drops out and again when it comes back, so the UI can
  /// say what is happening rather than showing a timer that has quietly frozen.
  void Function(bool interrupted)? onCaptureInterrupted;

  bool get isRecording => _isRecording;

  /// Paused mid-recording: the session and the file stay open, and audio
  /// arriving from the platform is discarded until [resume].
  bool get isPaused => _isPaused;

  /// Optional tap on the recorded audio, for live transcription.
  ///
  /// Called with a copy of each chunk actually written, plus that chunk's byte
  /// offset from the start of the recording. Set it to start observing and
  /// null it to stop; when null there is no extra work per chunk at all, which
  /// is what keeps live transcription's cost bounded to the moment the user is
  /// holding the button.
  ///
  /// Never called while paused, and never called with audio beyond the storage
  /// cap. Implementations must return promptly: this runs inside the audio
  /// stream's chunk handler, and time spent here delays the next chunk's write.
  void Function(Uint8List pcm, int byteOffset)? onLiveAudio;

  /// Bytes of audio captured in the current recording.
  int get bytesWritten => _bytesWritten;

  /// Duration captured so far, derived from the byte count rather than a wall
  /// clock, so it stays truthful if the stream stalls.
  Duration get elapsed => durationForPcmBytes(_bytesWritten,
      sampleRate: sampleRate, channels: channels);

  Future<bool> hasPermission() => _capture.hasPermission();

  /// Whether silence is currently being dropped rather than written.
  bool get isSkippingSilence => _gate != null;

  /// Turn silence-skipping on or off. Safe to call mid-recording; it takes
  /// effect on the next chunk of audio.
  ///
  /// Returns false when [skip] was true but no detector could be built — a
  /// 32-bit process, a missing native library, a failed asset copy. The
  /// recording continues either way, keeping every sample: silently writing the
  /// wrong thing, or refusing to record at all, are both worse than saying the
  /// feature is unavailable here.
  Future<bool> setSkipSilence(bool skip) async {
    _skipSilenceWanted = skip;

    if (!skip) {
      _gate?.dispose();
      _gate = null;
      return true;
    }
    if (_gate != null) return true;

    final detector = await _detectorFactory();
    // The user may have turned it off again while the detector was loading.
    if (!_skipSilenceWanted) {
      detector?.dispose();
      return true;
    }
    if (detector == null) {
      _skipSilenceWanted = false;
      return false;
    }
    final gate = SilenceGate(detector: detector);
    // Switched on mid-recording there is no pre-roll to fall back on, so let
    // audio through until the detector has had a chance to speak up.
    if (_isRecording) gate.openForResume();
    _gate = gate;
    return true;
  }

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
  /// tapping stop, so the UI can react (and explain) without polling. Its result
  /// is null when there was no audio worth keeping — the UI still has to be told,
  /// or it is left showing a recording that is over.
  Future<String?> startRecording({
    required int availableBytes,
    required Duration flushInterval,
    RecordingNotificationText? notification,
    void Function(RecordingStopReason reason, RecordingResult? result)?
        onStopped,
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
      stream = await _capture.start(_captureConfig);
    } catch (e) {
      debugPrint('AudioRecordingService: could not start stream: $e');
      return null;
    }

    _pcmFile = pcmFile;
    _sink = pcmFile.openWrite();
    _isPaused = false;
    _bytesWritten = 0;
    // A gate carried over from the previous recording must not open this one
    // with audio captured before it started.
    _gate?.reset();
    // A single recording is capped by the WAV container as well as by the
    // user's storage setting. The storage options go up to 10 GB, which is well
    // past the ~4 GiB a 32-bit RIFF size can describe, so without this clamp a
    // long enough recording would finalise into a silently corrupt file.
    _byteBudget = math.min(availableBytes, maxWavDataBytes);
    _cappedByFileSize = _byteBudget < availableBytes;
    _isRecording = true;
    _finished = Completer<RecordingResult?>();
    _onStopped = onStopped;

    // Keep running while backgrounded / screen-locked.
    await _session.start(notification);

    _captureRestarts = 0;
    _restartAttemptsUsed = 0;
    _awaitingFirstChunk = false;
    // The clock starts now, not at the first buffer: a microphone that never
    // produces one is exactly the failure the watchdog exists to catch.
    _lastChunkAt = DateTime.now();
    _listen(stream);

    // Periodic flush is the crash-safety guarantee: at most one interval of
    // audio can be lost.
    _flushTimer = Timer.periodic(flushInterval, (_) => _flush());
    _watchdog = Timer.periodic(_watchdogInterval, (_) => _checkForStall());

    return '$basePath.wav';
  }

  /// Notice capture going quiet, and rebuild it.
  ///
  /// The recovery path already existed and was sound; what was missing was
  /// anything able to *trigger* it when the platform neither errors nor closes
  /// the stream. That is the common case — another app takes the microphone, or
  /// the OS freezes this process in the background — and it left a recording
  /// frozen at whatever second it stalled on, looking live, until the user
  /// pressed stop.
  void _checkForStall() {
    if (!_isRecording || _restarting) return;
    final last = _lastChunkAt;
    if (last == null) return;
    if (DateTime.now().difference(last) < _stallTimeout) return;

    debugPrint('AudioRecordingService: no audio for '
        '${DateTime.now().difference(last).inMilliseconds}ms — rebuilding capture');
    unawaited(_restartCapture());
  }

  /// Subscribe to a capture stream. Called again for each rebuilt stream.
  ///
  /// These two callbacks are the *polite* ways capture can fail. Neither fires
  /// when the platform simply stops delivering, which is why [_checkForStall]
  /// exists alongside them.
  void _listen(Stream<Uint8List> stream) {
    _subscription = stream.listen(
      _onChunk,
      onError: (Object e, StackTrace _) {
        debugPrint('AudioRecordingService: stream error: $e');
        unawaited(_restartCapture());
      },
      onDone: () {
        // The platform ended the stream without being asked — a phone call the
        // session could not recover from, a Bluetooth headset disconnecting,
        // another app taking the microphone. The recording is not over; only
        // this stream is.
        if (_isRecording) unawaited(_restartCapture());
      },
      cancelOnError: true,
    );
  }

  /// Rebuild capture after it drops out, and keep writing to the same file.
  ///
  /// A recording ends when the user says so. Anything else that stops the
  /// microphone is treated as a fault to recover from: the stream is torn down
  /// and reopened, with a backoff so a device that needs a moment gets one. The
  /// audio already on disk is untouched throughout, and the gap is simply
  /// missing from the file — which is the honest outcome, since nothing was
  /// captured during it.
  ///
  /// Only after [_maxCaptureRestarts] failed attempts does the recording end,
  /// keeping everything recorded up to that point.
  Future<void> _restartCapture() async {
    if (!_isRecording || _restarting) return;
    _restarting = true;
    onCaptureInterrupted?.call(true);

    try {
      while (_restartAttemptsUsed < _maxCaptureRestarts) {
        final attempt = _restartAttemptsUsed++;
        await Future<void>.delayed(_backoffFor(attempt));
        // The user may have tapped stop while this was waiting.
        if (!_isRecording) return;

        await _subscription?.cancel();
        _subscription = null;
        try {
          await _capture.stop();
        } catch (_) {
          // Already stopped, or never started. Either way the next call is the
          // one that matters.
        }

        try {
          final stream = await _capture.start(_captureConfig);
          if (!_isRecording) {
            await _capture.stop();
            return;
          }
          _captureRestarts++;
          // Nothing is buffered after the gap, so let audio through until the
          // detector has had a chance to catch up.
          _gate?.openForResume();

          // A rebuilt stream is a claim, not a recovery. `startStream` can
          // succeed and hand back a stream that never emits — which is exactly
          // what happens when the microphone is still held by whoever took it.
          // So the "recording again" message and the retry budget both wait for
          // real audio; until then the watchdog's clock is running and will
          // come back round to try again.
          _awaitingFirstChunk = true;
          _lastChunkAt = DateTime.now();
          _listen(stream);
          debugPrint('AudioRecordingService: capture rebuilt on attempt '
              '${attempt + 1}; waiting for audio');
          return;
        } catch (e) {
          debugPrint('AudioRecordingService: restart attempt ${attempt + 1} '
              'failed: $e');
        }
      }

      debugPrint('AudioRecordingService: giving up after $_maxCaptureRestarts '
          'restart attempts; keeping the audio recorded so far');
      await _finish(RecordingStopReason.interrupted, _onStopped);
    } finally {
      _restarting = false;
    }
  }

  /// Doubling backoff, capped: a transient glitch recovers on the first retry,
  /// while a microphone held by another app is not polled sixty times a second.
  static Duration _backoffFor(int attempt) {
    final ms = 200 * (1 << attempt.clamp(0, 4));
    return ms >= _maxRestartBackoff.inMilliseconds
        ? _maxRestartBackoff
        : Duration(milliseconds: ms);
  }

  void _onChunk(Uint8List chunk) {
    if (!_isRecording) return;

    // Proof of life for the watchdog, stamped before every early return below.
    // A paused recording and a silent room both stop bytes being written while
    // capture is perfectly healthy; only the arrival of a buffer says the
    // microphone is still there.
    _lastChunkAt = DateTime.now();

    // Audio is back after an interruption. This — not `startStream` returning —
    // is what makes a recovery real, so it is what clears the warning and
    // replenishes the retry budget for any future, unrelated interruption.
    if (_awaitingFirstChunk) {
      _awaitingFirstChunk = false;
      _restartAttemptsUsed = 0;
      debugPrint('AudioRecordingService: capture resumed');
      onCaptureInterrupted?.call(false);
    }

    // While paused the microphone stream is left running and its audio is
    // dropped. Stopping the platform recorder instead would end the stream and
    // tear down the session, which on iOS also drops the background audio
    // assertion — the app would stop being allowed to run with the screen
    // locked, and could not resume.
    if (_isPaused) return;

    // Silence is dropped before anything else sees this audio, so the byte
    // budget, the elapsed time and the live transcript's byte offsets all go on
    // describing the file that is actually being written.
    final gate = _gate;
    final Uint8List audio;
    if (gate == null) {
      audio = chunk;
    } else {
      audio = gate.gate(chunk);
      if (audio.isEmpty) return;
    }

    final remaining = _byteBudget - _bytesWritten;
    if (remaining <= 0) {
      _finish(_budgetExhaustedReason, _onStopped);
      return;
    }

    // Trim the final chunk so the cap is honoured exactly rather than
    // overshooting by up to one buffer.
    final toWrite =
        audio.length <= remaining ? audio : Uint8List.sublistView(audio, 0, remaining);
    final offsetBefore = _bytesWritten;

    // Guarded because this runs inside a stream callback: an exception here
    // escapes to the zone, where release builds swallow it, and every later
    // chunk then throws at the same line. The visible result is identical to a
    // dead microphone — a frozen timer over a recording that still looks live —
    // so a failed write has to end the recording out loud instead.
    try {
      _sink?.add(toWrite);
    } catch (e) {
      debugPrint('AudioRecordingService: write failed: $e');
      _finish(RecordingStopReason.writeFailed, _onStopped);
      return;
    }
    _bytesWritten += toWrite.length;
    _session.updateElapsed(elapsed);

    // Live transcription tee. Deliberately last, and deliberately fed the
    // trimmed `toWrite` rather than `chunk` — feeding `chunk` would transcribe
    // audio past the storage cap that was never recorded.
    //
    // The listener must not touch the sink or _bytesWritten: those are the only
    // source of truth for elapsed time, the cap, and the final duration. It is
    // handed a *copy* because `Uint8List.sublistView` is a view onto the
    // plugin's buffer, and holding it would retain the whole underlying chunk.
    final live = onLiveAudio;
    if (live != null && toWrite.isNotEmpty) {
      live(Uint8List.fromList(toWrite), offsetBefore);
    }

    if (_bytesWritten >= _byteBudget) {
      _finish(_budgetExhaustedReason, _onStopped);
    }
  }

  /// Why the recording ends when the byte budget runs out.
  RecordingStopReason get _budgetExhaustedReason => _cappedByFileSize
      ? RecordingStopReason.fileSizeLimit
      : RecordingStopReason.storageFull;

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
    // Audio buffered by the gate belongs to the moment before the pause;
    // resuming must not splice it in front of what comes next.
    _gate?.reset();
    // Flush now so a crash while paused keeps everything up to this point.
    _flush();
  }

  void resume() {
    if (!_isRecording || !_isPaused) return;
    _isPaused = false;
    // Nothing is buffered after a pause, so a user who speaks the instant they
    // resume would lose the moment the detector takes to decide. Start open.
    _gate?.openForResume();
  }

  /// Stop recording at the user's request and finalise the WAV.
  Future<RecordingResult?> stopRecording() async {
    if (!_isRecording) return null;
    return _finish(RecordingStopReason.user, null);
  }

  /// Shared teardown for every way a recording can end.
  Future<RecordingResult?> _finish(
    RecordingStopReason reason,
    void Function(RecordingStopReason reason, RecordingResult? result)?
        onStopped,
  ) async {
    if (!_isRecording) return _finished?.future;
    _isRecording = false;

    _flushTimer?.cancel();
    _flushTimer = null;

    // Before anything awaits: the watchdog must not fire against a recording
    // that is already ending and try to rebuild capture underneath the
    // teardown.
    _watchdog?.cancel();
    _watchdog = null;
    _lastChunkAt = null;
    _awaitingFirstChunk = false;

    await _subscription?.cancel();
    _subscription = null;

    try {
      await _capture.stop();
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
    _cappedByFileSize = false;
    _restartAttemptsUsed = 0;
    _onStopped = null;
    _finished?.complete(result);

    // Deliberately not conditional on `result`: a recording that ends by itself
    // having captured nothing — the microphone revoked a moment after it
    // started, say — still has to take the UI out of its recording state.
    // Gating this on a non-null result left the timer running over a recording
    // that had already stopped.
    if (reason != RecordingStopReason.user) {
      onStopped?.call(reason, result);
    }
    return result;
  }

  /// Turn a raw `.pcm` file into a playable `.wav` by prepending a header.
  ///
  /// Returns the `.wav` path, or null if there was no audio worth keeping.
  /// The `.pcm` is removed once the `.wav` is written.
  static Future<String?> finalisePcm(File pcmFile) async {
    if (!await pcmFile.exists()) return null;

    final rawBytes = await pcmFile.length();
    if (rawBytes <= 0) {
      await pcmFile.delete();
      return null;
    }

    // Recording clamps its own budget, but recovery has to cope with whatever
    // is on disk — including a `.pcm` written by an older build that had no
    // clamp. Describing more bytes than a 32-bit RIFF size can hold would
    // produce an unreadable file, so the tail is dropped instead: a valid
    // 37-hour recording beats a corrupt longer one.
    final dataBytes = math.min(rawBytes, maxWavDataBytes);
    if (dataBytes < rawBytes) {
      debugPrint('AudioRecordingService: ${p.basename(pcmFile.path)} is '
          '$rawBytes bytes; '
          'truncating to the $maxWavDataBytes-byte WAV limit');
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
      await sink.addStream(pcmFile.openRead(0, dataBytes));
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
        debugPrint('Could not recover ${p.basename(entry.path)}: $e');
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
    _watchdog?.cancel();
    _watchdog = null;
    _subscription?.cancel();
    _sink?.close();
    _gate?.dispose();
    _gate = null;
    _capture.dispose();
  }

  /// `yyyyMMdd_HHmmss`, matching the fixed 24-hour timestamp the UI displays.
  String _formatTimestamp(DateTime time) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${time.year}${two(time.month)}${two(time.day)}'
        '_${two(time.hour)}${two(time.minute)}${two(time.second)}';
  }
}
