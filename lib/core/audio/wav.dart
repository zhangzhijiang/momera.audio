import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// Canonical 44-byte RIFF/WAVE header for uncompressed PCM.
const int wavHeaderBytes = 44;

/// Largest PCM payload a WAV file can describe.
///
/// RIFF sizes are unsigned 32-bit and `ByteData.setUint32` silently truncates,
/// so a larger payload would write a wrapped size field — a file no player or
/// transcriber reads correctly, with nothing to indicate anything went wrong.
/// The binding limit is the RIFF chunk size (`36 + dataBytes`), not the payload
/// alone, and it is floored to a whole 2-byte PCM16 frame so the cut never
/// lands mid-sample.
///
/// At 16 kHz mono PCM16 this is roughly 37 hours of audio.
const int maxWavDataBytes = ((0xFFFFFFFF - 36) ~/ 2) * 2;

/// Byte range of a WAV file's PCM payload.
@immutable
class PcmRegion {
  const PcmRegion(this.offset, this.length);

  /// Offset of the first PCM byte from the start of the file.
  final int offset;

  /// Number of PCM bytes, clamped to what the file actually contains so a
  /// truncated recording is read as far as it goes rather than overrunning.
  final int length;

  /// True when there is no audio to read.
  bool get isEmpty => length <= 0;

  @override
  String toString() => 'PcmRegion(offset: $offset, length: $length)';
}

/// Locate the `data` chunk of a WAV file without reading the audio.
///
/// Walks the RIFF chunk list reading 8 bytes per chunk header, so finding the
/// payload in a 200 MB recording costs a handful of tiny reads — which is what
/// lets a long recording be transcribed with a fixed-size buffer instead of
/// being loaded into memory whole.
///
/// Falls back to assuming a canonical 44-byte header when there is no `data`
/// chunk, so a file with an unusual layout still transcribes as something
/// rather than nothing.
Future<PcmRegion> locatePcmRegion(
  RandomAccessFile raf,
  int fileLength,
) async {
  if (fileLength < wavHeaderBytes) return const PcmRegion(0, 0);

  var offset = 12; // past "RIFF" + size + "WAVE"
  while (offset + 8 <= fileLength) {
    await raf.setPosition(offset);
    final head = await raf.read(8);
    if (head.length < 8) break;

    final id = String.fromCharCodes(head.sublist(0, 4));
    final size = ByteData.sublistView(head).getUint32(4, Endian.little);
    final body = offset + 8;
    if (id == 'data') {
      final end = math.min(body + size, fileLength);
      return PcmRegion(body, math.max(0, end - body));
    }
    // Chunks are word-aligned (padded to even length).
    offset = body + size + (size.isOdd ? 1 : 0);
  }
  return PcmRegion(wavHeaderBytes, math.max(0, fileLength - wavHeaderBytes));
}

/// Builds a 44-byte WAV header for [dataBytes] of PCM payload.
///
/// Recording writes *raw* PCM to disk and only prepends a header when the
/// recording is finalised. That is deliberate:
///
/// * Concatenating WAV files would embed 44-byte headers mid-stream, which the
///   transcriber would read as audio — audible clicks, and noise fed to the VAD.
/// * A raw stream has nothing to keep in sync. A recording interrupted by a
///   crash is just a shorter payload, so recovery is "prepend a header for
///   whatever bytes survived" rather than a repair.
/// Throws [ArgumentError] if [dataBytes] exceeds [maxWavDataBytes]. Callers
/// must clamp before they get here: failing loudly beats writing a header whose
/// truncated size field silently misdescribes the file.
Uint8List buildWavHeader({
  required int dataBytes,
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  if (dataBytes < 0 || dataBytes > maxWavDataBytes) {
    throw ArgumentError.value(
      dataBytes,
      'dataBytes',
      'must be between 0 and $maxWavDataBytes — RIFF sizes are 32-bit',
    );
  }
  final bytesPerSample = bitsPerSample ~/ 8;
  final byteRate = sampleRate * channels * bytesPerSample;
  final blockAlign = channels * bytesPerSample;

  final header = ByteData(wavHeaderBytes);
  // RIFF chunk descriptor.
  _writeAscii(header, 0, 'RIFF');
  // Size of everything after this field: 36 + payload.
  header.setUint32(4, 36 + dataBytes, Endian.little);
  _writeAscii(header, 8, 'WAVE');

  // "fmt " sub-chunk.
  _writeAscii(header, 12, 'fmt ');
  header.setUint32(16, 16, Endian.little); // PCM fmt chunk size
  header.setUint16(20, 1, Endian.little); // audio format 1 = PCM
  header.setUint16(22, channels, Endian.little);
  header.setUint32(24, sampleRate, Endian.little);
  header.setUint32(28, byteRate, Endian.little);
  header.setUint16(32, blockAlign, Endian.little);
  header.setUint16(34, bitsPerSample, Endian.little);

  // "data" sub-chunk.
  _writeAscii(header, 36, 'data');
  header.setUint32(40, dataBytes, Endian.little);

  return header.buffer.asUint8List();
}

void _writeAscii(ByteData data, int offset, String value) {
  for (var i = 0; i < value.length; i++) {
    data.setUint8(offset + i, value.codeUnitAt(i));
  }
}

/// Duration of [dataBytes] of PCM at the given format.
Duration durationForPcmBytes(
  int dataBytes, {
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  if (dataBytes <= 0) return Duration.zero;
  final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  return Duration(milliseconds: (dataBytes * 1000 / byteRate).round());
}

/// Bytes of PCM produced by [duration] at the given format. Inverse of
/// [durationForPcmBytes]; used to translate a storage cap into a time budget.
int pcmBytesForDuration(
  Duration duration, {
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
  final byteRate = sampleRate * channels * (bitsPerSample ~/ 8);
  return (duration.inMilliseconds * byteRate / 1000).round();
}
