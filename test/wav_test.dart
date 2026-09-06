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
}
