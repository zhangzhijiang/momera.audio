import 'dart:typed_data';

/// Canonical 44-byte RIFF/WAVE header for uncompressed PCM.
const int wavHeaderBytes = 44;

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
Uint8List buildWavHeader({
  required int dataBytes,
  int sampleRate = 16000,
  int channels = 1,
  int bitsPerSample = 16,
}) {
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
