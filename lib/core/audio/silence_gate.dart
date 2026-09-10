import 'dart:typed_data';

/// Decides, one window at a time, whether speech is in progress.
///
/// The seam exists so [SilenceGate]'s buffering can be tested with a scripted
/// fake: the real implementation wraps a native Silero VAD, which cannot be
/// built in a widget test.
abstract class SpeechDetector {
  /// True while speech is in progress. [window] holds exactly
  /// [SilenceGate.windowSamples] normalised samples and is **reused between
  /// calls** — implementations must not retain it.
  bool detect(Float32List window);

  /// Forget everything heard so far, e.g. across a pause.
  void reset();

  void dispose();
}

/// Drops silence from a PCM16 stream, keeping speech.
///
/// **Why a gate rather than the VAD's segment queue.** sherpa's
/// `VoiceActivityDetector` can hand back whole utterances, but only once they
/// are over — a segment appears half a second after the speaker stops, or up to
/// `maxSpeechDuration` later. Recording cannot wait that long: audio sitting in
/// the detector's buffer is audio that a crash loses, which would break the
/// guarantee that at most one flush interval is ever at risk. So the detector is
/// used only for its `isDetected()` verdict, and this class decides which of the
/// *original bytes* to keep. Audio that survives the gate is bit-identical to
/// what the app would have written with the feature off.
///
/// **Pre-roll and hangover** are what keep the result listenable:
///
/// * The detector only asserts speech a quarter-second in (`minSpeechDuration`),
///   so the moment it says "speech" the first syllable is already past. A
///   rolling [preRoll] of recent audio is written first, restoring the onset.
/// * Speech is not continuous — there are gaps between words. Closing the gate
///   the instant the detector goes quiet would chop the tail off every phrase
///   and stutter through the gaps, so it stays open for [hangover] after.
class SilenceGate {
  SilenceGate({
    required SpeechDetector detector,
    this.preRoll = const Duration(milliseconds: 400),
    this.hangover = const Duration(milliseconds: 600),
  }) : _detector = detector;

  /// The window size Silero VAD requires at 16 kHz.
  static const int windowSamples = 512;

  static const int sampleRate = 16000;
  static const int bytesPerSample = 2;

  /// 1024 bytes — 32 ms of audio, the gate's decision granularity.
  static const int windowBytes = windowSamples * bytesPerSample;

  final SpeechDetector _detector;

  /// How much audio from before speech was detected is kept.
  final Duration preRoll;

  /// How long the gate stays open after speech stops.
  final Duration hangover;

  /// Bytes not yet forming a whole window, carried to the next chunk.
  ///
  /// Chunks from `record` are not multiples of the window size — and
  /// `streamBufferSize` is documented as a hint the platform may override — so
  /// without this up to a window of audio would be dropped per chunk, which is
  /// cumulative and audible. Carrying the remainder also keeps sample alignment
  /// when a chunk ends on an odd byte: windows are always cut on 1024-byte
  /// boundaries of one continuous stream. (`LiveTranscriptionService` solves the
  /// same problem for the transcript path, but over floats, since it has no use
  /// for the original bytes.)
  Uint8List _carry = Uint8List(0);

  /// Recent silent windows, kept in case speech starts in the next one.
  final List<Uint8List> _preRollWindows = [];
  int _preRollBytes = 0;

  bool _open = false;

  /// Silence written since the detector last reported speech, in bytes.
  int _silentRun = 0;

  /// Reused so a long recording does not allocate a window per 32 ms.
  final Float32List _window = Float32List(windowSamples);

  int get _preRollLimit => _bytesForDuration(preRoll);
  int get _hangoverLimit => _bytesForDuration(hangover);

  static int _bytesForDuration(Duration d) =>
      (d.inMilliseconds * sampleRate ~/ 1000) * bytesPerSample;

  /// True while audio is being let through.
  bool get isOpen => _open;

  /// Filter one chunk of PCM16, returning the bytes that should be written.
  ///
  /// The result is empty during silence. It can be *longer* than [chunk] on the
  /// window where speech starts, because the pre-roll is flushed then.
  Uint8List gate(Uint8List chunk) {
    final input = _withCarry(chunk);
    final windows = input.lengthInBytes ~/ windowBytes;
    if (windows == 0) {
      _carry = Uint8List.fromList(input);
      return Uint8List(0);
    }

    // Copying: what comes out of here is handed to an IOSink, which writes it
    // asynchronously, and to the live-transcript tee. Neither may be given a
    // view onto a buffer this class still owns.
    final out = BytesBuilder(copy: true);
    for (var i = 0; i < windows; i++) {
      final start = i * windowBytes;
      final window = Uint8List.sublistView(input, start, start + windowBytes);
      _consume(window, out);
    }

    // Copied off `input` so a whole chunk is not retained for the sake of a
    // few undecided bytes.
    _carry = Uint8List.fromList(
        Uint8List.sublistView(input, windows * windowBytes));
    return out.takeBytes();
  }

  void _consume(Uint8List window, BytesBuilder out) {
    if (_detector.detect(_toFloat(window))) {
      if (!_open) {
        _open = true;
        // The speech started before the detector noticed. Restore it.
        for (final held in _preRollWindows) {
          out.add(held);
        }
        _clearPreRoll();
      }
      _silentRun = 0;
      out.add(window);
      return;
    }

    if (_open && _silentRun < _hangoverLimit) {
      _silentRun += windowBytes;
      out.add(window);
      return;
    }

    _open = false;
    _rememberForPreRoll(window);
  }

  /// PCM16 little-endian to normalised float, matching the conversion the
  /// transcription paths use so the detector sees the same input either way.
  Float32List _toFloat(Uint8List window) {
    final data = ByteData.sublistView(window);
    for (var i = 0; i < windowSamples; i++) {
      _window[i] = data.getInt16(i * bytesPerSample, Endian.little) / 32768.0;
    }
    return _window;
  }

  Uint8List _withCarry(Uint8List chunk) {
    if (_carry.isEmpty) return chunk;
    final joined = Uint8List(_carry.lengthInBytes + chunk.lengthInBytes)
      ..setRange(0, _carry.lengthInBytes, _carry)
      ..setRange(_carry.lengthInBytes, _carry.lengthInBytes + chunk.lengthInBytes,
          chunk);
    return joined;
  }

  void _rememberForPreRoll(Uint8List window) {
    // Copied because the window is a view onto the joined buffer, which would
    // otherwise be retained whole for as long as the pre-roll holds it.
    _preRollWindows.add(Uint8List.fromList(window));
    _preRollBytes += windowBytes;
    while (_preRollBytes > _preRollLimit && _preRollWindows.isNotEmpty) {
      _preRollBytes -= _preRollWindows.removeAt(0).lengthInBytes;
    }
  }

  void _clearPreRoll() {
    _preRollWindows.clear();
    _preRollBytes = 0;
  }

  /// Start letting audio through immediately, with a full hangover to spend.
  ///
  /// Used when capture resumes and when the feature is switched on mid-
  /// recording. In both cases the pre-roll is empty, so a user who speaks the
  /// instant they resume would otherwise lose the quarter-second the detector
  /// takes to make up its mind. Opening first and letting the hangover expire
  /// costs at most [hangover] of silence; the alternative costs a word.
  void openForResume() {
    _open = true;
    _silentRun = 0;
  }

  /// Forget everything buffered — used across a pause, so resuming cannot emit
  /// pre-roll captured before it.
  void reset() {
    _carry = Uint8List(0);
    _clearPreRoll();
    _open = false;
    _silentRun = 0;
    _detector.reset();
  }

  void dispose() => _detector.dispose();
}
