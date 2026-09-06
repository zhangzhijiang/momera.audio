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

/// Transcript plus the languages the recogniser detected while producing it.
@immutable
class TranscriptionResult {
  const TranscriptionResult({required this.text, required this.languages});

  final String text;

  /// Languages detected across the recording's speech segments, in the order
  /// first encountered. More than one entry means the speakers switched
  /// language during the recording.
  final List<TranscriptionLanguage> languages;

  bool get isEmpty => text.trim().isEmpty;
}

/// Thrown by [TranscriptionService.initialize] when the SenseVoice model has
/// not been downloaded yet. Callers should trigger a model download and retry.
class ModelNotReadyException implements Exception {
  const ModelNotReadyException();
  @override
  String toString() => 'Speech-to-text model has not been downloaded yet.';
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
  /// The VAD feed and the decode both run on the calling isolate — sherpa_onnx
  /// holds native pointers that are not shareable across isolates, and the
  /// model is far too expensive to load per transcription. Instead the loop
  /// yields to the event loop regularly, so the UI keeps painting (a progress
  /// spinner that cannot animate is worse than no spinner) and the app stays
  /// responsive to taps.
  Future<TranscriptionResult> transcribeFile(
    String wavPath, {
    TranscriptionLanguage language = TranscriptionLanguage.auto,
    void Function(double progress)? onProgress,
  }) async {
    await initialize(language: language);

    final bytes = await File(wavPath).readAsBytes();
    final pcm = _extractPcmData(bytes);
    final samples = _convertPcm16ToFloat32(pcm);

    final vad = _vad!;
    vad.reset();

    final buffer = StringBuffer();
    // Preserves first-seen order, so the UI can show which languages appeared
    // and in what order they turned up.
    final detected = <TranscriptionLanguage>[];

    // Feed the audio to the VAD in fixed windows and transcribe each completed
    // speech segment.
    int offset = 0;
    int sinceYield = 0;
    while (offset + _vadWindowSamples <= samples.length) {
      final window =
          Float32List.sublistView(samples, offset, offset + _vadWindowSamples);
      vad.acceptWaveform(window);
      while (!vad.isEmpty()) {
        _appendSegment(vad.front().samples, buffer, detected);
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
      _appendSegment(vad.front().samples, buffer, detected);
      vad.pop();
      await Future<void>.delayed(Duration.zero);
    }

    onProgress?.call(1.0);
    return TranscriptionResult(
      text: buffer.toString().trim(),
      languages: detected,
    );
  }

  void _appendSegment(
    Float32List samples,
    StringBuffer out,
    List<TranscriptionLanguage> detected,
  ) {
    if (_recognizer == null || samples.isEmpty) return;
    final stream = _recognizer!.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
    _recognizer!.decode(stream);
    final result = _recognizer!.getResult(stream);
    stream.free();
    if (result.text.trim().isEmpty) return;

    if (out.isNotEmpty) out.write(' ');
    out.write(result.text.trim());

    // SenseVoice reports the language it identified for this segment. Segments
    // are decoded independently, so a recording where speakers switch language
    // yields several entries here.
    final language = TranscriptionLanguage.fromTag(result.lang);
    if (language != null && !detected.contains(language)) {
      detected.add(language);
    }
  }

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
