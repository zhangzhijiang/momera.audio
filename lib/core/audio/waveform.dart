import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'wav.dart';

/// Where a recording's cached peaks live: a sibling of the `.wav`, matching the
/// `.txt` transcript convention.
///
/// Defined here rather than in the repository so there is exactly one answer to
/// "where does this file go", shared by whoever writes it and whoever has to
/// carry it across a rename or delete it.
String peaksPathFor(String audioPath) => p.setExtension(audioPath, '.peaks');

/// Buckets in a stored waveform.
///
/// 256 fills a wide tablet tile at a 2 dp bar pitch; narrower widths are
/// downsampled by the painter, which is much cheaper than re-reading audio.
const int defaultPeakBuckets = 256;

const int _headerBytes = 12;
const int _version = 1;
const List<int> _magic = [0x4D, 0x50, 0x4B, 0x31]; // "MPK1"

/// Bytes of PCM read at a time — the same 32 KiB the transcriber uses.
const int _readChunkBytes = 32 * 1024;

/// A recording's waveform, downsampled to a fixed number of buckets.
@immutable
class PeakData {
  const PeakData({required this.values, required this.pcmByteLength});

  /// One 0–255 amplitude per bucket, oldest first.
  final Uint8List values;

  /// Length of the PCM payload these peaks were computed from.
  ///
  /// The staleness key: if the audio no longer has this many bytes, the cache
  /// belongs to a different recording and must be recomputed.
  final int pcmByteLength;
}

/// Read a recording and reduce it to [buckets] amplitude values.
///
/// Streams the file in 32 KiB chunks — the same shape as
/// `TranscriptionService._transcribeFileLocked`, including the odd-byte carry,
/// because a short read that splits a PCM16 sample would byte-swap every sample
/// after it. Peak memory is one chunk plus the output, whatever the recording's
/// length.
///
/// Values are **max-abs** per bucket rather than RMS. RMS measures loudness and
/// renders speech as a flat sausage; a peak meter shows where the phrases are,
/// which is what makes the bar worth scrubbing. Any display curve belongs in
/// the painter — what is stored here stays a faithful measurement, so the look
/// can be retuned later without invalidating every cache on every device.
///
/// Returns null when there is no audio to measure. Takes a path and nothing
/// else, so it can be handed to `Isolate.run` unchanged if a profile ever
/// demands it — the chunked loop already yields, so it does not block today.
Future<PeakData?> computePeaks(
  String wavPath, {
  int buckets = defaultPeakBuckets,
}) async {
  final file = File(wavPath);
  if (!await file.exists()) return null;

  final raf = await file.open();
  try {
    final region = await locatePcmRegion(raf, await file.length());
    if (region.isEmpty) return null;

    final totalSamples = region.length ~/ 2;
    if (totalSamples <= 0) return null;

    final values = Uint8List(buckets);
    var position = region.offset;
    final end = region.offset + region.length;
    await raf.setPosition(position);

    var sampleIndex = 0;
    var currentBucket = 0;
    var currentMax = 0.0;
    int? pendingByte;

    while (position < end) {
      final read = await raf.read(math.min(_readChunkBytes, end - position));
      if (read.isEmpty) break;
      position += read.length;

      final Uint8List chunk;
      if (pendingByte == null) {
        chunk = read;
      } else {
        chunk = Uint8List(read.length + 1)
          ..[0] = pendingByte
          ..setRange(1, read.length + 1, read);
        pendingByte = null;
      }
      final wholeSamples = chunk.length ~/ 2;
      if (chunk.length.isOdd) pendingByte = chunk[chunk.length - 1];

      final data = ByteData.sublistView(chunk);
      for (var i = 0; i < wholeSamples; i++) {
        final sample = data.getInt16(i * 2, Endian.little) / 32768.0;
        final magnitude = sample < 0 ? -sample : sample;

        final bucket = sampleIndex * buckets ~/ totalSamples;
        if (bucket != currentBucket) {
          final value = _toByte(currentMax);
          // Hold across any buckets that were skipped. A recording shorter than
          // `buckets` samples advances by more than one bucket per sample, and
          // leaving the gaps at zero would draw a comb instead of a level.
          for (var b = currentBucket; b < bucket && b < buckets; b++) {
            values[b] = value;
          }
          currentBucket = bucket;
          currentMax = 0.0;
        }
        if (magnitude > currentMax) currentMax = magnitude;
        sampleIndex++;
      }

      // Hand the event loop a turn, about once per second of audio.
      await Future<void>.delayed(Duration.zero);
    }

    final tail = _toByte(currentMax);
    for (var b = currentBucket; b < buckets; b++) {
      values[b] = tail;
    }

    return PeakData(values: values, pcmByteLength: region.length);
  } finally {
    await raf.close();
  }
}

int _toByte(double magnitude) => (magnitude * 255).round().clamp(0, 255);

/// Serialise peaks for the sidecar: a 12-byte header then one byte per bucket.
Uint8List encodePeaks(PeakData peaks) {
  final out = Uint8List(_headerBytes + peaks.values.length);
  final data = ByteData.sublistView(out);
  out.setRange(0, 4, _magic);
  data.setUint8(4, _version);
  data.setUint8(5, 0); // reserved
  data.setUint16(6, peaks.values.length, Endian.little);
  // Safe as a uint32: a WAV cannot describe more payload than this anyway.
  data.setUint32(8, peaks.pcmByteLength & 0xFFFFFFFF, Endian.little);
  out.setRange(_headerBytes, out.length, peaks.values);
  return out;
}

/// Parse a sidecar, or return null if it is not usable.
///
/// Null for a wrong magic, an unknown version, a truncated body, or a
/// [PeakData.pcmByteLength] that no longer matches the audio. **Never throws**
/// — a corrupt cache is a reason to recompute, not to fail; the same posture
/// the transcript sidecar reader takes.
PeakData? decodePeaks(
  Uint8List bytes, {
  required int expectedPcmByteLength,
}) {
  if (bytes.length < _headerBytes) return null;
  for (var i = 0; i < _magic.length; i++) {
    if (bytes[i] != _magic[i]) return null;
  }

  final data = ByteData.sublistView(bytes);
  if (data.getUint8(4) != _version) return null;

  final count = data.getUint16(6, Endian.little);
  if (count <= 0 || bytes.length != _headerBytes + count) return null;

  final pcmByteLength = data.getUint32(8, Endian.little);
  if (pcmByteLength != (expectedPcmByteLength & 0xFFFFFFFF)) return null;

  return PeakData(
    values: Uint8List.fromList(bytes.sublist(_headerBytes)),
    pcmByteLength: pcmByteLength,
  );
}
