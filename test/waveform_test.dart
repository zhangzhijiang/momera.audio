import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/audio/waveform.dart';
import 'package:momera_recording/core/audio/wav.dart';

/// Little-endian PCM16 for [samples].
Uint8List _pcm(List<int> samples) {
  final bytes = Uint8List(samples.length * 2);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < samples.length; i++) {
    data.setInt16(i * 2, samples[i], Endian.little);
  }
  return bytes;
}

/// A complete WAV file wrapping [pcm].
Uint8List _wav(Uint8List pcm) => Uint8List.fromList([
      ...buildWavHeader(dataBytes: pcm.length),
      ...pcm,
    ]);

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('waveform_test');
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  /// Writes [bytes] to a file and computes its peaks.
  Future<PeakData?> peaksOf(Uint8List bytes, {int buckets = 16}) async {
    final file = File('${dir.path}/probe.wav');
    await file.writeAsBytes(bytes);
    return computePeaks(file.path, buckets: buckets);
  }

  group('computePeaks', () {
    test('a full-scale square wave peaks at the top of the range', () async {
      final peaks = await peaksOf(_wav(_pcm(List.filled(4096, 32767))));

      expect(peaks, isNotNull);
      expect(peaks!.values.length, 16);
      expect(peaks.values.every((v) => v >= 254), isTrue,
          reason: 'got ${peaks.values}');
    });

    test('silence is flat zero', () async {
      final peaks = await peaksOf(_wav(_pcm(List.filled(4096, 0))));

      expect(peaks!.values.every((v) => v == 0), isTrue);
    });

    test('a back-loaded ramp is louder at the end than the start', () async {
      // Quiet first half, loud second half.
      final samples = [
        ...List.filled(2048, 1000),
        ...List.filled(2048, 30000),
      ];
      final peaks = await peaksOf(_wav(_pcm(samples)));

      expect(peaks!.values.first, lessThan(peaks.values.last));
      expect(peaks.values.first, lessThan(30));
      expect(peaks.values.last, greaterThan(200));
    });

    test('negative swings count as loudly as positive ones', () async {
      // Max-abs, not a signed max: a negative-only waveform is not silence.
      final peaks = await peaksOf(_wav(_pcm(List.filled(4096, -32768))));

      expect(peaks!.values.every((v) => v >= 254), isTrue);
    });

    test('peaks survive a read boundary that splits a sample', () async {
      // The regression that matters most. Reads are 32 KiB; an odd byte count
      // means a chunk ends mid-sample, and without carrying that byte forward
      // every sample after it is byte-swapped noise for the rest of the file.
      //
      // 32 KiB * 3 + 1 bytes of payload puts a split squarely in the middle.
      const totalBytes = 32 * 1024 * 3 + 1;
      final payload = Uint8List(totalBytes);
      final data = ByteData.sublistView(payload);
      for (var i = 0; i + 1 < totalBytes; i += 2) {
        // A steady tone, so any desync shows up as a changed amplitude.
        data.setInt16(i, i.isEven ? 24000 : -24000, Endian.little);
      }

      final peaks = await peaksOf(_wav(payload), buckets: 8);

      expect(peaks, isNotNull);
      // Every bucket saw the same tone, so all should read the same amplitude.
      final distinct = peaks!.values.toSet();
      expect(distinct.length, 1, reason: 'buckets diverged: ${peaks.values}');
      expect(peaks.values.first, greaterThan(180));
    });

    test('a recording shorter than the bucket count holds its level', () async {
      // Fewer samples than buckets: each sample jumps several buckets, and
      // leaving the gaps at zero would draw a comb instead of a level.
      final peaks = await peaksOf(_wav(_pcm(List.filled(4, 32767))),
          buckets: defaultPeakBuckets);

      expect(peaks!.values.where((v) => v == 0).length, 0,
          reason: 'gaps left unfilled: ${peaks.values}');
    });

    test('finds audio behind a chunk that precedes data', () async {
      // Exercises locatePcmRegion: editors insert LIST/INFO metadata, and the
      // peaks must come from the audio, not from the metadata bytes.
      final pcm = _pcm(List.filled(2048, 20000));
      final body = BytesBuilder()
        ..add(Uint8List.fromList('fmt '.codeUnits))
        ..add((ByteData(4)..setUint32(0, 16, Endian.little))
            .buffer
            .asUint8List())
        ..add(buildWavHeader(dataBytes: 0).sublist(20, 36))
        ..add(Uint8List.fromList('LIST'.codeUnits))
        ..add((ByteData(4)..setUint32(0, 12, Endian.little))
            .buffer
            .asUint8List())
        ..add(Uint8List.fromList('INFOmetadata'.codeUnits))
        ..add(Uint8List.fromList('data'.codeUnits))
        ..add((ByteData(4)..setUint32(0, pcm.length, Endian.little))
            .buffer
            .asUint8List())
        ..add(pcm);
      final bodyBytes = body.takeBytes();

      final out = BytesBuilder()
        ..add(Uint8List.fromList('RIFF'.codeUnits))
        ..add((ByteData(4)..setUint32(0, 4 + bodyBytes.length, Endian.little))
            .buffer
            .asUint8List())
        ..add(Uint8List.fromList('WAVE'.codeUnits))
        ..add(bodyBytes);

      final peaks = await peaksOf(out.takeBytes());

      expect(peaks, isNotNull);
      expect(peaks!.pcmByteLength, pcm.length);
      expect(peaks.values.every((v) => v > 100), isTrue);
    });

    test('a missing file yields null rather than throwing', () async {
      expect(await computePeaks('${dir.path}/nope.wav'), isNull);
    });

    test('a header with no payload yields null', () async {
      expect(await peaksOf(buildWavHeader(dataBytes: 0)), isNull);
    });
  });

  group('encodePeaks / decodePeaks', () {
    PeakData sample() => PeakData(
          values: Uint8List.fromList(List.generate(256, (i) => i)),
          pcmByteLength: 320000,
        );

    test('round-trips', () {
      final encoded = encodePeaks(sample());
      final decoded = decodePeaks(encoded, expectedPcmByteLength: 320000);

      expect(decoded, isNotNull);
      expect(decoded!.values, equals(sample().values));
      expect(decoded.pcmByteLength, 320000);
    });

    test('a stored file is the size the format promises', () {
      // 12-byte header + one byte per bucket. Worth pinning: this file counts
      // against the user's storage cap.
      expect(encodePeaks(sample()).length, 12 + 256);
    });

    test('rejects a cache belonging to different audio', () {
      // The staleness key. A recording that was recovered or overwritten has a
      // different payload length, and its old peaks would draw the wrong shape.
      final encoded = encodePeaks(sample());

      expect(decodePeaks(encoded, expectedPcmByteLength: 999), isNull);
    });

    test('rejects a foreign or corrupt file without throwing', () {
      expect(
        decodePeaks(Uint8List.fromList(List.filled(64, 7)),
            expectedPcmByteLength: 320000),
        isNull,
      );
      expect(decodePeaks(Uint8List(0), expectedPcmByteLength: 320000), isNull);
    });

    test('rejects a truncated body', () {
      final encoded = encodePeaks(sample());
      final truncated = Uint8List.fromList(encoded.sublist(0, encoded.length - 5));

      expect(decodePeaks(truncated, expectedPcmByteLength: 320000), isNull);
    });
  });

  group('peaksPathFor', () {
    test('sits beside the audio, like the transcript sidecar', () {
      expect(peaksPathFor('/a/b/recording_20260101_120000.wav'),
          '/a/b/recording_20260101_120000.peaks');
    });
  });
}
