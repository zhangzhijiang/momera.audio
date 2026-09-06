// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Momera.Audio';

  @override
  String get tapToRecord => '点击录音';

  @override
  String get noRecordingsTitle => '还没有录音';

  @override
  String get noRecordingsBody => '点击录音按钮开始录制。';

  @override
  String get micPermissionRequired => '录音需要麦克风权限。';

  @override
  String loadFailed(String error) {
    return '加载失败：$error';
  }

  @override
  String get transcribe => '转写文字';

  @override
  String get deleteRecordingTitle => '删除这段录音？';

  @override
  String get deleteRecordingBody => '此操作无法撤销。';

  @override
  String get delete => '删除';

  @override
  String get cancel => '取消';

  @override
  String get retry => '重试';

  @override
  String get downloadModelTitle => '下载语音模型';

  @override
  String downloadModelBody(String size) {
    return '转写完全离线运行。语音模型（$size）只需下载一次，之后保存在本机。';
  }

  @override
  String get download => '下载';

  @override
  String get downloadFailed => '下载失败。请检查网络连接后重试。';

  @override
  String get settings => '设置';

  @override
  String get settingsLanguage => '语言';

  @override
  String get settingsLanguageSubtitle => '应用界面使用的语言';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsStorage => '存储空间';

  @override
  String get settingsMaxStorage => '最大存储空间';

  @override
  String get settingsMaxStorageSubtitle => '当录音总大小达到此上限时，录音会自动停止。';

  @override
  String settingsStorageUsed(String used, String total) {
    return '已使用 $used／共 $total';
  }

  @override
  String get settingsRecording => '录音';

  @override
  String get settingsAutosaveInterval => '自动保存间隔';

  @override
  String get settingsAutosaveIntervalSubtitle =>
      '正在录制的音频写入磁盘的频率。即使应用崩溃，最多也只会丢失这段时长的录音。';

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
    return '录音已停止，因为录音总大小达到了 $limit 的上限。请删除部分录音，或在设置中调高上限。';
  }

  @override
  String get recoveredRecordingBody => '已恢复一段中断的录音。';

  @override
  String get stop => '停止';

  @override
  String get notificationRecording => '正在录音';

  @override
  String get noSpeechDetected => '这段录音中没有检测到语音。';

  @override
  String get modelNotReady => '语音模型尚未准备好。';

  @override
  String get transcriptionFailed => '转写失败。';

  @override
  String transcribingPercent(int percent) {
    return '正在转写… $percent%';
  }

  @override
  String get playbackFailed => '无法播放这段录音。';

  @override
  String get settingsTranscription => '转写';

  @override
  String get settingsTranscriptionLanguage => '说话语言';

  @override
  String get settingsTranscriptionLanguageSubtitle =>
      '自动识别会逐句判断语言，因此对话中途切换语言也能正确转写。如果录音始终是同一种语言，可以直接指定。';

  @override
  String get sttAuto => '自动识别';

  @override
  String get sttMandarin => '普通话';

  @override
  String get sttCantonese => '粤语';

  @override
  String get sttEnglish => '英语';

  @override
  String get sttJapanese => '日语';

  @override
  String get sttKorean => '韩语';

  @override
  String detectedLanguages(String languages) {
    return '识别到：$languages';
  }

  @override
  String get rename => '重命名';

  @override
  String get renameTitle => '重命名录音';

  @override
  String get renameHint => '名称';

  @override
  String get renameEmpty => '请输入名称。';

  @override
  String get renameExists => '已存在同名的录音。';

  @override
  String get renameFailed => '无法重命名该录音。';

  @override
  String get save => '保存';

  @override
  String get copyTranscript => '复制转写文字';

  @override
  String get copied => '已复制转写文字。';

  @override
  String get share => '分享';

  @override
  String get shareAudio => '分享音频';

  @override
  String get shareTranscript => '分享转写文字';

  @override
  String get shareFailed => '无法分享这段录音。';

  @override
  String get pause => '暂停';

  @override
  String get resume => '继续';

  @override
  String get paused => '已暂停';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageKorean => '한국어';

  @override
  String get searchHint => '搜索录音和转写文字';

  @override
  String searchNoResults(String query) {
    return '没有匹配“$query”的结果。';
  }

  @override
  String get searchNoResultsHint => '只有已转写的录音才能按说话内容搜索。';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 条结果',
    );
    return '$_temp0';
  }

  @override
  String get searchMatchedName => '匹配到名称';

  @override
  String get clear => '清除';

  @override
  String get translate => '翻译';

  @override
  String get translateTo => '翻译成';

  @override
  String get translating => '正在翻译…';

  @override
  String get translationFailed => '翻译失败。';

  @override
  String get translationUnsupported => '此设备无法翻译该语言组合。';

  @override
  String get translationCantonese => '粤语翻译需要在线翻译服务，目前尚未提供。';

  @override
  String translationOf(String language) {
    return '译文（$language）';
  }

  @override
  String get translationSourceUnknown => '翻译需要单一的识别语言，这段录音没有识别到语言或包含多种语言。';

  @override
  String get langEnglish => '英语';

  @override
  String get langChineseSimplified => '简体中文';

  @override
  String get langChineseTraditional => '繁体中文';

  @override
  String get langJapanese => '日语';

  @override
  String get langKorean => '韩语';

  @override
  String get langCantonese => '粤语';

  @override
  String get liveHold => '按住实时转写';

  @override
  String get liveListening => '正在聆听…';

  @override
  String get liveStarting => '正在启动…';

  @override
  String get liveEmpty => '按住按钮说话，每说完一句就会显示文字。';

  @override
  String get liveUnavailable => '请先下载语音模型才能使用实时转写。';

  @override
  String get liveBusy => '请先完成正在进行的转写。';

  @override
  String get liveTranslateOff => '不翻译';
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'Momera.Audio';

  @override
  String get tapToRecord => '點擊錄音';

  @override
  String get noRecordingsTitle => '還沒有錄音';

  @override
  String get noRecordingsBody => '點擊錄音按鈕開始錄製。';

  @override
  String get micPermissionRequired => '錄音需要麥克風權限。';

  @override
  String loadFailed(String error) {
    return '載入失敗：$error';
  }

  @override
  String get transcribe => '轉寫文字';

  @override
  String get deleteRecordingTitle => '刪除這段錄音？';

  @override
  String get deleteRecordingBody => '此操作無法復原。';

  @override
  String get delete => '刪除';

  @override
  String get cancel => '取消';

  @override
  String get retry => '重試';

  @override
  String get downloadModelTitle => '下載語音模型';

  @override
  String downloadModelBody(String size) {
    return '轉寫完全離線運作。語音模型（$size）只需下載一次，之後保存在本機。';
  }

  @override
  String get download => '下載';

  @override
  String get downloadFailed => '下載失敗。請檢查網路連線後重試。';

  @override
  String get settings => '設定';

  @override
  String get settingsLanguage => '語言';

  @override
  String get settingsLanguageSubtitle => '應用程式介面使用的語言';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsStorage => '儲存空間';

  @override
  String get settingsMaxStorage => '最大儲存空間';

  @override
  String get settingsMaxStorageSubtitle => '當錄音總大小達到此上限時，錄音會自動停止。';

  @override
  String settingsStorageUsed(String used, String total) {
    return '已使用 $used／共 $total';
  }

  @override
  String get settingsRecording => '錄音';

  @override
  String get settingsAutosaveInterval => '自動儲存間隔';

  @override
  String get settingsAutosaveIntervalSubtitle =>
      '正在錄製的音訊寫入磁碟的頻率。即使應用程式當機，最多也只會遺失這段時長的錄音。';

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
    return '錄音已停止，因為錄音總大小達到了 $limit 的上限。請刪除部分錄音，或在設定中調高上限。';
  }

  @override
  String get recoveredRecordingBody => '已復原一段中斷的錄音。';

  @override
  String get stop => '停止';

  @override
  String get notificationRecording => '正在錄音';

  @override
  String get noSpeechDetected => '這段錄音中沒有偵測到語音。';

  @override
  String get modelNotReady => '語音模型尚未準備好。';

  @override
  String get transcriptionFailed => '轉寫失敗。';

  @override
  String transcribingPercent(int percent) {
    return '正在轉寫… $percent%';
  }

  @override
  String get playbackFailed => '無法播放這段錄音。';

  @override
  String get settingsTranscription => '轉寫';

  @override
  String get settingsTranscriptionLanguage => '說話語言';

  @override
  String get settingsTranscriptionLanguageSubtitle =>
      '自動辨識會逐句判斷語言，因此對話中途切換語言也能正確轉寫。如果錄音始終是同一種語言，可以直接指定。';

  @override
  String get sttAuto => '自動辨識';

  @override
  String get sttMandarin => '普通話';

  @override
  String get sttCantonese => '粵語';

  @override
  String get sttEnglish => '英語';

  @override
  String get sttJapanese => '日語';

  @override
  String get sttKorean => '韓語';

  @override
  String detectedLanguages(String languages) {
    return '辨識到：$languages';
  }

  @override
  String get rename => '重新命名';

  @override
  String get renameTitle => '重新命名錄音';

  @override
  String get renameHint => '名稱';

  @override
  String get renameEmpty => '請輸入名稱。';

  @override
  String get renameExists => '已存在同名的錄音。';

  @override
  String get renameFailed => '無法重新命名這段錄音。';

  @override
  String get save => '儲存';

  @override
  String get copyTranscript => '複製轉寫文字';

  @override
  String get copied => '已複製轉寫文字。';

  @override
  String get share => '分享';

  @override
  String get shareAudio => '分享音訊';

  @override
  String get shareTranscript => '分享轉寫文字';

  @override
  String get shareFailed => '無法分享這段錄音。';

  @override
  String get pause => '暫停';

  @override
  String get resume => '繼續';

  @override
  String get paused => '已暫停';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageKorean => '한국어';

  @override
  String get searchHint => '搜尋錄音和轉寫文字';

  @override
  String searchNoResults(String query) {
    return '沒有符合「$query」的結果。';
  }

  @override
  String get searchNoResultsHint => '只有已轉寫的錄音才能依說話內容搜尋。';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 筆結果',
    );
    return '$_temp0';
  }

  @override
  String get searchMatchedName => '符合名稱';

  @override
  String get clear => '清除';

  @override
  String get translate => '翻譯';

  @override
  String get translateTo => '翻譯成';

  @override
  String get translating => '正在翻譯…';

  @override
  String get translationFailed => '翻譯失敗。';

  @override
  String get translationUnsupported => '此裝置無法翻譯該語言組合。';

  @override
  String get translationCantonese => '粵語翻譯需要線上翻譯服務，目前尚未提供。';

  @override
  String translationOf(String language) {
    return '譯文（$language）';
  }

  @override
  String get translationSourceUnknown => '翻譯需要單一的辨識語言，這段錄音沒有辨識到語言或包含多種語言。';

  @override
  String get langEnglish => '英語';

  @override
  String get langChineseSimplified => '簡體中文';

  @override
  String get langChineseTraditional => '繁體中文';

  @override
  String get langJapanese => '日語';

  @override
  String get langKorean => '韓語';

  @override
  String get langCantonese => '粵語';

  @override
  String get liveHold => '按住即時轉寫';

  @override
  String get liveListening => '正在聆聽…';

  @override
  String get liveStarting => '正在啟動…';

  @override
  String get liveEmpty => '按住按鈕說話，每說完一句就會顯示文字。';

  @override
  String get liveUnavailable => '請先下載語音模型才能使用即時轉寫。';

  @override
  String get liveBusy => '請先完成正在進行的轉寫。';

  @override
  String get liveTranslateOff => '不翻譯';
}
