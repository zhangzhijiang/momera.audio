import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../utils/model_asset_helper.dart';
import '../audio/silence_gate.dart';

/// [SpeechDetector] backed by Silero VAD.
///
/// Deliberately independent of `TranscriptionService`: skip-silence must work on
/// a device that has never downloaded the 228 MB speech model, and the detector
/// it needs is 644 KB and bundled. It also keeps its own detector rather than
/// borrowing the transcription one, because the two have different lifetimes —
/// this one lives for a whole recording, and resetting a shared detector under
/// the live transcript would corrupt its segmentation.
///
/// Only [sherpa_onnx.VoiceActivityDetector.isDetected] is used; the segment
/// queue is drained and thrown away. See [SilenceGate] for why the gate cannot
/// wait for segments.
class VadSpeechDetector implements SpeechDetector {
  VadSpeechDetector._(this._vad);

  final sherpa_onnx.VoiceActivityDetector _vad;
  bool _disposed = false;

  /// Whether the native library could not be loaded, remembered across
  /// attempts.
  ///
  /// `initBindings()` resolves a lazy `final` that opens a ~29 MB shared
  /// library; if that throws once it throws on every subsequent access, so
  /// retrying buys the same failure again. `DeviceCapabilityService` memoises
  /// its own native probe for the same reason.
  static bool _nativeUnavailable = false;

  /// Build a detector, or return null if this device cannot run one.
  ///
  /// Null is not a failure to report as an error: the caller keeps recording
  /// everything and tells the user the feature is unavailable. Reasons include a
  /// 32-bit process, a missing native library, or the asset copy failing.
  static Future<VadSpeechDetector?> tryCreate() async {
    if (_nativeUnavailable) return null;
    try {
      final modelPath = await ModelAssetHelper.resolveVadModelPath();
      // Idempotent: `_dylib` is opened once per isolate and this only rebinds
      // symbols onto it, so calling it here as well as in TranscriptionService
      // is safe.
      sherpa_onnx.initBindings();

      final vad = sherpa_onnx.VoiceActivityDetector(
        config: sherpa_onnx.VadModelConfig(
          sileroVad: sherpa_onnx.SileroVadModelConfig(
            model: modelPath,
            threshold: 0.5,
            // Deliberately far lower than the transcription paths' 0.5.
            // `isDetected()` stays true until this much silence has already
            // passed, so a large value would add its tail on top of the gate's
            // own hangover. Letting the gate own the tail keeps the total
            // predictable — and testable.
            minSilenceDuration: 0.1,
            minSpeechDuration: 0.25,
            windowSize: SilenceGate.windowSamples,
            // The segment queue is unused, but the detector still buffers
            // speech into it. A short cap keeps that buffer from growing
            // through a long monologue.
            maxSpeechDuration: 5.0,
          ),
          sampleRate: SilenceGate.sampleRate,
          // Defaults to true, which would log a line per 32 ms window for the
          // length of every recording.
          debug: false,
        ),
        bufferSizeInSeconds: 10,
      );
      return VadSpeechDetector._(vad);
    } catch (e) {
      _nativeUnavailable = true;
      debugPrint('VadSpeechDetector: could not build a detector: $e');
      return null;
    }
  }

  @override
  bool detect(Float32List window) {
    if (_disposed) return false;
    _vad.acceptWaveform(window);
    // The gate keeps its own audio, so completed segments are only a buffer
    // that would grow without bound if it were never drained.
    while (!_vad.isEmpty()) {
      _vad.pop();
    }
    return _vad.isDetected();
  }

  @override
  void reset() {
    if (_disposed) return;
    _vad.reset();
    _vad.clear();
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _vad.free();
  }
}
