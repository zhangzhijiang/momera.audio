import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/audio/silence_gate.dart';

/// A detector driven by a script, one entry per window.
///
/// Anything past the end of the script is silence, so a test only has to say
/// where the speech is.
class _ScriptedDetector implements SpeechDetector {
  _ScriptedDetector(this.script);

  final List<bool> script;
  int calls = 0;
  int resets = 0;
  bool disposed = false;

  @override
  bool detect(Float32List window) {
    final speaking = calls < script.length && script[calls];
    calls++;
    return speaking;
  }

  @override
  void reset() => resets++;

  @override
  void dispose() => disposed = true;
}

/// `count` windows of PCM16, each filled with its own index so the bytes that
/// come out of the gate can be traced back to the window they went in as.
Uint8List _windows(int count, {int from = 0}) {
  final bytes = Uint8List(count * SilenceGate.windowBytes);
  final data = ByteData.sublistView(bytes);
  for (var w = 0; w < count; w++) {
    for (var i = 0; i < SilenceGate.windowSamples; i++) {
      data.setInt16(
        (w * SilenceGate.windowSamples + i) * SilenceGate.bytesPerSample,
        from + w,
        Endian.little,
      );
    }
  }
  return bytes;
}

/// The window indices present in `bytes`, read back from their marker samples.
List<int> _idsOf(Uint8List bytes) {
  expect(bytes.lengthInBytes % SilenceGate.windowBytes, 0,
      reason: 'output should be whole windows');
  final data = ByteData.sublistView(bytes);
  return [
    for (var w = 0; w < bytes.lengthInBytes ~/ SilenceGate.windowBytes; w++)
      data.getInt16(w * SilenceGate.windowBytes, Endian.little),
  ];
}

