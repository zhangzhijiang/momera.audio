import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// Mirrors the PCM16 → float carry logic in
/// `LiveTranscriptionService._appendToCarry` / `feed`.
///
/// The real class cannot be unit-tested directly without a loaded 228 MB model
/// and a native VAD, so the sample-accounting — the part that silently corrupts
/// a transcript when it is wrong — is reproduced here and checked against the
/// same invariants.
class _CarryHarness {
  static const int windowSamples = 512;
  static const int bytesPerSample = 2;

  final List<double> _carry = <double>[];
  int? _pendingByte;

  /// Windows handed to the VAD, in order.
  final List<Float32List> windows = [];

  void feed(Uint8List pcm) {
    final Uint8List bytes;
    if (_pendingByte == null) {
      bytes = pcm;
    } else {
      bytes = Uint8List(pcm.lengthInBytes + 1)
        ..[0] = _pendingByte!
        ..setRange(1, pcm.lengthInBytes + 1, pcm);
      _pendingByte = null;
    }

    final wholeSamples = bytes.lengthInBytes ~/ bytesPerSample;
    if (bytes.lengthInBytes.isOdd) {
      _pendingByte = bytes[bytes.lengthInBytes - 1];
    }

    final data = ByteData.sublistView(bytes);
    for (var i = 0; i < wholeSamples; i++) {
      _carry.add(data.getInt16(i * bytesPerSample, Endian.little) / 32768.0);
    }

    var consumed = 0;
    while (_carry.length - consumed >= windowSamples) {
      windows.add(Float32List.fromList(
        _carry.sublist(consumed, consumed + windowSamples),
      ));
      consumed += windowSamples;
    }
    if (consumed > 0) _carry.removeRange(0, consumed);
  }

  int get pendingSamples => _carry.length;
  bool get hasPendingByte => _pendingByte != null;

  /// Every sample the VAD has seen, flattened.
  List<double> get delivered => [for (final w in windows) ...w];
}

/// Little-endian PCM16 for [values].
Uint8List _pcm(List<int> values) {
  final bytes = Uint8List(values.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < values.length; i++) {
    data.setInt16(i * 2, values[i], Endian.little);
  }
  return bytes;
}

void main() {
  group('live PCM carry buffer', () {
    test('delivers whole windows and holds the remainder', () {
      final h = _CarryHarness();
      // 700 samples = one 512 window, 188 left over.
      h.feed(_pcm(List.generate(700, (i) => i)));
      expect(h.windows, hasLength(1));
      expect(h.pendingSamples, 188);
    });

    test('loses no samples across arbitrary chunk sizes', () {
      // The bug this guards: feeding each chunk independently and dropping the
      // sub-window tail loses up to 511 samples PER CHUNK — cumulative, and
      // audible as clipped words.
      final rng = Random(20260905);
      final h = _CarryHarness();

      final all = <int>[];
      var next = 0;
      for (var chunk = 0; chunk < 60; chunk++) {
        final count = 1 + rng.nextInt(1500);
        final values = List.generate(count, (_) => (next++ % 30000) - 15000);
        all.addAll(values);
        h.feed(_pcm(values));
      }

      final expectedWindows = all.length ~/ 512;
      expect(h.windows, hasLength(expectedWindows));
      expect(h.pendingSamples, all.length % 512);

      // Every delivered sample must equal the source, in order.
      final delivered = h.delivered;
      expect(delivered, hasLength(expectedWindows * 512));
      for (var i = 0; i < delivered.length; i++) {
        expect(delivered[i], closeTo(all[i] / 32768.0, 1e-9),
            reason: 'sample $i differs — the stream is misaligned');
      }
    });

    test('an odd-length chunk does not misalign the stream', () {
      // A chunk ending mid-sample is unexpected for PCM16, but dropping the
      // stray byte would shift every subsequent sample by one byte and turn the
      // whole transcript into noise. The byte is carried instead.
      final h = _CarryHarness();
      final full = _pcm(List.generate(1024, (i) => i - 512));

      // Split so the first part ends on an odd byte boundary.
      h.feed(Uint8List.sublistView(full, 0, 401));
      expect(h.hasPendingByte, isTrue);
      h.feed(Uint8List.sublistView(full, 401));
      expect(h.hasPendingByte, isFalse);

      expect(h.windows, hasLength(2));
      final delivered = h.delivered;
      for (var i = 0; i < delivered.length; i++) {
        expect(delivered[i], closeTo((i - 512) / 32768.0, 1e-9),
            reason: 'sample $i misaligned after an odd-length chunk');
      }
    });

    test('a chunk smaller than one window produces nothing yet', () {
      final h = _CarryHarness();
      h.feed(_pcm(List.filled(100, 1)));
      expect(h.windows, isEmpty);
      expect(h.pendingSamples, 100);
    });

    test('many tiny chunks still assemble a full window', () {
      final h = _CarryHarness();
      for (var i = 0; i < 512; i++) {
        h.feed(_pcm([i]));
      }
      expect(h.windows, hasLength(1));
      expect(h.pendingSamples, 0);
    });

    test('an empty chunk is harmless', () {
      final h = _CarryHarness();
      h.feed(Uint8List(0));
      expect(h.windows, isEmpty);
      expect(h.pendingSamples, 0);
    });
  });
}
