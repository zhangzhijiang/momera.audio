import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import 'transcription_service.dart';

/// Converts a live PCM16 chunk stream into transcript segments as they are
/// spoken.
///
/// **This is not streaming recognition.** SenseVoice is a non-streaming
/// (whole-utterance) model — `sherpa_onnx.OnlineModelConfig` has no
/// `senseVoice` field and never will. What happens instead is upstream
/// sherpa-onnx's "VAD + non-streaming ASR" pattern: the live audio is fed to a
/// voice-activity detector, and each *completed utterance* is decoded as soon
/// as the speaker pauses. Text therefore arrives a phrase at a time, not a word
/// at a time.
///
/// The trade is deliberate: it needs no second model (the alternative,
/// a streaming Zipformer, is another download and carries no detected language,
/// losing per-phrase language identification and inverse text normalisation).
///
/// **Owns its own VAD, shares the recogniser.** `silero_vad.onnx` is 644 KB, so
/// a second detector is nearly free and keeps this path from touching the VAD
/// that [TranscriptionService.transcribeFile] resets and drives. The
/// recogniser, at ~228 MB, is shared — guarded by
/// [TranscriptionService.tryAcquire].
class LiveTranscriptionService {
  LiveTranscriptionService(this._transcription);

  final TranscriptionService _transcription;

  static const int _sampleRate = 16000;
  static const int _bytesPerSample = 2;
  static const int _vadWindowSamples = 512;

  /// Longest stretch the VAD will hold before force-emitting a segment.
  ///
  /// Lower than the 15 s used for file transcription: this is the worst-case
  /// wait before the speaker sees *anything*, and it also bounds how long a
  /// single blocking decode can be. File transcription has no such deadline and
  /// benefits from longer segments.
  static const double _maxSpeechSeconds = 7.0;

  sherpa_onnx.VoiceActivityDetector? _vad;

  /// Samples left over from the previous chunk.
  ///
  /// The VAD consumes fixed 512-sample windows and record's chunks are not
  /// multiples of that, so without carrying the remainder forward up to 511
  /// samples would be dropped *per chunk* — cumulative, and audible as clipped
  /// words. (The file path can ignore this because it sees the whole buffer at
  /// once and only loses a sub-window tail at the very end.)
  final List<double> _carry = <double>[];

  /// Sample offset of the first sample in [_carry], from the start of the
  /// recording. Used to give segments timings that line up with what a later
  /// file transcription of the same audio would produce.
  int _carryStartSample = 0;

  bool _running = false;
  bool get isRunning => _running;

  /// Begin a live pass. Returns false if the model is not loaded or the
  /// recogniser is busy with a file transcription.
  ///
  /// [fromByteOffset] is how many bytes of the recording have already been
  /// written, so segment timings are relative to the recording rather than to
  /// when the user started holding the button.
  Future<bool> start({required int fromByteOffset}) async {
    if (_running) return true;

    final paths = await _transcription.modelPathsIfReady();
    if (paths == null) return false;
    if (!_transcription.tryAcquire()) return false;

    try {
      _vad = sherpa_onnx.VoiceActivityDetector(
        config: sherpa_onnx.VadModelConfig(
          sileroVad: sherpa_onnx.SileroVadModelConfig(
            model: paths.vadModelPath,
            threshold: 0.5,
            minSilenceDuration: 0.25,
            minSpeechDuration: 0.25,
            windowSize: _vadWindowSamples,
            maxSpeechDuration: _maxSpeechSeconds,
          ),
          sampleRate: _sampleRate,
        ),
        // Enough headroom for one maximum-length utterance plus slack.
        bufferSizeInSeconds: 15,
      );
    } catch (e) {
      _transcription.release();
      debugPrint('LiveTranscriptionService: could not build VAD: $e');
      return false;
    }

    _carry.clear();
    _pendingByte = null;
    _carryStartSample = fromByteOffset ~/ _bytesPerSample;
    _running = true;
    return true;
  }

  /// Feed one chunk of recorded PCM16.
  ///
  /// Returns the segments that completed on this chunk — usually none, and one
  /// when the speaker finishes a phrase.
  ///
  /// **Blocking while decoding.** Each completed utterance is decoded inline
  /// with a native call that cannot yield. Segments are capped at
  /// [_maxSpeechSeconds] to bound that.
  List<TranscriptSegment> feed(Uint8List pcm) {
    if (!_running || _vad == null || pcm.isEmpty) return const [];

    _appendToCarry(pcm);

    final segments = <TranscriptSegment>[];
    final vad = _vad!;

    var consumed = 0;
    while (_carry.length - consumed >= _vadWindowSamples) {
      final window = Float32List.fromList(
        _carry.sublist(consumed, consumed + _vadWindowSamples),
      );
      vad.acceptWaveform(window);
      consumed += _vadWindowSamples;

      while (!vad.isEmpty()) {
        final segment = vad.front();
        final decoded = _transcription.decodeSegment(
          segment.samples,
          // The VAD's own `start` counts from where this pass began feeding,
          // so shift it to the recording's timeline.
          startSamples: _carryStartSample + segment.start,
        );
        vad.pop();
        if (decoded != null) segments.add(decoded);
      }
    }

    if (consumed > 0) {
      _carry.removeRange(0, consumed);
      _carryStartSample += consumed;
    }
    return segments;
  }

  /// Stop the pass and return any trailing speech the VAD had not yet emitted.
  List<TranscriptSegment> stop() {
    if (!_running) return const [];
    _running = false;

    final segments = <TranscriptSegment>[];
    final vad = _vad;
    if (vad != null) {
      try {
        vad.flush();
        while (!vad.isEmpty()) {
          final segment = vad.front();
          final decoded = _transcription.decodeSegment(
            segment.samples,
            startSamples: _carryStartSample + segment.start,
          );
          vad.pop();
          if (decoded != null) segments.add(decoded);
        }
      } catch (e) {
        debugPrint('LiveTranscriptionService: flush failed: $e');
      }
      vad.free();
    }
    _vad = null;
    _carry.clear();
    _pendingByte = null;
    _transcription.release();
    return segments;
  }

  void _appendToCarry(Uint8List pcm) {
    // A chunk that ends mid-sample would misalign every sample after it, so an
    // odd trailing byte is held over and prefixed to the next chunk. Chunk
    // sizes should always be even for PCM16, but the cost of being wrong here
    // is total garbage rather than a small glitch.
    final Uint8List bytes;
    if (_pendingByte == null) {
      bytes = pcm;
    } else {
      bytes = Uint8List(pcm.lengthInBytes + 1)
        ..[0] = _pendingByte!
        ..setRange(1, pcm.lengthInBytes + 1, pcm);
      _pendingByte = null;
    }

    final wholeSamples = bytes.lengthInBytes ~/ _bytesPerSample;
    if (bytes.lengthInBytes.isOdd) {
      _pendingByte = bytes[bytes.lengthInBytes - 1];
    }

    // PCM16 little-endian → normalised float, matching the file path's
    // conversion so the recogniser sees identical input either way.
    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < wholeSamples; i++) {
      _carry.add(data.getInt16(i * _bytesPerSample, Endian.little) / 32768.0);
    }
  }

  /// Trailing byte of an odd-length chunk, prefixed to the next one.
  int? _pendingByte;

  void dispose() {
    if (_running) stop();
  }
}
