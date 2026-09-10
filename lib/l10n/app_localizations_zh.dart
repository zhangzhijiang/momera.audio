// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'Momera Recorder';

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
  String get settingsInfo => '关于此设置';

  @override
  String get languageSystem => '跟随系统';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsMaxStorage => '最大存储空间';

  @override
  String get settingsMaxStorageSubtitle =>
      '当录音总量达到该大小时，录音会自动停止。这里显示的时间是音频长度——开启“跳过静音”后，实际录制时长可以更久。';

  @override
  String settingsStorageUsed(String used, String total) {
    return '已使用 $used／共 $total';
  }

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
  String get fileSizeLimitBody =>
      '录音已停止，因为本次录音已达到单个音频文件所能容纳的最大长度。录音已保存，可开始新的录音继续。';

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
  String get transcriptLabel => '转写文字';

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
  String get searchHintNamesOnly => '搜索录音';

  @override
  String get searchNoResultsHintNamesOnly => '搜索会匹配录音名称。';

  @override
  String get transcriptionLoadFailed => '此设备无法加载语音模型。';

  @override
  String get searchMatchedName => '匹配到名称';

  @override
  String get clear => '清除';

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
  String notEnoughSpaceBody(String needed, String available) {
    return '请释放 $needed 以下载语音模型。当前可用 $available。';
  }

  @override
  String get waveformSeek => '在此录音中跳转';

  @override
  String get removeTranscript => '删除转写文字';

  @override
  String get removeTranscriptTitle => '删除这份转写文字？';

  @override
  String get removeTranscriptBody => '转写文字将被删除。你随时可以重新转写这段录音。';

  @override
  String get transcriptRemoved => '转写文字已删除。';

  @override
  String get livePanelHidden => '已隐藏实时文字。长按字幕按钮可重新显示。';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get history => '历史记录';

  @override
  String get settingsHistorySubtitle => '你录制的全部录音，最新的在前。主页只保留今天的录音，其余都在这里。';

  @override
  String historyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 段录音',
      zero: '暂无录音',
    );
    return '$_temp0';
  }

  @override
  String get noRecordingsTodayTitle => '今天还没有录音';

  @override
  String get noRecordingsTodayBody => '点按录音按钮开始录制。更早的录音在“历史记录”中。';

  @override
  String get openHistory => '打开历史记录';

  @override
  String get searchNoResultsHintToday => '这里只搜索今天的录音。要搜索全部，请前往“历史记录”。';

  @override
  String get playbackBlockedWhileRecording => '请先停止录音，再播放其他录音。';

  @override
  String get hideLiveText => '隐藏实时文字';

  @override
  String get skipSilence => '跳过静音';

  @override
  String get skipSilenceOnTitle => '已跳过静音';

  @override
  String get skipSilenceOnBody => '只录制语音。';

  @override
  String get skipSilenceOffTitle => '完整录制';

  @override
  String get skipSilenceOffBody => '静音也会被录制。';

  @override
  String get skipSilenceUnavailable => '此设备不支持跳过静音。';

  @override
  String get settingsTheme => '主题';

  @override
  String get settingsThemeSubtitle =>
      '浅色或深色。默认跟随设备设置；也可以手动指定——在光线昏暗的环境中用浅色设备录音时会很有用。';

  @override
  String get themeSystem => '跟随设备';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get noRecordingsOnDay => '这一天没有录音。';

  @override
  String get noRecordingsOnDayHint => '再次点按高亮的日期即可查看全部录音。';

  @override
  String get recordingReconnecting => '已失去麦克风，正在重新连接…';

  @override
  String get recordingResumed => '已恢复录音。';

  @override
  String get recordingInterruptedBody => '录音已停止：麦克风持续不可用。此前录到的内容都已保存。';

  @override
  String get recordingWriteFailedBody => '录音已停止：音频无法保存到此设备。到此为止录制的内容已保留。';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours 小时 $minutes 分钟';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分钟',
      zero: '不到一分钟',
    );
    return '$_temp0';
  }

  @override
  String settingsStorageDurations(String recorded, String remaining) {
    return '已录制 $recorded · 大约还能录 $remaining';
  }
}

/// The translations for Chinese, using the Han script (`zh_Hant`).
class AppLocalizationsZhHant extends AppLocalizationsZh {
  AppLocalizationsZhHant() : super('zh_Hant');

  @override
  String get appTitle => 'Momera Recorder';

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
  String get settingsInfo => '關於此設定';

