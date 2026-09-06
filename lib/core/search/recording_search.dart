import 'package:flutter/foundation.dart';

import '../services/transcription_service.dart';
import '../../data/models/recording.dart';
import 'han_variants.dart';

/// Where in a recording a search term was found.
@immutable
class SearchHit {
  const SearchHit({
    required this.recording,
    this.segment,
    this.matchedName = false,
  });

  final Recording recording;

  /// The phrase the term appeared in, when the recording has timed segments.
  /// Null when the match came from the recording's name, or from a transcript
  /// stored before segments were recorded.
  final TranscriptSegment? segment;

  /// True when the term matched the recording's name rather than its speech.
  final bool matchedName;

  /// Where playback should start to hear this hit.
  Duration? get seekTo => segment?.start;
}

/// Searches recordings by transcript text and name.
///
/// Deliberately a plain scan over what is already loaded rather than an index:
/// transcripts are small, the list is already in memory, and a database would
/// buy nothing until there are thousands of recordings.
class RecordingSearch {
  const RecordingSearch();

  /// Returns every match for [query], newest recording first, and within a
  /// recording in the order the phrases were spoken.
  ///
  /// An empty or whitespace-only query returns nothing — the caller shows the
  /// unfiltered list in that case.
  List<SearchHit> search(List<Recording> recordings, String query) {
    final needle = normalizeForSearch(query);
    if (needle.isEmpty) return const [];

    final hits = <SearchHit>[];
    for (final recording in recordings) {
      final name = recording.customName;
      final nameMatches =
          name != null && normalizeForSearch(name).contains(needle);

      var speechMatched = false;
      for (final segment in recording.segments) {
        if (normalizeForSearch(segment.text).contains(needle)) {
          hits.add(SearchHit(recording: recording, segment: segment));
          speechMatched = true;
        }
      }

      // A transcript saved before segments were stored still matches, it just
      // cannot offer a seek position.
      if (!speechMatched &&
          recording.segments.isEmpty &&
          recording.hasTranscript &&
          normalizeForSearch(recording.transcript!).contains(needle)) {
        hits.add(SearchHit(recording: recording));
        speechMatched = true;
      }

      if (nameMatches && !speechMatched) {
        hits.add(SearchHit(recording: recording, matchedName: true));
      }
    }
    return hits;
  }

  /// Recordings with at least one hit, preserving list order.
  List<Recording> filter(List<Recording> recordings, String query) {
    final matched = <String>{};
    for (final hit in search(recordings, query)) {
      matched.add(hit.recording.path);
    }
    return [for (final r in recordings) if (matched.contains(r.path)) r];
  }
}

/// Folds text into a form where equivalent writings compare equal.
///
/// Three things happen here, and each exists for a concrete reason:
///
/// 1. **Case folding**, so "Standup" finds "standup".
/// 2. **Whitespace collapsing**, so a stray double space does not hide a match.
/// 3. **Traditional → Simplified Han folding.** This app ships both Chinese
///    scripts and transcribes Mandarin and Cantonese, so the same words are
///    routinely written both ways. Without folding, searching 會議 would not
///    find a transcript containing 会议 — the single most likely way search
///    would appear broken to a Chinese-speaking user.
///
/// Note that `useInverseTextNormalization` is enabled on the recogniser, so
/// spoken numbers are stored as digits ("twenty twenty six" → "2026"). Searching
/// the words will not find them; that is a property of the transcript, not of
/// this function.
String normalizeForSearch(String input) {
  final buffer = StringBuffer();
  var lastWasSpace = false;

  for (final rune in input.trim().toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    if (char.trim().isEmpty) {
      if (!lastWasSpace) buffer.write(' ');
      lastWasSpace = true;
      continue;
    }
    lastWasSpace = false;
    buffer.write(simplifyHan(char));
  }
  return buffer.toString().trim();
}
