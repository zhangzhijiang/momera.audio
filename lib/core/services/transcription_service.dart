import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../utils/model_asset_helper.dart';

/// Languages the SenseVoice model can recognise.
///
/// The checkpoint is `sense-voice-zh-en-ja-ko-yue`, and those five are the
/// whole list. The token vocabulary contains tags for many more languages
/// (inherited from the vocab it was built on) but this checkpoint is not
/// trained for them — notably **Spanish is not supported**, even though the app
/// UI is available in Spanish.
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
/// (loading a second would cost another ~228 MB), and it cannot be driven from
/// both at once. The UI prevents this by disabling whichever action is not
/// running; this exception is the backstop.
class TranscriptionBusyException implements Exception {
  const TranscriptionBusyException();
  @override
  String toString() => 'The recogniser is already transcribing.';
}

/// Offline, file-based speech-to-text.
///
/// Given a recorded 16 kHz mono WAV file, this runs Silero VAD to split it into
/// speech segments and transcribes each with the SenseVoice model, returning
/// the concatenated text. There is no real-time/streaming path — transcription
/// is an explicit action the user runs on an already-saved recording.
class TranscriptionService {
  static const int _sampleRate = 16000;
  static const int _vadWindowSamples = 512; // Silero VAD window size

  /// VAD windows to process between yields to the event loop. 512 samples is
  /// 32 ms of audio, so this is roughly a second of audio per yield — often
  /// enough to keep the UI smooth, rare enough not to dominate the run.
  static const int _yieldThreshold = 32;

  sherpa_onnx.OfflineRecognizer? _recognizer;
  sherpa_onnx.VoiceActivityDetector? _vad;

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
    if (isInitialized && language != _language) dispose();
    if (isInitialized) return;
    _language = language;

    if (!await ModelAssetHelper.isModelReady()) {
      throw const ModelNotReadyException();
    }

    sherpa_onnx.initBindings();
    final modelPaths = await ModelAssetHelper.resolveModelPaths();

    final senseVoice = sherpa_onnx.OfflineSenseVoiceModelConfig(
      model: modelPaths.modelPath,
      // Empty means auto-detect, applied per speech segment — which is what
      // makes a conversation that switches language work. Pinning a language
      // helps accuracy when the content is known to be monolingual.
      language: language.code,
      useInverseTextNormalization: true,
    );
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

    _vad = sherpa_onnx.VoiceActivityDetector(
      config: sherpa_onnx.VadModelConfig(
        sileroVad: sherpa_onnx.SileroVadModelConfig(
          model: modelPaths.vadModelPath,
          threshold: 0.5,
          minSilenceDuration: 0.25,
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
    final bytes = await File(wavPath).readAsBytes();
    final pcm = _extractPcmData(bytes);
    final samples = _convertPcm16ToFloat32(pcm);

    final vad = _vad!;
    vad.reset();

    final buffer = StringBuffer();
    // Preserves first-seen order, so the UI can show which languages appeared
    // and in what order they turned up.
    final detected = <TranscriptionLanguage>[];
    final segments = <TranscriptSegment>[];

    // Feed the audio to the VAD in fixed windows and transcribe each completed
    // speech segment.
    int offset = 0;
    int sinceYield = 0;
    while (offset + _vadWindowSamples <= samples.length) {
      final window =
          Float32List.sublistView(samples, offset, offset + _vadWindowSamples);
      vad.acceptWaveform(window);
      while (!vad.isEmpty()) {
        _appendSegment(vad.front(), buffer, detected, segments);
        vad.pop();
        // Decoding a segment is the expensive step; always yield after one.
        sinceYield = _yieldThreshold;
      }
      offset += _vadWindowSamples;

      sinceYield++;
      if (sinceYield >= _yieldThreshold) {
        sinceYield = 0;
        onProgress?.call(offset / samples.length);
        // Hand the event loop a turn so the UI can paint.
        await Future<void>.delayed(Duration.zero);
      }
    }

    // Flush any trailing speech the VAD has not yet emitted.
    vad.flush();
    while (!vad.isEmpty()) {
      _appendSegment(vad.front(), buffer, detected, segments);
      vad.pop();
      await Future<void>.delayed(Duration.zero);
    }

    onProgress?.call(1.0);
    return TranscriptionResult(
      text: buffer.toString().trim(),
      languages: detected,
      segments: segments,
    );
  }

  void _appendSegment(
    sherpa_onnx.SpeechSegment segment,
    StringBuffer out,
    List<TranscriptionLanguage> detected,
    List<TranscriptSegment> segments,
  ) {
    final decoded = decodeSegment(segment.samples, startSamples: segment.start);
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
  /// **Blocking.** `decode` is a native call with no yield point inside it, so
  /// the calling isolate is stalled for its duration.
  TranscriptSegment? decodeSegment(
    Float32List samples, {
    required int startSamples,
  }) {
    if (_recognizer == null || samples.isEmpty) return null;
    final stream = _recognizer!.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
    _recognizer!.decode(stream);
    final result = _recognizer!.getResult(stream);
    stream.free();

    final text = result.text.trim();
    if (text.isEmpty) return null;

    final start =
        Duration(milliseconds: (startSamples * 1000 / _sampleRate).round());
    return TranscriptSegment(
      start: start,
      end: start +
          Duration(milliseconds: (samples.length * 1000 / _sampleRate).round()),
      text: text,
      language: TranscriptionLanguage.fromTag(result.lang),
    );
  }

  /// Paths needed to build a second VAD for the live path, and proof the model
  /// is loaded. Null until [initialize] has run.
  Future<ModelPaths?> modelPathsIfReady() async {
    if (!isInitialized) return null;
    return ModelAssetHelper.resolveModelPaths();
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

  void dispose() {
    _vad?.free();
    _vad = null;
    _recognizer?.free();
    _recognizer = null;
    debugPrint('TranscriptionService disposed');
  }

  // --- WAV / PCM helpers ----------------------------------------------------

  /// Extract the raw PCM bytes from a WAV file by locating its `data` chunk.
  /// Falls back to skipping the canonical 44-byte header if no chunk is found.
  Uint8List _extractPcmData(Uint8List bytes) {
    if (bytes.length < 44) return Uint8List(0);
    final data = ByteData.sublistView(bytes);

    // Walk chunks after the 12-byte RIFF header to find "data".
    int offset = 12;
    while (offset + 8 <= bytes.length) {
      final id = String.fromCharCodes(bytes.sublist(offset, offset + 4));
      final size = data.getUint32(offset + 4, Endian.little);
      final body = offset + 8;
      if (id == 'data') {
        final end = (body + size <= bytes.length) ? body + size : bytes.length;
        return Uint8List.sublistView(bytes, body, end);
      }
      // Chunks are word-aligned (padded to even length).
      offset = body + size + (size.isOdd ? 1 : 0);
    }
    return Uint8List.sublistView(bytes, 44);
  }

  Float32List _convertPcm16ToFloat32(Uint8List pcm16) {
    final numSamples = pcm16.length ~/ 2;
    final out = Float32List(numSamples);
    final data = ByteData.sublistView(pcm16);
    for (int i = 0; i < numSamples; i++) {
      out[i] = data.getInt16(i * 2, Endian.little) / 32768.0;
    }
    return out;
  }
}
