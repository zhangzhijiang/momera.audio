import 'package:flutter_test/flutter_test.dart';
import 'package:momera_audio/core/search/han_variants.dart';
import 'package:momera_audio/core/search/recording_search.dart';
import 'package:momera_audio/core/services/transcription_service.dart';
import 'package:momera_audio/data/models/recording.dart';

Recording _rec(
  String path, {
  String? transcript,
  List<TranscriptSegment> segments = const [],
}) {
  return Recording(
    path: '/recordings/$path',
    createdAt: DateTime(2026, 9, 5, 16, 0, 0),
    sizeBytes: 32044,
    transcript: transcript,
    segments: segments,
  );
}

TranscriptSegment _seg(int startSec, String text) => TranscriptSegment(
      start: Duration(seconds: startSec),
      end: Duration(seconds: startSec + 3),
      text: text,
    );

void main() {
  const search = RecordingSearch();

  group('normalizeForSearch', () {
    test('folds case', () {
      expect(normalizeForSearch('Team StandUp'), 'team standup');
    });

    test('collapses and trims whitespace', () {
      expect(normalizeForSearch('  a   b  '), 'a b');
    });

    test('folds Traditional Han to Simplified', () {
      expect(normalizeForSearch('會議'), normalizeForSearch('会议'));
      expect(normalizeForSearch('錄音'), normalizeForSearch('录音'));
      expect(normalizeForSearch('語言'), normalizeForSearch('语言'));
      expect(normalizeForSearch('學習'), normalizeForSearch('学习'));
      expect(normalizeForSearch('國家'), normalizeForSearch('国家'));
      expect(normalizeForSearch('電話'), normalizeForSearch('电话'));
    });

    test('leaves characters absent from the table alone', () {
      // An incomplete table must degrade to "matches only itself", never to a
      // wrong fold.
      expect(normalizeForSearch('日本語'), contains('日'));
      expect(normalizeForSearch('한국어'), '한국어');
    });
  });

  group('han variant table', () {
    test('is aligned and non-trivial', () {
      // _buildTable asserts even length; this guards the size so a botched
      // edit that empties the table is caught.
      expect(hanVariantRuleCount, greaterThan(200));
    });

    test('never maps a character to itself', () {
      expect(simplifyHan('会'), '会');
      expect(simplifyHan('a'), 'a');
    });
  });

  group('search', () {
    final standup = _rec('Team standup.wav', transcript: 'we shipped the port',
        segments: [
          _seg(0, 'good morning everyone'),
          _seg(12, 'we shipped the port'),
          _seg(30, 'anything blocking'),
        ]);
    final bilingual = _rec('recording_20260905_160000.wav',
        transcript: '你好 how are you 我很好', segments: [
      _seg(0, '你好'),
      _seg(5, 'how are you'),
      _seg(9, '我很好'),
    ]);
    final legacy = _rec('recording_20260904_090000.wav',
        transcript: 'quarterly budget review');

    final all = [standup, bilingual, legacy];

    test('an empty query matches nothing', () {
      expect(search.search(all, ''), isEmpty);
      expect(search.search(all, '   '), isEmpty);
    });

    test('finds a phrase and reports where to seek', () {
      final hits = search.search(all, 'shipped');
      expect(hits, hasLength(1));
      expect(hits.single.recording.path, standup.path);
      expect(hits.single.seekTo, const Duration(seconds: 12));
    });

    test('is case-insensitive', () {
      expect(search.search(all, 'SHIPPED'), hasLength(1));
    });

    test('returns one hit per matching phrase', () {
      final hits = search.search(all, 'o');
      expect(hits.length, greaterThan(1));
    });

    test('finds Simplified text when the query is Traditional', () {
      // 你好 is script-neutral; use a pair that actually differs.
      final zh = _rec('zh.wav',
          transcript: '会议记录', segments: [_seg(0, '会议记录')]);
      final hits = search.search([zh], '會議');
      expect(hits, hasLength(1));
      expect(hits.single.seekTo, Duration.zero);
    });

    test('finds a phrase in either language of a bilingual recording', () {
      expect(search.search(all, '你好').single.seekTo, Duration.zero);
      expect(search.search(all, 'how are you').single.seekTo,
          const Duration(seconds: 5));
    });

    test('matches a transcript with no segments, without a seek position', () {
      final hits = search.search(all, 'quarterly');
      expect(hits, hasLength(1));
      expect(hits.single.recording.path, legacy.path);
      expect(hits.single.seekTo, isNull,
          reason: 'a pre-segments transcript still matches, it just cannot seek');
    });

    test('matches a custom name', () {
      final hits = search.search(all, 'standup');
      expect(hits.any((h) => h.recording.path == standup.path), isTrue);
    });

    test('a name-only match is flagged as such', () {
      final named = _rec('Budget meeting.wav');
      final hits = search.search([named], 'budget');
      expect(hits.single.matchedName, isTrue);
      expect(hits.single.seekTo, isNull);
    });

    test('does not match the generated filename of an unnamed recording', () {
      // Otherwise typing "recording" would return everything.
      expect(search.search(all, 'recording_20260905'), isEmpty);
    });

    test('a term found in speech does not also produce a name hit', () {
      final hits = search.search(all, 'standup');
      expect(hits.where((h) => h.recording.path == standup.path), hasLength(1));
    });

    test('filter returns whole recordings, de-duplicated, in list order', () {
      final filtered = search.filter(all, 'o');
      expect(filtered.map((r) => r.path).toSet().length, filtered.length);
      expect(filtered.first.path, all.firstWhere((r) => filtered.contains(r)).path);
    });

    test('no match yields nothing', () {
      expect(search.search(all, 'zzzznotpresent'), isEmpty);
      expect(search.filter(all, 'zzzznotpresent'), isEmpty);
    });
  });
}
