import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/waveform.dart';
import 'service_providers.dart';

/// A recording's waveform, computed on first display and cached thereafter.
///
/// `autoDispose` so a tile scrolled out of the list releases its provider
/// entry; the service keeps its own LRU, so scrolling back is still instant
/// without re-reading the audio.
final waveformProvider =
    FutureProvider.autoDispose.family<PeakData?, String>((ref, audioPath) {
  return ref.read(waveformServiceProvider).peaksFor(audioPath);
});
