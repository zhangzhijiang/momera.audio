import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../utils/model_asset_helper.dart';
import '../audio/wav.dart';
import '../capabilities/device_capability_service.dart';
import 'decode_worker.dart';

/// Languages the SenseVoice model can recognise.
///
/// The checkpoint is `sense-voice-zh-en-ja-ko-yue`, and those five are the
/// whole list. The token vocabulary contains tags for many more languages
/// (inherited from the vocab it was built on) but this checkpoint is not
/// trained for them.
enum TranscriptionLanguage {
  /// Detect per speech segment. The model's default, and the right choice for
  /// a conversation that switches language between utterances.
  auto(''),
  mandarin('zh'),
  cantonese('yue'),
  english('en'),
  japanese('ja'),
  korean('ko');

  const TranscriptionLanguage(this.code);

  /// Value for `OfflineSenseVoiceModelConfig.language`; empty means auto.
  final String code;

  static TranscriptionLanguage fromName(String? name) =>
      TranscriptionLanguage.values.firstWhere(
        (l) => l.name == name,
        orElse: () => TranscriptionLanguage.auto,
      );

  /// Maps a language tag reported by the recogniser back to an enum value.
  /// Tags arrive either bare (`zh`) or wrapped (`<|zh|>`).
  static TranscriptionLanguage? fromTag(String tag) {
    final code = tag.replaceAll('<|', '').replaceAll('|>', '').trim();
    if (code.isEmpty) return null;
    for (final language in TranscriptionLanguage.values) {
      if (language != TranscriptionLanguage.auto && language.code == code) {
        return language;
      }
    }
    return null;
  }
}

/// One recognised stretch of speech, with where it sits in the recording.
///
/// The VAD reports the sample offset of every segment it emits, and that offset
/// was previously discarded. Keeping it is what lets a search hit seek playback
/// to the moment the words were spoken rather than merely naming the file.
@immutable
class TranscriptSegment {
  const TranscriptSegment({
    required this.start,
    required this.end,
    required this.text,
    this.language,
  });

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    return TranscriptSegment(
      start: Duration(milliseconds: (json['startMs'] as num?)?.toInt() ?? 0),
      end: Duration(milliseconds: (json['endMs'] as num?)?.toInt() ?? 0),
      text: json['text'] as String? ?? '',
      language: json['language'] == null
          ? null
          : TranscriptionLanguage.fromName(json['language'] as String?),
    );
  }

  /// Offset from the start of the recording.
  final Duration start;
  final Duration end;
  final String text;
  final TranscriptionLanguage? language;

  Map<String, dynamic> toJson() => {
        'startMs': start.inMilliseconds,
        'endMs': end.inMilliseconds,
        'text': text,
        if (language != null) 'language': language!.name,
      };
}

/// Transcript plus the languages the recogniser detected while producing it.
@immutable
class TranscriptionResult {
  const TranscriptionResult({
    required this.text,
    required this.languages,
    this.segments = const [],
  });

  final String text;

  /// Languages detected across the recording's speech segments, in the order
  /// first encountered. More than one entry means the speakers switched
  /// language during the recording.
  final List<TranscriptionLanguage> languages;

  /// Per-phrase breakdown with timings, used by search to jump to a moment.
  final List<TranscriptSegment> segments;

  bool get isEmpty => text.trim().isEmpty;
}

/// Thrown by [TranscriptionService.initialize] when the SenseVoice model has
/// not been downloaded yet. Callers should trigger a model download and retry.
class ModelNotReadyException implements Exception {
  const ModelNotReadyException();
  @override
  String toString() => 'Speech-to-text model has not been downloaded yet.';
}

/// Thrown when the shared recogniser is already in use by the other path.
///
/// File transcription and live transcription share one `OfflineRecognizer`
/// (loading a second would cost another ~228 MB). Individual decodes are
/// serialised by [DecodeWorker], but the two *passes* still cannot overlap:
/// each drives a VAD across `await` gaps, and the file pass resets its detector
/// at the start. The UI prevents this by disabling whichever action is not
/// running; this exception is the backstop.
class TranscriptionBusyException implements Exception {
  const TranscriptionBusyException();
  @override
  String toString() => 'The recogniser is already transcribing.';
}

