import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../utils/model_asset_helper.dart';

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

  sherpa_onnx.OfflineRecognizer? _recognizer;
  sherpa_onnx.VoiceActivityDetector? _vad;

  bool get isInitialized => _recognizer != null && _vad != null;

  /// Whether the downloaded STT model is present, without initializing anything.
  Future<bool> isModelReady() => ModelAssetHelper.isModelReady();

  /// Initialize the recognizer and VAD. Throws [ModelNotReadyException] if the
  /// SenseVoice model has not been downloaded yet.
  Future<void> initialize() async {
    if (isInitialized) return;

    if (!await ModelAssetHelper.isModelReady()) {
      throw const ModelNotReadyException();
    }

    sherpa_onnx.initBindings();
    final modelPaths = await ModelAssetHelper.resolveModelPaths();

    final senseVoice = sherpa_onnx.OfflineSenseVoiceModelConfig(
      model: modelPaths.modelPath,
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
  Future<String> transcribeFile(String wavPath) async {
    if (!isInitialized) await initialize();

    final bytes = await File(wavPath).readAsBytes();
    final pcm = _extractPcmData(bytes);
    final samples = _convertPcm16ToFloat32(pcm);

    final vad = _vad!;
    vad.reset();

    final buffer = StringBuffer();

    // Feed the audio to the VAD in fixed windows and transcribe each completed
    // speech segment.
    int offset = 0;
    while (offset + _vadWindowSamples <= samples.length) {
      final window =
          Float32List.sublistView(samples, offset, offset + _vadWindowSamples);
      vad.acceptWaveform(window);
      while (!vad.isEmpty()) {
        _appendSegment(vad.front().samples, buffer);
        vad.pop();
      }
      offset += _vadWindowSamples;
    }

    // Flush any trailing speech the VAD has not yet emitted.
    vad.flush();
    while (!vad.isEmpty()) {
      _appendSegment(vad.front().samples, buffer);
      vad.pop();
    }

    return buffer.toString().trim();
  }

  void _appendSegment(Float32List samples, StringBuffer out) {
    if (_recognizer == null || samples.isEmpty) return;
    final stream = _recognizer!.createStream();
    stream.acceptWaveform(samples: samples, sampleRate: _sampleRate);
    _recognizer!.decode(stream);
    final result = _recognizer!.getResult(stream);
    stream.free();
    if (result.text.trim().isNotEmpty) {
      if (out.isNotEmpty) out.write(' ');
      out.write(result.text.trim());
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
