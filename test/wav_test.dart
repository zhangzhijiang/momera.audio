import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/audio/wav.dart';
import 'package:momera_recording/core/services/audio_recording_service.dart';

/// Reads a little-endian uint32 at [offset].
int _u32(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint32(offset, Endian.little);
int _u16(Uint8List bytes, int offset) =>
    ByteData.sublistView(bytes).getUint16(offset, Endian.little);
String _ascii(Uint8List bytes, int offset, int length) =>
    String.fromCharCodes(bytes.sublist(offset, offset + length));

void main() {
  group('buildWavHeader', () {
    test('is exactly 44 bytes', () {
      expect(buildWavHeader(dataBytes: 1000).length, wavHeaderBytes);
      expect(wavHeaderBytes, 44);
    });

    test('writes a well-formed RIFF/WAVE header for our recording format', () {
      const dataBytes = 32000; // 1 second at 16 kHz mono PCM16
      final header = buildWavHeader(dataBytes: dataBytes);

      expect(_ascii(header, 0, 4), 'RIFF');
      expect(_u32(header, 4), 36 + dataBytes, reason: 'RIFF chunk size');
      expect(_ascii(header, 8, 4), 'WAVE');

      expect(_ascii(header, 12, 4), 'fmt ');
      expect(_u32(header, 16), 16, reason: 'PCM fmt chunk is 16 bytes');
      expect(_u16(header, 20), 1, reason: 'format 1 = uncompressed PCM');
      expect(_u16(header, 22), 1, reason: 'mono');
      expect(_u32(header, 24), 16000, reason: 'sample rate');
      expect(_u32(header, 28), 32000, reason: 'byte rate = 16000 * 1 * 2');
      expect(_u16(header, 32), 2, reason: 'block align = channels * 2');
      expect(_u16(header, 34), 16, reason: 'bits per sample');

      expect(_ascii(header, 36, 4), 'data');
      expect(_u32(header, 40), dataBytes, reason: 'data chunk size');
    });

    test('an empty payload still produces a valid header', () {
      final header = buildWavHeader(dataBytes: 0);
      expect(_u32(header, 4), 36);
      expect(_u32(header, 40), 0);
    });
  });

  group('duration <-> bytes', () {
    test('one second of 16 kHz mono PCM16 is 32000 bytes', () {
      expect(pcmBytesForDuration(const Duration(seconds: 1)), 32000);
      expect(durationForPcmBytes(32000), const Duration(seconds: 1));
    });

    test('round-trips', () {
      for (final seconds in [1, 7, 60, 3600]) {
        final d = Duration(seconds: seconds);
        expect(durationForPcmBytes(pcmBytesForDuration(d)), d);
      }
    });

    test('a non-positive payload is zero duration, not negative', () {
      expect(durationForPcmBytes(0), Duration.zero);
      expect(durationForPcmBytes(-100), Duration.zero);
    });
  });

  group('finalisePcm', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('momera_wav_test');
    });
    tearDown(() async {
      if (await tempDir.exists()) await tempDir.delete(recursive: true);
    });

    test('prepends a header, keeps the payload, and removes the .pcm',
        () async {
      final pcm = File('${tempDir.path}/recording_20260905_161500.pcm');
      final payload = Uint8List.fromList(List.generate(1000, (i) => i % 256));
      await pcm.writeAsBytes(payload);

      final wavPath = await AudioRecordingService.finalisePcm(pcm);

      expect(wavPath, endsWith('.wav'));
      expect(await pcm.exists(), isFalse, reason: 'the .pcm is consumed');

      final wav = await File(wavPath!).readAsBytes();
      expect(wav.length, wavHeaderBytes + payload.length);
      expect(_ascii(wav, 0, 4), 'RIFF');
      expect(_u32(wav, 40), payload.length,
          reason: 'declared data size matches what was written');
      expect(wav.sublist(wavHeaderBytes), payload,
          reason: 'audio survives byte-for-byte');
    });

    test('an interrupted recording of any length is recoverable', () async {
      // The crash-safety guarantee: whatever was flushed becomes playable, with
      // no repair step, because the payload is raw PCM with no header to fix.
      for (final size in [2, 999, 32000]) {
        final pcm = File('${tempDir.path}/partial_$size.pcm');
        await pcm.writeAsBytes(Uint8List(size));
        final wavPath = await AudioRecordingService.finalisePcm(pcm);
        final wav = await File(wavPath!).readAsBytes();
        expect(wav.length, wavHeaderBytes + size);
        expect(_u32(wav, 40), size);
      }
    });

    test('an empty .pcm yields no .wav and is cleaned up', () async {
      final pcm = File('${tempDir.path}/empty.pcm');
      await pcm.writeAsBytes(Uint8List(0));

      expect(await AudioRecordingService.finalisePcm(pcm), isNull);
      expect(await pcm.exists(), isFalse,
          reason: 'a zero-byte leftover should not linger');
      expect(await File('${tempDir.path}/empty.wav').exists(), isFalse);
    });

    test('a missing file is handled without throwing', () async {
      final missing = File('${tempDir.path}/nope.pcm');
      expect(await AudioRecordingService.finalisePcm(missing), isNull);
    });
  });

  _locateTests();

  _sizeLimitTests();
}

