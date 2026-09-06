// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => 'Momera.Audio';

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
  String get languageSystem => 'システムに合わせる';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsStorage => 'ストレージ';

  @override
  String get settingsMaxStorage => '最大ストレージ';

  @override
  String get settingsMaxStorageSubtitle => '録音の合計サイズがこの上限に達すると、録音は自動的に停止します。';

  @override
  String settingsStorageUsed(String used, String total) {
    return '$total 中 $used を使用中';
  }

  @override
  String get settingsRecording => '録音';

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
  String get settingsTranscription => '文字起こし';

  @override
  String get settingsTranscriptionLanguage => '話される言語';

  @override
  String get settingsTranscriptionLanguageSubtitle =>
      '自動検出はフレーズごとに言語を判定するため、会話の途中で言語が変わっても正しく文字起こしできます。音声が常に同じ言語の場合は、言語を指定してください。';

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
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 件',
    );
    return '$_temp0';
  }

  @override
  String get searchMatchedName => '名前が一致';

  @override
  String get clear => 'クリア';

  @override
  String get translate => '翻訳';

  @override
  String get translateTo => '翻訳先';

  @override
  String get translating => '翻訳中…';

  @override
  String get translationFailed => '翻訳に失敗しました。';

  @override
  String get translationUnsupported => 'この端末ではこの言語の組み合わせを翻訳できません。';

  @override
  String get translationCantonese => '広東語の翻訳にはオンライン翻訳が必要ですが、現在は利用できません。';

  @override
  String translationOf(String language) {
    return '翻訳（$language）';
  }

  @override
  String get translationSourceUnknown =>
      '翻訳には検出された言語が1つ必要です。この録音には言語がないか、複数含まれています。';

  @override
  String get langEnglish => '英語';

  @override
  String get langChineseSimplified => '中国語（簡体字）';

  @override
  String get langChineseTraditional => '中国語（繁体字）';

  @override
  String get langJapanese => '日本語';

  @override
  String get langKorean => '韓国語';

  @override
  String get langCantonese => '広東語';
}