void main() {
  group('SilenceGate', () {
    test('writes nothing while nobody is speaking', () {
      final detector = _ScriptedDetector(const []);
      final gate = SilenceGate(detector: detector);

      final out = gate.gate(_windows(40));

      expect(out, isEmpty);
      expect(detector.calls, 40, reason: 'every window is still examined');
      expect(gate.isOpen, isFalse);
    });

    test('restores the audio from before speech was detected', () {
      // Silero only asserts speech a quarter-second in, so the first syllable
      // is always already past when the gate opens.
      final detector = _ScriptedDetector([
        ...List.filled(5, false),
        true,
      ]);
      final gate = SilenceGate(detector: detector);

      final out = gate.gate(_windows(6));

      expect(_idsOf(out), [0, 1, 2, 3, 4, 5],
          reason: 'the five silent windows before speech are the pre-roll');
      expect(gate.isOpen, isTrue);
    });

    test('keeps the pre-roll bounded', () {
      // 400 ms at 16 kHz mono PCM16 is 12800 bytes: 12 whole windows.
      final detector = _ScriptedDetector([
        ...List.filled(100, false),
        true,
      ]);
      final gate = SilenceGate(detector: detector);

      final out = gate.gate(_windows(101));

      expect(_idsOf(out), hasLength(13), reason: '12 pre-roll + the speech');
      expect(_idsOf(out).last, 100);
      expect(_idsOf(out).first, 88, reason: 'older audio was dropped');
    });

    test('stays open through the gaps between words', () {
      // 600 ms of hangover is 19200 bytes: silence is written until the run
      // reaches that, so 19 windows survive before the gate closes.
      final detector = _ScriptedDetector([true]);
      final gate = SilenceGate(detector: detector);

      final out = gate.gate(_windows(40));

      expect(_idsOf(out), hasLength(20), reason: '1 speech + 19 hangover');
      expect(gate.isOpen, isFalse, reason: 'the hangover ran out');
    });

    test('a word in the hangover extends it rather than starting over', () {
      final detector = _ScriptedDetector([
        true,
        ...List.filled(5, false),
        true,
        ...List.filled(5, false),
      ]);
      final gate = SilenceGate(detector: detector);

      final out = gate.gate(_windows(12));

      // Continuous: no pre-roll is re-emitted mid-phrase, and nothing is cut.
      expect(_idsOf(out), [0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11]);
      expect(gate.isOpen, isTrue);
    });

    test('chunk boundaries do not change the result', () {
      // record's chunks are not window multiples, and streamBufferSize is only
      // a hint, so the gate must not care where a chunk happens to end.
      List<bool> script() => [
            ...List.filled(3, false),
            ...List.filled(4, true),
            ...List.filled(30, false),
          ];

      final whole = SilenceGate(detector: _ScriptedDetector(script()));
      final expected = whole.gate(_windows(37));

      final split = SilenceGate(detector: _ScriptedDetector(script()));
      final pieces = BytesBuilder();
      final source = _windows(37);
      // Deliberately awkward: 1500 is neither a window multiple nor even.
      for (var offset = 0; offset < source.lengthInBytes; offset += 1500) {
        final end = (offset + 1500).clamp(0, source.lengthInBytes);
        pieces.add(split.gate(Uint8List.sublistView(source, offset, end)));
      }

      expect(pieces.takeBytes(), expected);
    });

    test('an odd-length chunk keeps the stream sample-aligned', () {
      final detector = _ScriptedDetector(List.filled(4, true));
      final gate = SilenceGate(detector: detector);
      final source = _windows(4);

      // Split mid-sample: the odd byte has to be carried, or every sample after
      // it is shifted by one byte and the audio becomes noise.
      final out = BytesBuilder()
        ..add(gate.gate(Uint8List.sublistView(source, 0, 1025)))
        ..add(gate.gate(Uint8List.sublistView(source, 1025)));

      expect(_idsOf(out.takeBytes()), [0, 1, 2, 3]);
    });

    test('output is always input audio, in order, never duplicated', () {
      // The property that makes the feature safe: the gate may drop audio, but
      // it can never invent, reorder or repeat any. Each window carries its own
      // index, so the output can be checked against the stream it came from.
      final detector = _ScriptedDetector([
        ...List.filled(4, false),
        ...List.filled(6, true),
        ...List.filled(3, false),
        ...List.filled(2, true),
        ...List.filled(40, false),
      ]);
      final gate = SilenceGate(detector: detector);

      final ids = _idsOf(gate.gate(_windows(55)));

      expect(ids, isNotEmpty);
      for (var i = 1; i < ids.length; i++) {
        expect(ids[i], greaterThan(ids[i - 1]),
            reason: 'window ${ids[i]} came after ${ids[i - 1]}');
      }
      expect(ids.toSet(), hasLength(ids.length), reason: 'no duplicates');
      expect(ids.every((id) => id >= 0 && id < 55), isTrue);
    });

    test('opens immediately when capture resumes', () {
      // After a pause there is no pre-roll to fall back on, so a user who
      // speaks the instant they resume would lose the quarter-second the
      // detector takes to decide.
      final detector = _ScriptedDetector(const []); // never reports speech
      final gate = SilenceGate(detector: detector);

      gate.openForResume();
      final out = gate.gate(_windows(3));

      expect(_idsOf(out), [0, 1, 2]);
      expect(gate.isOpen, isTrue, reason: 'the hangover has not run out yet');
    });

    test('reset drops buffered audio and the detector state', () {
      final detector = _ScriptedDetector([
        ...List.filled(3, false),
        true,
      ]);
      final gate = SilenceGate(detector: detector);

      gate.gate(_windows(3)); // three silent windows now sit in the pre-roll
      gate.reset();
      final out = gate.gate(_windows(1, from: 90));

      expect(detector.resets, 1);
      expect(_idsOf(out), [90],
          reason: 'pre-roll from before the pause must not be written');
    });

    test('disposing the gate disposes the detector', () {
      final detector = _ScriptedDetector(const []);
      SilenceGate(detector: detector).dispose();
      expect(detector.disposed, isTrue);
    });
  });
}