/// Thrown when sherpa-onnx's native library will not load on this device.
///
/// Permanent: a missing `.so`, or an ABI the build does not ship. The device
/// should stop being offered transcription.
class SttNativeUnavailableException implements Exception {
  const SttNativeUnavailableException(this.cause);
  final Object cause;
  @override
  String toString() =>
      'The speech recognition engine is not available on this device: $cause';
}

/// Thrown when the model was found but could not be loaded.
///
/// Note that this only covers *catchable* failures — a bad or truncated model
/// file, a rejected config. A genuine out-of-memory inside onnxruntime never
/// gets here: it aborts the process on Android and is SIGKILLed by jetsam on
/// iOS. That case is caught instead by the breadcrumb
/// `DeviceCapabilityService.recordModelLoadStarted` writes before the load.
class SttModelLoadFailedException implements Exception {
  const SttModelLoadFailedException(this.cause);
  final Object cause;
  @override
  String toString() => 'The speech model could not be loaded: $cause';
}

/// Offline, file-based speech-to-text.
///
/// Given a recorded 16 kHz mono WAV file, this runs Silero VAD to split it into
/// speech segments and transcribes each with the SenseVoice model, returning
/// the concatenated text. There is no real-time/streaming path — transcription
/// is an explicit action the user runs on an already-saved recording.
class TranscriptionService {
  TranscriptionService({DeviceCapabilityService? capabilities})
      : _capabilities = capabilities;

  /// Records whether the model actually loaded, so a device that cannot run it
  /// stops being offered transcription. Optional so the service stays
  /// constructible in tests without a preference store.
  final DeviceCapabilityService? _capabilities;

  static const int _sampleRate = 16000;
  static const int _vadWindowSamples = 512; // Silero VAD window size

  /// Bytes of PCM read from disk at a time.
  ///
  /// 32 KiB is 16384 samples, which is exactly 32 VAD windows, so a read
  /// boundary never splits a window and the loop yields to the event loop about
  /// once per second of audio.
  ///
  /// Reading in chunks is what keeps peak memory flat. Loading the whole file
  /// and converting it in one go — as this did before — allocated a Float32List
  /// of the entire recording: ~460 MB for two hours, on top of the ~228 MB
  /// model, which is an out-of-memory kill on most phones. The storage cap
  /// permits far longer recordings than that.
  static const int _readChunkBytes = 32 * 1024;

  sherpa_onnx.OfflineRecognizer? _recognizer;
  sherpa_onnx.VoiceActivityDetector? _vad;

  /// Decodes utterances off the main isolate. Null only when the isolate could
  /// not be spawned, in which case decoding falls back to this isolate.
  DecodeWorker? _worker;

  /// Language the recogniser was built with. Changing it requires rebuilding
  /// the recogniser, so it is tracked to detect a stale one.
  TranscriptionLanguage _language = TranscriptionLanguage.auto;

  bool get isInitialized => _recognizer != null && _vad != null;

  /// Whether the downloaded STT model is present, without initializing anything.
  Future<bool> isModelReady() => ModelAssetHelper.isModelReady();

