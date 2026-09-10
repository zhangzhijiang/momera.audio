// Demo library for store screenshots — the recordings the listing shows.
//
// WHY THIS FILE EXISTS
// A freshly installed Momera Recorder has an empty recordings folder, and the
// screens worth photographing (waveforms, transcripts, search hits, the History
// calendar, detected languages) all need content. `shoot` wipes app data before
// every run, so the content has to be rebuilt in-process at the start of each
// one — and rebuilt *identically*, or sequence NN would be a different picture
// in every locale.
//
// WHAT IS REAL AND WHAT IS SEEDED
//   * The audio is generated here: a 16 kHz mono PCM16 tone with a speech-like
//     envelope, written through the app's own `buildWavHeader`. Every waveform
//     in a screenshot is therefore computed by the real `computePeaks` from the
//     real file — nothing draws a fake waveform.
//   * The transcripts are seeded, in the app's real `.txt` sidecar format, and
//     rendered by the real UI. They were NOT produced by SenseVoice during the
//     capture run: the 228 MB model is a runtime download and capture happens
//     with the radios off. They are written to look like what the model does
//     produce — punctuated text, per-phrase segments with timings, and a
//     detected-language list that is genuinely per segment.
//   * Nothing here is random. Every string is a literal and every timestamp is
//     derived from the capture date, so a rerun of the same locale produces the
//     same screens.
//
// EDITING THIS FILE
// Changing the ORDER or COUNT of `recordings` changes what the numbered screens
// contain, and `selection.json` refers to those numbers. Change text freely;
// think before reordering.

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:momera_recording/core/audio/wav.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// One phrase of a seeded transcript, mirroring `TranscriptSegment`.
class DemoSegment {
  const DemoSegment(this.startMs, this.endMs, this.text, this.language);

  final int startMs;
  final int endMs;
  final String text;

  /// A `TranscriptionLanguage` enum *name* — 'english', 'mandarin', 'japanese',
  /// 'korean', 'cantonese'. Written to the sidecar exactly as the app writes it.
  final String language;
}

/// One seeded recording.
class DemoRecording {
  const DemoRecording({
    required this.daysAgo,
    required this.hour,
    required this.minute,
    required this.seconds,
    this.name,
    this.segments = const [],
  });

  /// 0 = today. Today's recordings are additionally clamped so they never carry
  /// a timestamp in the future, whatever time of day the capture runs.
  final int daysAgo;
  final int hour;
  final int minute;

  /// Audio length. The app derives duration from the file's byte length, so
  /// this is the only thing that sets what the tile displays.
  final int seconds;

  /// A user-chosen name, or null to keep the generated
  /// `recording_yyyyMMdd_HHmmss` form — the app shows the two differently, and
  /// the pool should contain both.
  final String? name;

  /// Empty means "not transcribed yet", which is what puts the Transcribe
  /// button on the tile.
  final List<DemoSegment> segments;

  bool get hasTranscript => segments.isNotEmpty;

  /// The recogniser's own joining rule: segments separated by a single space.
  /// Kept identical to `TranscriptionService._appendSegment` so a seeded
  /// transcript and a produced one are byte-comparable.
  String get text => segments.map((s) => s.text).join(' ').trim();

  /// Languages in first-seen order — exactly how the app accumulates them.
  List<String> get languages {
    final seen = <String>[];
    for (final s in segments) {
      if (!seen.contains(s.language)) seen.add(s.language);
    }
    return seen;
  }
}

/// The demo library for one UI language, plus the queries the search screens
/// type. Queries live beside the content because they have to match it.
class DemoContent {
  const DemoContent({
    required this.recordings,
    required this.speechQuery,
    required this.nameQuery,
    required this.missQuery,
  });

  final List<DemoRecording> recordings;

  /// Matches spoken words in a transcript — one of today's recordings, and one
  /// older one, so it demonstrates both the home search and History's.
  final String speechQuery;

  /// Matches a recording NAME only, and nothing anyone said. This is what puts
  /// the "Matched the name" line on a tile.
  final String nameQuery;

  /// Matches nothing at all, for the empty-result screens.
  final String missQuery;
}

/// Content for an ARB locale code ('en', 'ja', 'ko', 'zh', 'zh_Hant').
///
/// Falls back to English for an unknown code, so adding a language to the app
/// degrades to a capturable (if untranslated) run rather than a crash.
DemoContent demoContentFor(String arbLocale) {
  switch (arbLocale) {
    case 'ja':
      return _ja;
    case 'ko':
      return _ko;
    case 'zh':
      return _zhHans;
    case 'zh_Hant':
      return _zhHant;
    default:
      return _en;
  }
}

// ---------------------------------------------------------------------------
// Seeding
// ---------------------------------------------------------------------------

/// The app's recordings directory: `Documents/recordings`, the same path
/// `RecordingRepository` scans.
Future<Directory> _recordingsDir() async {
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory(p.join(docs.path, 'recordings'));
  if (!await dir.exists()) await dir.create(recursive: true);
  return dir;
}

/// Empty the recordings folder, so the run starts from a genuine first-launch
/// state and the empty-state screens are real.
Future<void> clearRecordings() async {
  final dir = await _recordingsDir();
  await for (final entry in dir.list()) {
    if (entry is File) await entry.delete();
  }
}

