// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'McRecorder';

  @override
  String get tapToRecord => 'タップして録音';

  @override
  String get noRecordingsTitle => '録音がまだありません';

  @override
  String get noRecordingsBody => '録音ボタンをタップして音声を記録します。';

  @override
  String get micPermissionRequired => '録音にはマイクへのアクセス許可が必要です。';

  @override
  String loadFailed(String error) {
    return '読み込みに失敗しました：$error';
  }

  @override
  String get transcribe => '文字起こし';

  @override
  String get deleteRecordingTitle => 'この録音を削除しますか？';

  @override
  String get deleteRecordingBody => 'この操作は取り消せません。';

  @override
  String get delete => '削除';

  @override
  String get cancel => 'キャンセル';

  @override
  String get retry => '再試行';

  @override
  String get downloadModelTitle => '音声モデルをダウンロード';

  @override
  String downloadModelBody(String size) {
    return '文字起こしは完全にオフラインで動作します。音声モデル（$size）は一度だけダウンロードされ、この端末に保存されます。';
  }

  @override
  String get download => 'ダウンロード';

  @override
  String get downloadFailed => 'ダウンロードに失敗しました。接続を確認して、もう一度お試しください。';

  @override
  String get settings => '設定';

  @override
  String get settingsLanguage => '言語';

  @override
  String get settingsLanguageSubtitle => 'アプリ全体で使用する言語';

  @override
  String get settingsInfo => 'この設定について';

  @override
  String get languageSystem => 'システムに合わせる';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsMaxStorage => '最大ストレージ';

  @override
  String get settingsMaxStorageSubtitle =>
      '録音の合計がこのサイズに達すると録音を停止します。表示している時間は音声の長さです。「無音をスキップ」がオンのときは、実際の録音時間はこれより長くなります。';

  @override
  String settingsStorageUsed(String used, String total) {
    return '$total 中 $used を使用中';
  }

  @override
  String get settingsAutosaveInterval => '自動保存の間隔';

  @override
  String get settingsAutosaveIntervalSubtitle =>
      '録音中の音声をディスクに書き込む間隔です。クラッシュしても失われるのは最大でこの長さだけです。';

  @override
  String seconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 秒',
    );
    return '$_temp0';
  }

  @override
  String storageFullBody(String limit) {
    return '録音の合計サイズが上限（$limit）に達したため、録音を停止しました。録音を削除するか、設定で上限を引き上げてください。';
  }

  @override
  String get fileSizeLimitBody =>
      'この録音が1つの音声ファイルに保存できる最大の長さに達したため、録音を停止しました。録音は保存済みです。続けるには新しい録音を開始してください。';

  @override
  String get recoveredRecordingBody => '中断された録音を復元しました。';

  @override
  String get stop => '停止';

  @override
  String get notificationRecording => '録音中';

  @override
  String get noSpeechDetected => 'この録音から音声を検出できませんでした。';

  @override
  String get modelNotReady => '音声モデルの準備ができていません。';

  @override
  String get transcriptionFailed => '文字起こしに失敗しました。';

  @override
  String transcribingPercent(int percent) {
    return '文字起こし中… $percent%';
  }

  @override
  String get playbackFailed => 'この録音を再生できませんでした。';

  @override
  String get sttAuto => '自動検出';

  @override
  String get sttMandarin => '中国語（普通話）';

  @override
  String get sttCantonese => '広東語';

  @override
  String get sttEnglish => '英語';

  @override
  String get sttJapanese => '日本語';

  @override
  String get sttKorean => '韓国語';

  @override
  String detectedLanguages(String languages) {
    return '検出された言語：$languages';
  }

  @override
  String get rename => '名前を変更';

  @override
  String get renameTitle => '録音の名前を変更';

  @override
  String get renameHint => '名前';

  @override
  String get renameEmpty => '名前を入力してください。';

  @override
  String get renameExists => '同じ名前の録音がすでにあります。';

  @override
  String get renameFailed => '録音の名前を変更できませんでした。';

  @override
  String get save => '保存';

  @override
  String get transcriptLabel => '文字起こし';

  @override
  String get copyTranscript => '文字起こしをコピー';

  @override
  String get copied => '文字起こしをコピーしました。';

  @override
  String get share => '共有';

  @override
  String get shareAudio => '音声を共有';

  @override
  String get shareTranscript => '文字起こしを共有';

  @override
  String get shareFailed => 'この録音を共有できませんでした。';

  @override
  String get pause => '一時停止';

  @override
  String get resume => '再開';

  @override
  String get paused => '一時停止中';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageKorean => '한국어';

  @override
  String get searchHint => '録音と文字起こしを検索';

  @override
  String searchNoResults(String query) {
    return '「$query」に一致するものはありません。';
  }

  @override
  String get searchNoResultsHint => '発話内容で検索できるのは、文字起こし済みの録音だけです。';

  @override
  String get searchHintNamesOnly => '録音を検索';

  @override
  String get searchNoResultsHintNamesOnly => '検索は録音の名前と照合します。';

  @override
  String get transcriptionLoadFailed => 'この端末では音声モデルを読み込めませんでした。';

  @override
  String get searchMatchedName => '名前が一致';

  @override
  String get clear => 'クリア';

  @override
  String get liveHold => '長押しでリアルタイム表示';

  @override
  String get liveListening => '認識中…';

  @override
  String get liveStarting => '起動中…';

  @override
  String get liveEmpty => 'ボタンを長押しして話してください。一文ごとに文字が表示されます。';

  @override
  String get liveUnavailable => 'リアルタイム表示には音声モデルのダウンロードが必要です。';

  @override
  String get liveBusy => '実行中の文字起こしが終わるまでお待ちください。';

  @override
  String notEnoughSpaceBody(String needed, String available) {
    return '音声モデルをダウンロードするには $needed の空き容量が必要です。現在の空き容量は $available です。';
  }

  @override
  String get waveformSeek => 'この録音内を移動';

  @override
  String get removeTranscript => '文字起こしを削除';

  @override
  String get removeTranscriptTitle => 'この文字起こしを削除しますか？';

  @override
  String get removeTranscriptBody => '文字起こしが削除されます。この録音はいつでも再度文字起こしできます。';

  @override
  String get transcriptRemoved => '文字起こしを削除しました。';

  @override
  String get livePanelHidden => 'リアルタイム表示を隠しました。字幕ボタンを長押しすると再表示できます。';

  @override
  String get today => '今日';

  @override
  String get yesterday => '昨日';

  @override
  String get history => '履歴';

  @override
  String get settingsHistorySubtitle =>
      'これまでの録音がすべて新しい順に並びます。ホームには今日の録音だけが残り、それ以外はここにあります。';

  @override
  String historyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件の録音',
      zero: '録音なし',
    );
    return '$_temp0';
  }

  @override
  String get noRecordingsTodayTitle => '今日の録音はありません';

  @override
  String get noRecordingsTodayBody => '録音ボタンをタップして始めましょう。以前の録音は「履歴」にあります。';

  @override
  String get openHistory => '履歴を開く';

  @override
  String get searchNoResultsHintToday =>
      'ここでは今日の録音だけを検索します。すべて検索するには「履歴」を使ってください。';

  @override
  String get playbackBlockedWhileRecording => '録音を停止してから、ほかの録音を再生してください。';

  @override
  String get hideLiveText => 'リアルタイム文字を隠す';

  @override
  String get skipSilence => '無音をスキップ';

  @override
  String get skipSilenceOnTitle => '無音をスキップ中';

  @override
  String get skipSilenceOnBody => '音声だけを録音します。';

  @override
  String get skipSilenceOffTitle => 'すべて録音';

  @override
  String get skipSilenceOffBody => '無音も録音します。';

  @override
  String get skipSilenceUnavailable => 'この端末では無音のスキップを利用できません。';

  @override
  String get settingsTheme => 'テーマ';

  @override
  String get settingsThemeSubtitle =>
      'ライトまたはダーク。既定では端末の設定に従います。暗い部屋でライト設定の端末を使うときなどに、手動で選べます。';

  @override
  String get themeSystem => '端末に合わせる';

  @override
  String get themeLight => 'ライト';

  @override
  String get themeDark => 'ダーク';

  @override
  String get noRecordingsOnDay => 'この日の録音はありません。';

  @override
  String get noRecordingsOnDayHint => '強調表示された日付をもう一度タップすると、すべての録音が表示されます。';

  @override
  String get recordingReconnecting => 'マイクを失いました。再接続しています…';

  @override
  String get recordingResumed => '録音を再開しました。';

  @override
  String get recordingInterruptedBody =>
      '録音を停止しました。マイクが使用できないままでした。それまでに録音した内容はすべて保存されています。';

  @override
  String get recordingWriteFailedBody =>
      '録音を停止しました：音声をこの端末に保存できませんでした。そこまでに録音した内容は保存されています。';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours 時間 $minutes 分';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分',
      zero: '1 分未満',
    );
    return '$_temp0';
  }

  @override
  String settingsStorageDurations(String recorded, String remaining) {
    return '録音済み $recorded · あと約 $remaining 録音できます';
  }
}