  /// Initialize the recognizer and VAD. Throws [ModelNotReadyException] if the
  /// SenseVoice model has not been downloaded yet.
  Future<void> initialize({
    TranscriptionLanguage language = TranscriptionLanguage.auto,
  }) async {
    // The language is baked into the recogniser at construction, so a change
    // means tearing the old one down rather than ignoring the new setting.
    if (isInitialized && language != _language) await dispose();
    if (isInitialized) return;
    _language = language;

    if (!await ModelAssetHelper.isModelReady()) {
      throw const ModelNotReadyException();
    }

    try {
      sherpa_onnx.initBindings();
    } catch (e) {
      // A missing or wrong-ABI native library. Permanent, and distinct from a
      // model problem — the caller turns this into a capability verdict.
      throw SttNativeUnavailableException(e);
    }
    final modelPaths = await ModelAssetHelper.resolveModelPaths();

    final senseVoice = sherpa_onnx.OfflineSenseVoiceModelConfig(
      model: modelPaths.modelPath,
      // Empty means auto-detect, applied per speech segment — which is what
      // makes a conversation that switches language work. Pinning a language
      // helps accuracy when the content is known to be monolingual.
      language: language.code,
      useInverseTextNormalization: true,
    );

    // Everything between the breadcrumb and its clearing is the risky part:
    // loading 228 MB of weights. If the process dies in here — an OOM abort on
    // Android, a jetsam kill on iOS — nothing below runs, and the pending flag
    // left in storage is what tells the next launch this device could not do it.
    await _capabilities?.recordModelLoadStarted();
    try {
      _recognizer = sherpa_onnx.OfflineRecognizer(
        sherpa_onnx.OfflineRecognizerConfig(
          model: sherpa_onnx.OfflineModelConfig(
            senseVoice: senseVoice,
            tokens: modelPaths.tokensPath,
            numThreads: 4,
            debug: false,
          ),
          decodingMethod: 'greedy_search',
          maxActivePaths: 4,
        ),
      );
    } catch (e) {
      await _capabilities?.recordModelLoadFailed(e);
      throw SttModelLoadFailedException(e);
    }
    await _capabilities?.recordModelLoadSucceeded();

    // Decoding runs on a worker isolate against this same native recogniser —
    // see [DecodeWorker] for how the pointer crosses. If the isolate cannot be
    // spawned the service is degraded, not broken: decoding falls back to this
    // isolate, exactly as it behaved before.
    try {
      _worker = await DecodeWorker.spawn(
        recognizerAddress: _recognizer!.ptr.address,
      );
    } catch (e) {
      _worker = null;
      debugPrint('TranscriptionService: decode worker unavailable ($e); '
          'decoding on the main isolate instead');
    }

    _vad = sherpa_onnx.VoiceActivityDetector(
      config: sherpa_onnx.VadModelConfig(
        sileroVad: sherpa_onnx.SileroVadModelConfig(
          model: modelPaths.vadModelPath,
          threshold: 0.5,
          minSilenceDuration: 0.5,
          minSpeechDuration: 0.25,
          windowSize: _vadWindowSamples,
          maxSpeechDuration: 15.0,
        ),
        sampleRate: _sampleRate,
      ),
      bufferSizeInSeconds: 30,
    );

    debugPrint('TranscriptionService initialized (STT + VAD)');
  }

  /// Transcribe a 16 kHz mono PCM16 WAV file and return the recognized text.
  ///
  /// [onProgress] is called with a value in [0.0, 1.0] as the audio is consumed.
  ///
  /// The VAD feed and the decode both run on the calling isolate, and the loop
  /// yields to the event loop regularly so the UI keeps painting (a progress
  /// spinner that cannot animate is worse than no spinner) and the app stays
  /// responsive to taps.
  ///
  /// Note that running on the calling isolate is a choice, not a constraint.
  /// An earlier comment here claimed sherpa_onnx pointers "are not shareable
  /// across isolates" — that is wrong. Every sherpa class exposes a public
  /// `.ptr` and a `fromPtr` constructor, and `Pointer.address` is an int that
  /// crosses a `SendPort`, so a worker isolate can rebuild a handle to the
  /// *same* native object without reloading the model (it must call
  /// `initBindings()` itself, since the bindings are static and therefore
  /// per-isolate). The real constraint is exclusive ownership: the native
  /// objects are not documented as thread-safe, so exactly one isolate may
  /// touch a given recogniser at a time.
  Future<TranscriptionResult> transcribeFile(
    String wavPath, {
    TranscriptionLanguage language = TranscriptionLanguage.auto,
    void Function(double progress)? onProgress,
  }) async {
    await initialize(language: language);

    // The recogniser is shared with the live path and is not safe to drive from
    // both at once — this loop resets the VAD and holds state across awaits.
    if (!tryAcquire()) {
      throw const TranscriptionBusyException();
    }
    try {
      return await _transcribeFileLocked(wavPath, onProgress: onProgress);
    } finally {
      release();
    }
  }