/// Write the whole demo library to disk.
///
/// Roughly 38 MB of WAV across twelve recordings; a couple of seconds on an
/// emulator. Called once per capture run, before the app is pumped.
Future<void> seedRecordings(DemoContent content) async {
  final dir = await _recordingsDir();
  final now = DateTime.now();

  for (final recording in content.recordings) {
    final when = _timestampFor(recording, now);
    final base = recording.name ?? _generatedName(when);
    final wav = File(p.join(dir.path, '$base.wav'));

    await wav.writeAsBytes(_audioFor(recording.seconds), flush: true);
    // A generated name carries its own timestamp, which the repository parses.
    // A user-named file has none, so the repository falls back to the file's
    // modified time — which means the demo library has to set it.
    wav.setLastModifiedSync(when);

    if (recording.hasTranscript) {
      await File(p.join(dir.path, '$base.txt')).writeAsString(
        jsonEncode({
          'text': recording.text,
          'languages': recording.languages,
          'segments': [
            for (final s in recording.segments)
              {
                'startMs': s.startMs,
                'endMs': s.endMs,
                'text': s.text,
                'language': s.language,
              },
          ],
        }),
        flush: true,
      );
    }
  }
}

/// When a seeded recording claims to have been made.
///
/// Today's entries are pulled back to the current time if their nominal hour
/// has not happened yet, because a recording stamped three hours in the future
/// is the kind of detail a reviewer notices in a screenshot.
DateTime _timestampFor(DemoRecording r, DateTime now) {
  final nominal = DateTime(now.year, now.month, now.day, r.hour, r.minute)
      .subtract(Duration(days: r.daysAgo));
  if (r.daysAgo > 0 || nominal.isBefore(now)) return nominal;
  // Still today, but earlier: space the clamped ones a minute apart so the
  // list keeps a stable order instead of collapsing onto one timestamp.
  return now.subtract(Duration(minutes: 1 + r.hour % 5));
}

String _generatedName(DateTime when) {
  String two(int v) => v.toString().padLeft(2, '0');
  return 'recording_${when.year}${two(when.month)}${two(when.day)}'
      '_${two(when.hour)}${two(when.minute)}${two(when.second)}';
}

// --- audio -----------------------------------------------------------------

const int _sampleRate = 16000;
const int _bytesPerSecond = _sampleRate * 2;

/// Eight one-second PCM blocks at rising loudness, built once per run.
///
/// Assembling a recording out of pre-built blocks keeps seeding to a few
/// `setRange` copies per second of audio instead of millions of per-sample
/// computations — the difference between a run that starts in two seconds and
/// one that starts in thirty.
List<Uint8List>? _blocks;

List<Uint8List> _blockLibrary() {
  if (_blocks != null) return _blocks!;
  const gains = [0.18, 0.42, 0.71, 0.95, 0.55, 0.28, 0.83, 0.36];
  _blocks = [for (final gain in gains) _speechBlock(gain)];
  return _blocks!;
}

/// One second of speech-shaped PCM16: a 180 Hz carrier under a syllable
/// envelope, with a short pause at the end of the second.
///
/// It is not speech and is not meant to be — it exists so the waveform the app
/// computes has the peaks and gaps a voice recording has, rather than a
/// featureless block. Nothing transcribes it; the transcripts are seeded.
Uint8List _speechBlock(double gain) {
  final out = Uint8List(_bytesPerSecond);
  final data = ByteData.sublistView(out);
  for (var n = 0; n < _sampleRate; n++) {
    final t = n / _sampleRate;
    // Four syllables a second, then 150 ms of near-silence.
    final syllable = math.pow(math.sin(math.pi * (t * 4 % 1.0)), 2).toDouble();
    final pause = t > 0.85 ? 0.06 : 1.0;
    final carrier = math.sin(2 * math.pi * 180 * t);
    final value = carrier * syllable * pause * gain * 26000;
    data.setInt16(n * 2, value.round().clamp(-32768, 32767), Endian.little);
  }
  return out;
}

/// A complete WAV: the app's own header, then [seconds] of assembled blocks.
Uint8List _audioFor(int seconds) {
  final blocks = _blockLibrary();
  final dataBytes = seconds * _bytesPerSecond;
  final out = Uint8List(wavHeaderBytes + dataBytes);
  out.setRange(0, wavHeaderBytes, buildWavHeader(dataBytes: dataBytes));
  for (var s = 0; s < seconds; s++) {
    // Fixed, not random: the same recording length always yields the same
    // waveform, in every locale and on every tier.
    final block = blocks[(s * 5 + s ~/ 7) % blocks.length];
    final at = wavHeaderBytes + s * _bytesPerSecond;
    out.setRange(at, at + _bytesPerSecond, block);
  }
  return out;
}

// ---------------------------------------------------------------------------
// The library, per language
//
// The twelve entries are the same twelve situations in every language, in the
// same order, with the same durations — so `phone_07_ja_…` and `phone_07_ko_…`
// are the same screen. Only the words change.
// ---------------------------------------------------------------------------