/// A WAV file whose chunk list is [chunks] — each an id plus its body — so a
/// test can build layouts the recorder never writes but other tools do.
Uint8List _wavWithChunks(List<(String, Uint8List)> chunks) {
  final body = BytesBuilder();
  for (final (id, payload) in chunks) {
    body.add(Uint8List.fromList(id.codeUnits));
    final size = ByteData(4)..setUint32(0, payload.length, Endian.little);
    body.add(size.buffer.asUint8List());
    body.add(payload);
    // Chunks are word-aligned.
    if (payload.length.isOdd) body.addByte(0);
  }
  final bodyBytes = body.takeBytes();

  final out = BytesBuilder();
  out.add(Uint8List.fromList('RIFF'.codeUnits));
  final riffSize = ByteData(4)
    ..setUint32(0, 4 + bodyBytes.length, Endian.little);
  out.add(riffSize.buffer.asUint8List());
  out.add(Uint8List.fromList('WAVE'.codeUnits));
  out.add(bodyBytes);
  return out.takeBytes();
}

/// The 16-byte body of a PCM `fmt ` chunk.
Uint8List _fmtBody() => buildWavHeader(dataBytes: 0).sublist(20, 36);


// Registered from main().
void _locateTests() {
  group('locatePcmRegion', () {
    late Directory dir;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('wav_locate_test');
    });
    tearDown(() async {
      if (await dir.exists()) await dir.delete(recursive: true);
    });

    /// Writes [bytes] to a file and locates its PCM payload.
    Future<PcmRegion> locate(Uint8List bytes) async {
      final file = File('${dir.path}/probe.wav');
      await file.writeAsBytes(bytes);
      final raf = await file.open();
      try {
        return await locatePcmRegion(raf, await file.length());
      } finally {
        await raf.close();
      }
    }

    test('finds the payload behind a canonical 44-byte header', () async {
      const dataBytes = 3200;
      final bytes = Uint8List.fromList([
        ...buildWavHeader(dataBytes: dataBytes),
        ...List<int>.filled(dataBytes, 7),
      ]);

      final region = await locate(bytes);
      expect(region.offset, wavHeaderBytes);
      expect(region.length, dataBytes);
      expect(region.isEmpty, isFalse);
    });

    test('skips chunks that sit before the data chunk', () async {
      // Recorders and editors routinely insert LIST/INFO metadata; walking the
      // chunk list is the only way to find the audio behind it.
      final payload = Uint8List.fromList(List<int>.filled(64, 3));
      final bytes = _wavWithChunks([
        ('fmt ', _fmtBody()),
        ('LIST', Uint8List.fromList('INFOmetadata!'.codeUnits)),
        ('data', payload),
      ]);

      final region = await locate(bytes);
      expect(region.length, payload.length);
      // The payload must be exactly where the region says it is.
      expect(bytes.sublist(region.offset, region.offset + region.length),
          equals(payload));
    });

    test('word-aligns past an odd-length chunk', () async {
      final payload = Uint8List.fromList(List<int>.filled(32, 9));
      final bytes = _wavWithChunks([
        ('fmt ', _fmtBody()),
        // 13 bytes: the reader must skip the pad byte too, or it reads the
        // chunk id one byte off and never finds the audio.
        ('LIST', Uint8List.fromList('INFOodd-sized'.codeUnits)),
        ('data', payload),
      ]);

      final region = await locate(bytes);
      expect(bytes.sublist(region.offset, region.offset + region.length),
          equals(payload));
    });

    test('clamps a data chunk that claims more than the file holds', () async {
      // What an interrupted write looks like: the header promises audio the
      // file does not contain. Reading to the claimed length would overrun.
      const claimed = 32000;
      final bytes = Uint8List.fromList([
        ...buildWavHeader(dataBytes: claimed),
        ...List<int>.filled(500, 1),
      ]);

      final region = await locate(bytes);
      expect(region.offset, wavHeaderBytes);
      expect(region.length, 500);
    });

    test('falls back to the canonical header when there is no data chunk',
        () async {
      final bytes = _wavWithChunks([
        ('fmt ', _fmtBody()),
        ('LIST', Uint8List.fromList(List<int>.filled(64, 0))),
      ]);

      final region = await locate(bytes);
      expect(region.offset, wavHeaderBytes);
      expect(region.length, bytes.length - wavHeaderBytes);
    });

    test('reports empty for a file too short to be a WAV', () async {
      final region = await locate(Uint8List.fromList(List<int>.filled(20, 0)));
      expect(region.isEmpty, isTrue);
    });

    test('reports empty for a header with no payload', () async {
      final region = await locate(buildWavHeader(dataBytes: 0));
      expect(region.isEmpty, isTrue);
    });
  });
}

// Registered from main().
void _sizeLimitTests() {
  group('maxWavDataBytes', () {
    test('is the largest payload a 32-bit RIFF size can describe', () {
      // The RIFF chunk size field holds `36 + dataBytes`, so that sum — not the
      // payload alone — is what must fit in a uint32.
      expect(36 + maxWavDataBytes, lessThanOrEqualTo(0xFFFFFFFF));
      expect(36 + maxWavDataBytes + 2, greaterThan(0xFFFFFFFF));
      // Floored to a whole PCM16 mono frame, so the cut never splits a sample.
      expect(maxWavDataBytes.isEven, isTrue);
    });

    test('is about 37 hours of our recording format', () {
      final limit = durationForPcmBytes(maxWavDataBytes);
      expect(limit.inHours, 37);
    });

    test('a header at exactly the limit round-trips without wrapping', () {
      final header = buildWavHeader(dataBytes: maxWavDataBytes);
      expect(_u32(header, 40), maxWavDataBytes);
      expect(_u32(header, 4), 36 + maxWavDataBytes);
    });

    test('a payload past the limit is refused rather than silently truncated',
        () {
      // setUint32 wraps without complaint, which would write a header that
      // misdescribes the file with nothing to signal it.
      expect(
        () => buildWavHeader(dataBytes: maxWavDataBytes + 2),
        throwsArgumentError,
      );
      expect(() => buildWavHeader(dataBytes: -1), throwsArgumentError);
    });
  });
}