  @override
  String get languageSystem => '跟隨系統';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsMaxStorage => '最大儲存空間';

  @override
  String get settingsMaxStorageSubtitle =>
      '當錄音總量達到該大小時，錄音會自動停止。這裡顯示的時間是音訊長度——開啟「略過靜音」後，實際錄製時長可以更久。';

  @override
  String settingsStorageUsed(String used, String total) {
    return '已使用 $used／共 $total';
  }

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
  String get fileSizeLimitBody =>
      '錄音已停止，因為本次錄音已達到單一音訊檔案所能容納的最大長度。錄音已儲存，可開始新的錄音繼續。';

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
  String get transcriptLabel => '轉寫文字';

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
  String get searchHintNamesOnly => '搜尋錄音';

  @override
  String get searchNoResultsHintNamesOnly => '搜尋會比對錄音名稱。';

  @override
  String get transcriptionLoadFailed => '此裝置無法載入語音模型。';

  @override
  String get searchMatchedName => '符合名稱';

  @override
  String get clear => '清除';

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
  String notEnoughSpaceBody(String needed, String available) {
    return '請釋放 $needed 以下載語音模型。目前可用 $available。';
  }

  @override
  String get waveformSeek => '在此錄音中跳轉';

  @override
  String get removeTranscript => '刪除轉寫文字';

  @override
  String get removeTranscriptTitle => '刪除這份轉寫文字？';

  @override
  String get removeTranscriptBody => '轉寫文字將被刪除。你隨時可以重新轉寫這段錄音。';

  @override
  String get transcriptRemoved => '轉寫文字已刪除。';

  @override
  String get livePanelHidden => '已隱藏即時文字。長按字幕按鈕可重新顯示。';

  @override
  String get today => '今天';

  @override
  String get yesterday => '昨天';

  @override
  String get history => '歷史記錄';

  @override
  String get settingsHistorySubtitle => '你錄製的全部錄音，最新的在前。主畫面只保留今天的錄音，其餘都在這裡。';

  @override
  String historyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 段錄音',
      zero: '尚無錄音',
    );
    return '$_temp0';
  }

  @override
  String get noRecordingsTodayTitle => '今天還沒有錄音';

  @override
  String get noRecordingsTodayBody => '點按錄音按鈕開始錄製。更早的錄音在「歷史記錄」中。';

  @override
  String get openHistory => '開啟歷史記錄';

  @override
  String get searchNoResultsHintToday => '這裡只搜尋今天的錄音。要搜尋全部，請前往「歷史記錄」。';

  @override
  String get playbackBlockedWhileRecording => '請先停止錄音，再播放其他錄音。';

  @override
  String get hideLiveText => '隱藏即時文字';

  @override
  String get skipSilence => '略過靜音';

  @override
  String get skipSilenceOnTitle => '已略過靜音';

  @override
  String get skipSilenceOnBody => '只錄製語音。';

  @override
  String get skipSilenceOffTitle => '完整錄製';

  @override
  String get skipSilenceOffBody => '靜音也會被錄製。';

  @override
  String get skipSilenceUnavailable => '此裝置不支援略過靜音。';

  @override
  String get settingsTheme => '主題';

  @override
  String get settingsThemeSubtitle =>
      '淺色或深色。預設跟隨裝置設定；也可以手動指定——在光線昏暗的環境中用淺色裝置錄音時會很有用。';

  @override
  String get themeSystem => '跟隨裝置';

  @override
  String get themeLight => '淺色';

  @override
  String get themeDark => '深色';

  @override
  String get noRecordingsOnDay => '這一天沒有錄音。';

  @override
  String get noRecordingsOnDayHint => '再次點按醒目顯示的日期即可查看全部錄音。';

  @override
  String get recordingReconnecting => '已失去麥克風，正在重新連線…';

  @override
  String get recordingResumed => '已恢復錄音。';

  @override
  String get recordingInterruptedBody => '錄音已停止：麥克風持續無法使用。此前錄到的內容都已儲存。';

  @override
  String get recordingWriteFailedBody => '錄音已停止：音訊無法儲存到此裝置。到此為止錄製的內容已保留。';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours 小時 $minutes 分鐘';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count 分鐘',
      zero: '不到一分鐘',
    );
    return '$_temp0';
  }

  @override
  String settingsStorageDurations(String recorded, String remaining) {
    return '已錄製 $recorded · 大約還能錄 $remaining';
  }
}