const _en = DemoContent(
  speechQuery: 'budget',
  nameQuery: 'groceries',
  missQuery: 'helicopter',
  recordings: [
    DemoRecording(
      daysAgo: 0,
      hour: 9,
      minute: 12,
      seconds: 192,
      name: 'Team standup',
      segments: [
        DemoSegment(0, 9000,
            "Good morning everyone, let's keep this one to ten minutes.", 'english'),
        DemoSegment(12000, 24000,
            'Yesterday I finished the export pipeline and pushed the fix for the upload timeout.',
            'english'),
        DemoSegment(31000, 44000,
            "Today I'm picking up the search indexing work, and I need an hour from Maya to review it.",
            'english'),
        DemoSegment(62000, 75000,
            "One blocker: staging is still on the old build, so I can't verify the change end to end.",
            'english'),
        DemoSegment(160000, 172000,
            'Can we confirm the budget for the extra storage before Friday, so procurement has time.',
            'english'),
      ],
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 11,
      minute: 47,
      seconds: 85,
      segments: [
        DemoSegment(1000, 11000,
            'Reminder to myself: call the landlord about the radiator before the weekend.',
            'english'),
        DemoSegment(20000, 33000,
            'Book the car in for a service, and check whether the warranty still covers the brake pads.',
            'english'),
        DemoSegment(48000, 59000,
            'And pick up the dry cleaning on Thursday, it closes at six.', 'english'),
      ],
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 13,
      minute: 5,
      seconds: 38,
      name: 'Groceries voice memo',
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 15,
      minute: 30,
      seconds: 160,
      name: 'Interview — Dr. Chen',
      segments: [
        DemoSegment(0, 12000,
            'Thank you for making the time. Could you start with how the study was designed?',
            'english'),
        DemoSegment(15000, 29000, '我们一共招募了两百四十位参与者，分成三组。', 'mandarin'),
        DemoSegment(35000, 48000,
            'And how long did each group stay in the programme?', 'english'),
        DemoSegment(52000, 68000, '第一组是六个星期，另外两组都是十二个星期。', 'mandarin'),
        DemoSegment(90000, 104000,
            "That's a meaningful difference. Did it hold up at follow-up?", 'english'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 10,
      minute: 20,
      seconds: 130,
      name: 'Physics lecture, chapter 4',
      segments: [
        DemoSegment(2000, 14000,
            'Last week we derived the wave equation from first principles.', 'english'),
        DemoSegment(18000, 32000,
            "Today we look at what happens at a boundary between two media.", 'english'),
        DemoSegment(45000, 60000,
            'The key idea is that the displacement and its slope both have to stay continuous.',
            'english'),
        DemoSegment(100000, 114000,
            'If you remember one thing from this hour, remember that continuity condition.',
            'english'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 16,
      minute: 41,
      seconds: 65,
      segments: [
        DemoSegment(1000, 13000,
            'Idea for the article: open with the ferry crossing, not with the history.',
            'english'),
        DemoSegment(19000, 34000,
            'Then bring in the two interviews, and keep the statistics to a single paragraph.',
            'english'),
        DemoSegment(45000, 56000, 'Working title: the last hour of the tide.', 'english'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 21,
      minute: 8,
      seconds: 52,
      name: 'Song idea',
    ),
    DemoRecording(
      daysAgo: 3,
      hour: 14,
      minute: 15,
      seconds: 110,
      name: 'Client call — renewal',
      segments: [
        DemoSegment(2000, 16000,
            "They're happy with the migration, but they want the reporting module before renewal.",
            'english'),
        DemoSegment(22000, 37000,
            'I said we can commit to the export format now and the dashboard next quarter.',
            'english'),
        DemoSegment(55000, 66000, 'They asked for a written summary by Wednesday.',
            'english'),
        DemoSegment(80000, 94000,
            "On budget they have room — it's the timing they're nervous about.", 'english'),
      ],
    ),
    DemoRecording(daysAgo: 5, hour: 8, minute: 3, seconds: 27),
    DemoRecording(
      daysAgo: 8,
      hour: 19,
      minute: 22,
      seconds: 90,
      name: 'Book notes — chapter one',
      segments: [
        DemoSegment(1000, 14000,
            'The opening chapter sets up the town before it introduces a single character.',
            'english'),
        DemoSegment(20000, 36000,
            "That's a risk, but it pays off — by chapter three the geography is doing the work.",
            'english'),
        DemoSegment(48000, 58000, 'Note the repeated image of the flooded field.',
            'english'),
        DemoSegment(70000, 82000,
            'Come back to the question of whether the narrator is reliable.', 'english'),
      ],
    ),
    DemoRecording(
      daysAgo: 12,
      hour: 11,
      minute: 5,
      seconds: 108,
      name: "Doctor's appointment",
      segments: [
        DemoSegment(2000, 15000,
            'Blood pressure was a hundred and eighteen over seventy-six, which is fine.',
            'english'),
        DemoSegment(24000, 38000,
            'She suggested keeping the current dose for another six weeks.', 'english'),
        DemoSegment(55000, 70000,
            'Bring the readings from the home monitor to the next appointment.', 'english'),
        DemoSegment(88000, 99000, 'The next appointment is in six weeks.', 'english'),
      ],
    ),
    DemoRecording(
      daysAgo: 18,
      hour: 17,
      minute: 50,
      seconds: 142,
      segments: [
        DemoSegment(1000, 15000,
            'Walking home along the canal, thinking about the shape of the second half.',
            'english'),
        DemoSegment(22000, 34000, 'The problem is that the middle section explains too much.',
            'english'),
        DemoSegment(44000, 60000,
            'If I cut the flashback entirely, the reader still has everything they need.',
            'english'),
        DemoSegment(75000, 92000,
            'What I lose is the sense of how long he waited, and that might be worth keeping.',
            'english'),
        DemoSegment(110000, 126000,
            'Try both versions this week, and read them out loud before deciding.', 'english'),
      ],
    ),
  ],
);

const _ja = DemoContent(
  speechQuery: '予算',
  nameQuery: '買い物',
  missQuery: 'ヘリコプター',
  recordings: [
    DemoRecording(
      daysAgo: 0,
      hour: 9,
      minute: 12,
      seconds: 192,
      name: 'チームの朝会',
      segments: [
        DemoSegment(0, 9000, 'おはようございます。今日は十分以内で終わらせましょう。', 'japanese'),
        DemoSegment(12000, 24000,
            '昨日はエクスポート処理を仕上げて、アップロードのタイムアウトの修正も入れました。', 'japanese'),
        DemoSegment(31000, 44000,
            '今日は検索インデックスの作業に入ります。レビューに一時間ほどお願いしたいです。', 'japanese'),
        DemoSegment(62000, 75000,
            '一点だけ、ステージング環境が古いビルドのままなので、通しで確認できていません。', 'japanese'),
        DemoSegment(160000, 172000,
            '追加ストレージの予算を金曜までに確定させたいです。購買部の時間も必要なので。', 'japanese'),
      ],
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 11,
      minute: 47,
      seconds: 85,
      segments: [
        DemoSegment(1000, 11000, '自分用のメモ。週末までに大家さんに暖房の件で連絡すること。', 'japanese'),
        DemoSegment(20000, 33000,
            '車の点検も予約する。ブレーキパッドが保証の対象かどうかも確認しておく。', 'japanese'),
        DemoSegment(48000, 59000, 'それと木曜にクリーニングを取りに行く。六時に閉まる。', 'japanese'),
      ],
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 13,
      minute: 5,
      seconds: 38,
      name: '買い物メモ',
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 15,
      minute: 30,
      seconds: 160,
      name: 'インタビュー — 陳先生',
      segments: [
        DemoSegment(0, 12000, 'お時間をいただきありがとうございます。まず研究の設計から伺えますか。',
            'japanese'),
        DemoSegment(15000, 29000,
            'We recruited two hundred and forty participants, split into three groups.',
            'english'),
        DemoSegment(35000, 48000, '各グループの参加期間はどのくらいでしたか。', 'japanese'),
        DemoSegment(52000, 68000,
            'The first group ran for six weeks, the other two for twelve.', 'english'),
        DemoSegment(90000, 104000, 'それは大きな差ですね。追跡調査でも同じ傾向でしたか。', 'japanese'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 10,
      minute: 20,
      seconds: 130,
      name: '物理の講義 第四章',
      segments: [
        DemoSegment(2000, 14000, '先週は波動方程式を第一原理から導きました。', 'japanese'),
        DemoSegment(18000, 32000, '今日は二つの媒質の境界で何が起こるかを見ていきます。', 'japanese'),
        DemoSegment(45000, 60000, '要点は、変位とその傾きの両方が連続でなければならないということです。',
            'japanese'),
        DemoSegment(100000, 114000, 'この一時間で一つだけ覚えるなら、この連続条件を覚えてください。',
            'japanese'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 16,
      minute: 41,
      seconds: 65,
      segments: [
        DemoSegment(1000, 13000, '記事の構成案。歴史からではなく、フェリーの場面から始める。', 'japanese'),
        DemoSegment(19000, 34000, '次に二本のインタビューを入れて、統計は一段落に収める。', 'japanese'),
        DemoSegment(45000, 56000, '仮のタイトルは「潮の最後の一時間」。', 'japanese'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 21,
      minute: 8,
      seconds: 52,
      name: '曲のアイデア',
    ),
    DemoRecording(
      daysAgo: 3,
      hour: 14,
      minute: 15,
      seconds: 110,
      name: '顧客との通話 — 更新',
      segments: [
        DemoSegment(2000, 16000, '移行には満足されていますが、更新前にレポート機能が欲しいとのことです。',
            'japanese'),
        DemoSegment(22000, 37000,
            'エクスポート形式は今すぐ、ダッシュボードは来四半期でどうかと伝えました。', 'japanese'),
        DemoSegment(55000, 66000, '水曜までに書面でまとめてほしいと依頼されました。', 'japanese'),
        DemoSegment(80000, 94000, '予算には余裕があり、心配しているのは時期の方です。', 'japanese'),
      ],
    ),
    DemoRecording(daysAgo: 5, hour: 8, minute: 3, seconds: 27),
    DemoRecording(
      daysAgo: 8,
      hour: 19,
      minute: 22,
      seconds: 90,
      name: '読書メモ — 第一章',
      segments: [
        DemoSegment(1000, 14000, '冒頭の章は、人物より先に町そのものを描いている。', 'japanese'),
        DemoSegment(20000, 36000,
            '危うい構成だが効いている。第三章では土地の描写がそのまま物語を動かしている。', 'japanese'),
        DemoSegment(48000, 58000, '水に沈んだ畑の描写が繰り返されるのに注目。', 'japanese'),
        DemoSegment(70000, 82000, '語り手が信頼できるかどうかは、後でもう一度考えたい。', 'japanese'),
      ],
    ),
    DemoRecording(
      daysAgo: 12,
      hour: 11,
      minute: 5,
      seconds: 108,
      name: '通院メモ',
      segments: [
        DemoSegment(2000, 15000, '血圧は百十八の七十六で、問題ないとのことでした。', 'japanese'),
        DemoSegment(24000, 38000, '今の量をあと六週間続けましょう、と言われました。', 'japanese'),
        DemoSegment(55000, 70000, '次回は家庭用の血圧計の記録を持っていくこと。', 'japanese'),
        DemoSegment(88000, 99000, '次の診察は六週間後です。', 'japanese'),
      ],
    ),
    DemoRecording(
      daysAgo: 18,
      hour: 17,
      minute: 50,
      seconds: 142,
      segments: [
        DemoSegment(1000, 15000, '運河沿いを歩きながら、後半の構成について考えていた。', 'japanese'),
        DemoSegment(22000, 34000, '問題は、中盤で説明しすぎていることだ。', 'japanese'),
        DemoSegment(44000, 60000, '回想をすべて削っても、読者に必要なものは残る。', 'japanese'),
        DemoSegment(75000, 92000,
            '失われるのは彼がどれだけ待ったかという感覚で、それは惜しいかもしれない。', 'japanese'),
        DemoSegment(110000, 126000, '今週は両方の版を書いて、声に出して読んでから決める。', 'japanese'),
      ],
    ),
  ],
);

const _ko = DemoContent(
  speechQuery: '예산',
  nameQuery: '장보기',
  missQuery: '헬리콥터',
  recordings: [
    DemoRecording(
      daysAgo: 0,
      hour: 9,
      minute: 12,
      seconds: 192,
      name: '팀 스탠드업',
      segments: [
        DemoSegment(0, 9000, '좋은 아침입니다. 오늘은 십 분 안에 끝내죠.', 'korean'),
        DemoSegment(12000, 24000,
            '어제는 내보내기 파이프라인을 끝냈고 업로드 시간 초과 수정도 반영했습니다.', 'korean'),
        DemoSegment(31000, 44000,
            '오늘은 검색 색인 작업을 시작합니다. 검토에 한 시간 정도 도움이 필요합니다.', 'korean'),
        DemoSegment(62000, 75000,
            '한 가지 막힌 부분은 스테이징이 아직 예전 빌드라 전체 흐름을 확인하지 못한 점입니다.',
            'korean'),
        DemoSegment(160000, 172000,
            '추가 저장 공간 예산을 금요일 전에 확정했으면 합니다. 구매팀 시간도 필요하니까요.', 'korean'),
      ],
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 11,
      minute: 47,
      seconds: 85,
      segments: [
        DemoSegment(1000, 11000, '메모. 주말 전에 집주인에게 난방 문제로 연락할 것.', 'korean'),
        DemoSegment(20000, 33000,
            '차량 점검도 예약하고, 브레이크 패드가 보증에 포함되는지 확인하기.', 'korean'),
        DemoSegment(48000, 59000, '그리고 목요일에 세탁물 찾아오기. 여섯 시에 문 닫음.', 'korean'),
      ],
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 13,
      minute: 5,
      seconds: 38,
      name: '장보기 메모',
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 15,
      minute: 30,
      seconds: 160,
      name: '인터뷰 — 첸 박사',
      segments: [
        DemoSegment(0, 12000, '시간 내주셔서 감사합니다. 연구 설계부터 말씀해 주시겠어요?', 'korean'),
        DemoSegment(15000, 29000,
            'We recruited two hundred and forty participants, split into three groups.',
            'english'),
        DemoSegment(35000, 48000, '각 그룹은 얼마나 오래 참여했나요?', 'korean'),
        DemoSegment(52000, 68000,
            'The first group ran for six weeks, the other two for twelve.', 'english'),
        DemoSegment(90000, 104000, '의미 있는 차이네요. 추적 조사에서도 유지되었나요?', 'korean'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 10,
      minute: 20,
      seconds: 130,
      name: '물리학 강의 4장',
      segments: [
        DemoSegment(2000, 14000, '지난주에는 파동 방정식을 기본 원리에서 유도했습니다.', 'korean'),
        DemoSegment(18000, 32000, '오늘은 두 매질의 경계에서 무슨 일이 일어나는지 봅니다.', 'korean'),
        DemoSegment(45000, 60000, '핵심은 변위와 그 기울기가 모두 연속이어야 한다는 점입니다.',
            'korean'),
        DemoSegment(100000, 114000, '오늘 한 가지만 기억한다면, 이 연속 조건을 기억하세요.', 'korean'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 16,
      minute: 41,
      seconds: 65,
      segments: [
        DemoSegment(1000, 13000, '기사 구성 아이디어. 역사가 아니라 배 타는 장면으로 시작하기.',
            'korean'),
        DemoSegment(19000, 34000, '그다음 인터뷰 두 건을 넣고, 통계는 한 문단으로 줄이기.', 'korean'),
        DemoSegment(45000, 56000, '가제는 "조수의 마지막 한 시간".', 'korean'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 21,
      minute: 8,
      seconds: 52,
      name: '곡 아이디어',
    ),
    DemoRecording(
      daysAgo: 3,
      hour: 14,
      minute: 15,
      seconds: 110,
      name: '고객 통화 — 갱신',
      segments: [
        DemoSegment(2000, 16000, '이전 작업에는 만족하지만, 갱신 전에 리포트 기능을 원한다고 합니다.',
            'korean'),
        DemoSegment(22000, 37000,
            '내보내기 형식은 지금, 대시보드는 다음 분기로 하자고 전달했습니다.', 'korean'),
        DemoSegment(55000, 66000, '수요일까지 서면 요약을 요청받았습니다.', 'korean'),
        DemoSegment(80000, 94000, '예산은 여유가 있고, 걱정하는 것은 일정 쪽입니다.', 'korean'),
      ],
    ),
    DemoRecording(daysAgo: 5, hour: 8, minute: 3, seconds: 27),
    DemoRecording(
      daysAgo: 8,
      hour: 19,
      minute: 22,
      seconds: 90,
      name: '독서 메모 — 1장',
      segments: [
        DemoSegment(1000, 14000, '첫 장은 인물보다 마을을 먼저 세운다.', 'korean'),
        DemoSegment(20000, 36000,
            '위험한 선택이지만 통한다. 3장쯤에는 지리가 이야기를 밀고 간다.', 'korean'),
        DemoSegment(48000, 58000, '물에 잠긴 밭의 이미지가 반복되는 점에 주목.', 'korean'),
        DemoSegment(70000, 82000, '화자를 믿을 수 있는지는 다시 생각해 볼 것.', 'korean'),
      ],
    ),
    DemoRecording(
      daysAgo: 12,
      hour: 11,
      minute: 5,
      seconds: 108,
      name: '진료 메모',
      segments: [
        DemoSegment(2000, 15000, '혈압은 118에 76으로 괜찮다고 했습니다.', 'korean'),
        DemoSegment(24000, 38000, '지금 용량을 육 주 더 유지하자고 하셨습니다.', 'korean'),
        DemoSegment(55000, 70000, '다음 진료에는 가정용 혈압계 기록을 가져갈 것.', 'korean'),
        DemoSegment(88000, 99000, '다음 진료는 육 주 뒤입니다.', 'korean'),
      ],
    ),
    DemoRecording(
      daysAgo: 18,
      hour: 17,
      minute: 50,
      seconds: 142,
      segments: [
        DemoSegment(1000, 15000, '운하를 따라 걸으며 후반부의 구성을 생각했다.', 'korean'),
        DemoSegment(22000, 34000, '문제는 중반부가 너무 많이 설명한다는 것.', 'korean'),
        DemoSegment(44000, 60000, '회상을 전부 덜어내도 독자에게 필요한 것은 남는다.', 'korean'),
        DemoSegment(75000, 92000,
            '잃는 것은 그가 얼마나 오래 기다렸는지에 대한 감각인데, 그건 아까울 수 있다.', 'korean'),
        DemoSegment(110000, 126000, '이번 주에 두 버전을 다 써 보고, 소리 내어 읽은 뒤 정하기.',
            'korean'),
      ],
    ),
  ],
);

const _zhHans = DemoContent(
  speechQuery: '预算',
  nameQuery: '购物',
  missQuery: '直升机',
  recordings: [
    DemoRecording(
      daysAgo: 0,
      hour: 9,
      minute: 12,
      seconds: 192,
      name: '团队晨会',
      segments: [
        DemoSegment(0, 9000, '大家早上好，我们今天控制在十分钟以内。', 'mandarin'),
        DemoSegment(12000, 24000, '昨天我把导出流程做完了，上传超时的修复也提交了。', 'mandarin'),
        DemoSegment(31000, 44000, '今天开始做搜索索引，需要占用玛雅一个小时帮忙评审。', 'mandarin'),
        DemoSegment(62000, 75000, '有一个阻碍：预发布环境还是旧版本，没法完整验证这次改动。',
            'mandarin'),
        DemoSegment(160000, 172000, '希望周五之前确定扩容的预算，采购那边也需要时间。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 11,
      minute: 47,
      seconds: 85,
      segments: [
        DemoSegment(1000, 11000, '提醒自己：周末之前联系房东处理暖气的问题。', 'mandarin'),
        DemoSegment(20000, 33000, '再约一次车辆保养，顺便确认刹车片还在不在保修范围内。',
            'mandarin'),
        DemoSegment(48000, 59000, '还有周四去取干洗的衣服，六点关门。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 13,
      minute: 5,
      seconds: 38,
      name: '购物备忘',
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 15,
      minute: 30,
      seconds: 160,
      name: '访谈 — 陈医生',
      segments: [
        DemoSegment(0, 12000, '谢谢您抽时间。能先讲讲这项研究是怎么设计的吗？', 'mandarin'),
        DemoSegment(15000, 29000,
            'We recruited two hundred and forty participants, split into three groups.',
            'english'),
        DemoSegment(35000, 48000, '每一组分别参与了多长时间？', 'mandarin'),
        DemoSegment(52000, 68000,
            'The first group ran for six weeks, the other two for twelve.', 'english'),
        DemoSegment(90000, 104000, '这个差别不小。随访的时候还保持吗？', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 10,
      minute: 20,
      seconds: 130,
      name: '物理课 第四章',
      segments: [
        DemoSegment(2000, 14000, '上周我们从基本原理推导了波动方程。', 'mandarin'),
        DemoSegment(18000, 32000, '今天来看两种介质的交界面上会发生什么。', 'mandarin'),
        DemoSegment(45000, 60000, '关键在于位移和它的斜率都必须保持连续。', 'mandarin'),
        DemoSegment(100000, 114000, '这一节课如果只记一件事，就记住这个连续条件。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 16,
      minute: 41,
      seconds: 65,
      segments: [
        DemoSegment(1000, 13000, '稿子的思路：从渡轮那一段开头，不要从历史讲起。', 'mandarin'),
        DemoSegment(19000, 34000, '然后放两段访谈，统计数字压缩到一段之内。', 'mandarin'),
        DemoSegment(45000, 56000, '暂定标题：潮水的最后一小时。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 21,
      minute: 8,
      seconds: 52,
      name: '歌曲灵感',
    ),
    DemoRecording(
      daysAgo: 3,
      hour: 14,
      minute: 15,
      seconds: 110,
      name: '客户电话 — 续约',
      segments: [
        DemoSegment(2000, 16000, '他们对迁移很满意，但希望续约之前先有报表模块。', 'mandarin'),
        DemoSegment(22000, 37000, '我说导出格式可以现在定，仪表盘放到下个季度。', 'mandarin'),
        DemoSegment(55000, 66000, '他们要求周三之前给一份书面小结。', 'mandarin'),
        DemoSegment(80000, 94000, '预算上他们还有空间，真正担心的是时间。', 'mandarin'),
      ],
    ),
    DemoRecording(daysAgo: 5, hour: 8, minute: 3, seconds: 27),
    DemoRecording(
      daysAgo: 8,
      hour: 19,
      minute: 22,
      seconds: 90,
      name: '读书笔记 — 第一章',
      segments: [
        DemoSegment(1000, 14000, '开篇先写这座小镇，一个人物都还没出场。', 'mandarin'),
        DemoSegment(20000, 36000, '这是冒险的写法，但很有效，到第三章地理本身就在推动故事。',
            'mandarin'),
        DemoSegment(48000, 58000, '注意反复出现的那片被水淹没的田地。', 'mandarin'),
        DemoSegment(70000, 82000, '叙述者是否可靠，这一点还要再想一想。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 12,
      hour: 11,
      minute: 5,
      seconds: 108,
      name: '就诊记录',
      segments: [
        DemoSegment(2000, 15000, '血压是一百一十八和七十六，医生说没问题。', 'mandarin'),
        DemoSegment(24000, 38000, '她建议现在的剂量再维持六周。', 'mandarin'),
        DemoSegment(55000, 70000, '下次复诊要带上家用血压计的记录。', 'mandarin'),
        DemoSegment(88000, 99000, '下一次复诊在六周以后。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 18,
      hour: 17,
      minute: 50,
      seconds: 142,
      segments: [
        DemoSegment(1000, 15000, '沿着运河走回家，一路在想后半部分该怎么搭。', 'mandarin'),
        DemoSegment(22000, 34000, '问题是中间那一段解释得太多了。', 'mandarin'),
        DemoSegment(44000, 60000, '就算把回忆整段删掉，读者需要的东西还都在。', 'mandarin'),
        DemoSegment(75000, 92000, '会失去的是他等了多久的那种感觉，这也许值得留着。', 'mandarin'),
        DemoSegment(110000, 126000, '这周把两个版本都写出来，念一遍再决定。', 'mandarin'),
      ],
    ),
  ],
);

const _zhHant = DemoContent(
  speechQuery: '預算',
  nameQuery: '購物',
  missQuery: '直升機',
  recordings: [
    DemoRecording(
      daysAgo: 0,
      hour: 9,
      minute: 12,
      seconds: 192,
      name: '團隊晨會',
      segments: [
        DemoSegment(0, 9000, '大家早安，我們今天控制在十分鐘以內。', 'mandarin'),
        DemoSegment(12000, 24000, '昨天我把匯出流程做完了，上傳逾時的修正也送出了。', 'mandarin'),
        DemoSegment(31000, 44000, '今天開始做搜尋索引，需要佔用瑪雅一個小時幫忙審查。', 'mandarin'),
        DemoSegment(62000, 75000, '有一個阻礙：預備環境還是舊版本，沒辦法完整驗證這次的改動。',
            'mandarin'),
        DemoSegment(160000, 172000, '希望週五之前確定擴充儲存的預算，採購那邊也需要時間。',
            'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 11,
      minute: 47,
      seconds: 85,
      segments: [
        DemoSegment(1000, 11000, '提醒自己：週末之前聯絡房東處理暖氣的問題。', 'mandarin'),
        DemoSegment(20000, 33000, '再約一次汽車保養，順便確認煞車來令片還在不在保固範圍。',
            'mandarin'),
        DemoSegment(48000, 59000, '還有週四去拿乾洗的衣服，六點關門。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 13,
      minute: 5,
      seconds: 38,
      name: '購物備忘',
    ),
    DemoRecording(
      daysAgo: 0,
      hour: 15,
      minute: 30,
      seconds: 160,
      name: '訪談 — 陳醫師',
      segments: [
        DemoSegment(0, 12000, '謝謝您撥空。可以先談談這項研究是怎麼設計的嗎？', 'mandarin'),
        DemoSegment(15000, 29000,
            'We recruited two hundred and forty participants, split into three groups.',
            'english'),
        DemoSegment(35000, 48000, '每一組分別參與了多長時間？', 'mandarin'),
        DemoSegment(52000, 68000,
            'The first group ran for six weeks, the other two for twelve.', 'english'),
        DemoSegment(90000, 104000, '這個差別不小。追蹤時還維持嗎？', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 10,
      minute: 20,
      seconds: 130,
      name: '物理課 第四章',
      segments: [
        DemoSegment(2000, 14000, '上週我們從基本原理推導了波動方程式。', 'mandarin'),
        DemoSegment(18000, 32000, '今天來看兩種介質的交界面上會發生什麼事。', 'mandarin'),
        DemoSegment(45000, 60000, '關鍵在於位移和它的斜率都必須保持連續。', 'mandarin'),
        DemoSegment(100000, 114000, '這堂課如果只記一件事，就記住這個連續條件。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 16,
      minute: 41,
      seconds: 65,
      segments: [
        DemoSegment(1000, 13000, '稿子的想法：從渡輪那一段開頭，不要從歷史講起。', 'mandarin'),
        DemoSegment(19000, 34000, '接著放兩段訪談，統計數字壓縮到一段之內。', 'mandarin'),
        DemoSegment(45000, 56000, '暫定標題：潮水的最後一小時。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 1,
      hour: 21,
      minute: 8,
      seconds: 52,
      name: '歌曲靈感',
    ),
    DemoRecording(
      daysAgo: 3,
      hour: 14,
      minute: 15,
      seconds: 110,
      name: '客戶電話 — 續約',
      segments: [
        DemoSegment(2000, 16000, '他們對移轉很滿意，但希望續約之前先有報表模組。', 'mandarin'),
        DemoSegment(22000, 37000, '我說匯出格式可以現在定，儀表板放到下一季。', 'mandarin'),
        DemoSegment(55000, 66000, '他們要求週三之前給一份書面摘要。', 'mandarin'),
        DemoSegment(80000, 94000, '預算上他們還有空間，真正擔心的是時間。', 'mandarin'),
      ],
    ),
    DemoRecording(daysAgo: 5, hour: 8, minute: 3, seconds: 27),
    DemoRecording(
      daysAgo: 8,
      hour: 19,
      minute: 22,
      seconds: 90,
      name: '讀書筆記 — 第一章',
      segments: [
        DemoSegment(1000, 14000, '開篇先寫這座小鎮，一個人物都還沒出場。', 'mandarin'),
        DemoSegment(20000, 36000, '這是冒險的寫法，但很有效，到第三章地理本身就在推動故事。',
            'mandarin'),
        DemoSegment(48000, 58000, '注意反覆出現的那片被水淹沒的田地。', 'mandarin'),
        DemoSegment(70000, 82000, '敘事者是否可靠，這一點還要再想一想。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 12,
      hour: 11,
      minute: 5,
      seconds: 108,
      name: '就診紀錄',
      segments: [
        DemoSegment(2000, 15000, '血壓是一百一十八和七十六，醫師說沒問題。', 'mandarin'),
        DemoSegment(24000, 38000, '她建議現在的劑量再維持六週。', 'mandarin'),
        DemoSegment(55000, 70000, '下次回診要帶家用血壓計的紀錄。', 'mandarin'),
        DemoSegment(88000, 99000, '下一次回診在六週以後。', 'mandarin'),
      ],
    ),
    DemoRecording(
      daysAgo: 18,
      hour: 17,
      minute: 50,
      seconds: 142,
      segments: [
        DemoSegment(1000, 15000, '沿著運河走回家，一路在想後半部該怎麼搭。', 'mandarin'),
        DemoSegment(22000, 34000, '問題是中間那一段解釋得太多了。', 'mandarin'),
        DemoSegment(44000, 60000, '就算把回憶整段刪掉，讀者需要的東西還都在。', 'mandarin'),
        DemoSegment(75000, 92000, '會失去的是他等了多久的那種感覺，這也許值得留著。', 'mandarin'),
        DemoSegment(110000, 126000, '這週把兩個版本都寫出來，唸一遍再決定。', 'mandarin'),
      ],
    ),
  ],
);
