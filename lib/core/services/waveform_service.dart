import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../audio/waveform.dart';
import '../audio/wav.dart';

/// Supplies a recording's waveform, computing it once and caching it.
///
/// Peaks are computed **lazily, the first time a recording is shown**, and then
/// written beside the audio. Doing it at record time was considered and
/// rejected: a pass after Stop re-reads up to 230 MB on the worst frame budget
/// in the app, and accumulating during capture entangles the recorder with a
/// display concern, has to survive pause/resume, and still has no answer for a
/// recording recovered from an interrupted session. Existing recordings would
/// need a backfill path regardless — and lazy computation *is* that path, with
/// no migration and no work at all for recordings nobody scrolls to.
///
/// **Nothing here throws.** A waveform is decoration; audio that cannot be read
/// will fail at playback with its own message, which is the right place for
/// that error rather than a red box in the middle of the list.
class WaveformService {
  /// Recently used peaks, oldest first. 64 entries is about 17 KB.
  final Map<String, PeakData> _cache = {};

  /// Computations already running, keyed by path.
  ///
  /// A list brings half a dozen tiles on screen at once and scrolling back
  /// re-subscribes; without this, the same file would be read several times
  /// over.
  final Map<String, Future<PeakData?>> _inFlight = {};

  static const int _cacheLimit = 64;

  Future<PeakData?> peaksFor(String audioPath) {
    final cached = _cache.remove(audioPath);
    if (cached != null) {
      _cache[audioPath] = cached; // re-insert: most recently used
      return Future.value(cached);
    }

    final running = _inFlight[audioPath];
    if (running != null) return running;

    final future = _resolve(audioPath).whenComplete(() {
      _inFlight.remove(audioPath);
    });
    _inFlight[audioPath] = future;
    return future;
  }

  /// Forget one recording's peaks — after a rename, or a delete.
  void evict(String audioPath) => _cache.remove(audioPath);

  Future<PeakData?> _resolve(String audioPath) async {
    try {
      final audio = File(audioPath);
      if (!await audio.exists()) return null;

      final pcmLength = await _pcmLength(audio);
      if (pcmLength <= 0) return null;

      final cached = await _readSidecar(audioPath, pcmLength);
      if (cached != null) return _remember(audioPath, cached);

      final computed = await computePeaks(audioPath);
      if (computed == null) return null;

      await _writeSidecar(audioPath, computed);
      return _remember(audioPath, computed);
    } catch (e) {
      debugPrint('WaveformService: no waveform for ${p.basename(audioPath)}: $e');
      return null;
    }
  }

  PeakData _remember(String audioPath, PeakData peaks) {
    _cache[audioPath] = peaks;
    if (_cache.length > _cacheLimit) {
      _cache.remove(_cache.keys.first); // oldest
    }
    return peaks;
  }

  /// Length of the audio's PCM payload, used as the cache's staleness key.
  Future<int> _pcmLength(File audio) async {
    final raf = await audio.open();
    try {
      final region = await locatePcmRegion(raf, await audio.length());
      return region.length;
    } finally {
      await raf.close();
    }
  }

  Future<PeakData?> _readSidecar(String audioPath, int pcmLength) async {
    final file = File(peaksPathFor(audioPath));
    if (!await file.exists()) return null;
    return decodePeaks(await file.readAsBytes(),
        expectedPcmByteLength: pcmLength);
  }

  /// Persist the peaks, tolerating failure.
  ///
  /// Separately caught so a full disk still gets a waveform from memory — the
  /// alternative would have the cache throw in exactly the situation the
  /// storage checks elsewhere exist to handle gracefully.
  Future<void> _writeSidecar(String audioPath, PeakData peaks) async {
    try {
      await File(peaksPathFor(audioPath)).writeAsBytes(encodePeaks(peaks));
    } catch (e) {
      debugPrint('WaveformService: could not cache peaks for '
          '${p.basename(audioPath)}: $e');
    }
  }
}