  Future<TranscriptionResult> _transcribeFileLocked(
    String wavPath, {
    void Function(double progress)? onProgress,
  }) async {
    final vad = _vad!;
    vad.reset();

    final buffer = StringBuffer();
    // Preserves first-seen order, so the UI can show which languages appeared
    // and in what order they turned up.
    final detected = <TranscriptionLanguage>[];
    final segments = <TranscriptSegment>[];

    final file = File(wavPath);
    final raf = await file.open();
    try {
      final region = await locatePcmRegion(raf, await file.length());
      if (region.isEmpty) {
        onProgress?.call(1.0);
        return const TranscriptionResult(text: '', languages: []);
      }

      // One reusable window: `acceptWaveform` copies into native memory, so the
      // buffer can be refilled in place instead of allocated per window.
      final window = Float32List(_vadWindowSamples);
      var fill = 0;
      int? pendingByte;

      var position = region.offset;
      final end = region.offset + region.length;
      await raf.setPosition(position);

      while (position < end) {
        final read = await raf.read(math.min(_readChunkBytes, end - position));
        if (read.isEmpty) break;
        position += read.length;

        // A short read can split a sample across chunks; carrying the odd byte
        // over keeps every later sample aligned rather than turning the rest of
        // the recording into noise.
        final Uint8List chunk;
        if (pendingByte == null) {
          chunk = read;
        } else {
          chunk = Uint8List(read.length + 1)
            ..[0] = pendingByte
            ..setRange(1, read.length + 1, read);
          pendingByte = null;
        }
        final wholeSamples = chunk.length ~/ 2;
        if (chunk.length.isOdd) pendingByte = chunk[chunk.length - 1];

        final data = ByteData.sublistView(chunk);
        for (var i = 0; i < wholeSamples; i++) {
          window[fill++] = data.getInt16(i * 2, Endian.little) / 32768.0;
          if (fill < _vadWindowSamples) continue;

          vad.acceptWaveform(window);
          fill = 0;
          while (!vad.isEmpty()) {
            // Pop before awaiting: `front()` hands back a copy of the samples,
            // so draining the queue synchronously keeps the detector's state
            // from straddling a suspension point.
            final speech = vad.front();
            vad.pop();
            await _appendSegment(speech, buffer, detected, segments);
          }
        }

        onProgress?.call((position - region.offset) / region.length);
        // Hand the event loop a turn so the UI can paint. Once per chunk is
        // about once per second of audio; decoding a segment awaits the worker
        // isolate and yields on its own.
        await Future<void>.delayed(Duration.zero);
      }

      // Flush any trailing speech the VAD has not yet emitted. A sub-window
      // tail of under 512 samples (32 ms) is dropped, as it always has been.
      vad.flush();
      while (!vad.isEmpty()) {
        final speech = vad.front();
        vad.pop();
        await _appendSegment(speech, buffer, detected, segments);
      }
    } finally {
      await raf.close();
    }

    onProgress?.call(1.0);
    return TranscriptionResult(
      text: buffer.toString().trim(),
      languages: detected,
      segments: segments,
    );
  }

  Future<void> _appendSegment(
    sherpa_onnx.SpeechSegment segment,
    StringBuffer out,
    List<TranscriptionLanguage> detected,
    List<TranscriptSegment> segments,
  ) async {
    final decoded =
        await decodeSegment(segment.samples, startSamples: segment.start);
    if (decoded == null) return;

    if (out.isNotEmpty) out.write(' ');
    out.write(decoded.text);

    // SenseVoice reports the language it identified for this segment. Segments
    // are decoded independently, so a recording where speakers switch language
    // yields several entries here.
    final language = decoded.language;
    if (language != null && !detected.contains(language)) {
      detected.add(language);
    }
    segments.add(decoded);
  }

