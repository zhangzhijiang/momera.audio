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
  String get transcribing => '正在转写…';

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
  String get languageSpanish => 'Español';

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
  String get storageFullTitle => '已达到存储上限';

  @override
  String storageFullBody(String limit) {
    return '录音已停止，因为录音总大小达到了 $limit 的上限。请删除部分录音，或在设置中调高上限。';
  }

  @override
  String get recoveredRecordingTitle => '已恢复录音';

  @override
  String get recoveredRecordingBody => '已恢复一段中断的录音。';
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
  String get transcribing => '正在轉寫…';

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
  String get languageSpanish => 'Español';

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
  String get storageFullTitle => '已達到儲存上限';

  @override
  String storageFullBody(String limit) {
    return '錄音已停止，因為錄音總大小達到了 $limit 的上限。請刪除部分錄音，或在設定中調高上限。';
  }

  @override
  String get recoveredRecordingTitle => '已復原錄音';

  @override
  String get recoveredRecordingBody => '已復原一段中斷的錄音。';
}