  /// Decode one stretch of speech into a [TranscriptSegment], or null when the
  /// recogniser produced nothing.
  ///
  /// Shared by file transcription and the live path so the two can never drift
  /// apart in how they decode, read the detected language, or compute timings.
  ///
  /// [startSamples] is the sample offset of this speech from the start of the
  /// recording; the caller owns that number because the VAD's own `start` is
  /// relative to wherever *it* began being fed, which differs between a
  /// whole-file pass and a live pass that starts mid-recording.
  ///
  /// Runs on the [DecodeWorker] isolate, so awaiting this does not stall the
  /// UI. It falls back to a blocking on-isolate decode only when the worker
  /// could not be spawned.
  ///
  /// Throws if the worker died mid-decode — a lost segment is not silently
  /// swallowed here, because for file transcription that would present an
  /// incomplete transcript as a complete one. The live path catches it and
  /// drops the phrase instead.
  Future<TranscriptSegment?> decodeSegment(
    Float32List samples, {
    required int startSamples,
  }) async {
    if (_recognizer == null || samples.isEmpty) return null;

    final worker = _worker;
    final decoded = worker != null && worker.isRunning
        ? await worker.decode(samples, sampleRate: _sampleRate)
        : _decodeOnThisIsolate(samples);
    if (decoded == null) return null;

    final start =
        Duration(milliseconds: (startSamples * 1000 / _sampleRate).round());
    return TranscriptSegment(
      start: start,
      end: start +
          Duration(milliseconds: (samples.length * 1000 / _sampleRate).round()),
      text: decoded.text,
      language: TranscriptionLanguage.fromTag(decoded.lang),
    );
  }

  /// Decode without leaving this isolate.
  ///
  /// **Blocking** — `decode` is a native call with no yield point, so the
  /// isolate is stalled for its duration. Only reached when [DecodeWorker]
  /// could not be spawned, where a stuttering transcript beats none at all.
  DecodedUtterance? _decodeOnThisIsolate(Float32List samples) {
    final recognizer = _recognizer;
    if (recognizer == null) return null;
    final stream = recognizer.createStream();
    try {
      stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
      recognizer.decode(stream);
      final result = recognizer.getResult(stream);
      final text = result.text.trim();
      if (text.isEmpty) return null;
      return DecodedUtterance(text: text, lang: result.lang);
    } finally {
      stream.free();
    }
  }

  /// Paths needed to build a second VAD for the live path, and proof the model
  /// is loaded. Null until [initialize] has run.
  Future<ModelPaths?> modelPathsIfReady({
    TranscriptionLanguage language = TranscriptionLanguage.auto,
  }) async {
    // Previously this returned null whenever the recogniser had not been built
    // yet, and the recogniser was only ever built by `transcribeFile` or the
    // download sheet. So on a cold launch with the model already on disk, the
    // first live hold reported "Download the voice model first" — the app
    // refusing a capability it had. Loading it here is the correct answer to
    // "is the model ready", and `warmUp` keeps it off the critical path.
    if (!isInitialized) {
      if (!await ModelAssetHelper.isModelReady()) return null;
      try {
        await initialize(language: language);
      } catch (e) {
        debugPrint('TranscriptionService: could not initialize for the live '
            'path: $e');
        return null;
      }
    }
    return ModelAssetHelper.resolveModelPaths();
  }

  /// Build the recogniser ahead of time, ignoring failure.
  ///
  /// Called when recording starts so the ~228 MB load does not happen under a
  /// held finger. Never throws: warming is an optimisation, and anything that
  /// goes wrong here will be reported properly by the real call that follows.
  Future<void> warmUp({
    TranscriptionLanguage language = TranscriptionLanguage.auto,
  }) async {
    if (isInitialized) return;
    if (!await ModelAssetHelper.isModelReady()) return;
    try {
      await initialize(language: language);
    } catch (e) {
      debugPrint('TranscriptionService: warm-up failed: $e');
    }
  }

  /// Guards the shared recogniser.
  ///
  /// One `OfflineRecognizer` is shared between file transcription and the live
  /// path — loading a second would cost another ~228 MB of RAM. The native
  /// object is not documented as thread-safe and `transcribeFile` drives it
  /// across `await` gaps, so the two paths must not interleave. Callers check
  /// this before starting and set it for their duration.
  bool _busy = false;
  bool get isBusy => _busy;

  /// Claims the recogniser, or returns false if the other path already has it.
  bool tryAcquire() {
    if (_busy) return false;
    _busy = true;
    return true;
  }

  void release() => _busy = false;

  /// Tear down the recogniser, the VAD and the decode worker.
  ///
  /// The worker is stopped *first* and awaited: it holds a handle to the same
  /// native recogniser, so freeing that while an inference is still running
  /// would pull the model out from under it.
  Future<void> dispose() async {
    await _worker?.shutdown();
    _worker = null;
    _vad?.free();
    _vad = null;
    _recognizer?.free();
    _recognizer = null;
    debugPrint('TranscriptionService disposed');
  }

}
