// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'McRecorder';

  @override
  String get tapToRecord => '탭하여 녹음';

  @override
  String get noRecordingsTitle => '아직 녹음이 없습니다';

  @override
  String get noRecordingsBody => '녹음 버튼을 탭해 오디오를 기록하세요.';

  @override
  String get micPermissionRequired => '녹음하려면 마이크 권한이 필요합니다.';

  @override
  String loadFailed(String error) {
    return '불러오지 못했습니다: $error';
  }

  @override
  String get transcribe => '텍스트 변환';

  @override
  String get deleteRecordingTitle => '이 녹음을 삭제할까요?';

  @override
  String get deleteRecordingBody => '이 작업은 되돌릴 수 없습니다.';

  @override
  String get delete => '삭제';

  @override
  String get cancel => '취소';

  @override
  String get retry => '다시 시도';

  @override
  String get downloadModelTitle => '음성 모델 다운로드';

  @override
  String downloadModelBody(String size) {
    return '텍스트 변환은 완전히 오프라인으로 동작합니다. 음성 모델($size)은 한 번만 내려받아 이 기기에 저장됩니다.';
  }

  @override
  String get download => '다운로드';

  @override
  String get downloadFailed => '다운로드에 실패했습니다. 연결을 확인하고 다시 시도하세요.';

  @override
  String get settings => '설정';

  @override
  String get settingsLanguage => '언어';

  @override
  String get settingsLanguageSubtitle => '앱 전체에서 사용하는 언어';

  @override
  String get settingsInfo => '이 설정 정보';

  @override
  String get languageSystem => '시스템 기본값';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsMaxStorage => '최대 저장 공간';

  @override
  String get settingsMaxStorageSubtitle =>
      '녹음 용량이 이 크기에 이르면 녹음이 중지됩니다. 표시된 시간은 오디오 길이이며, 무음 건너뛰기를 켜면 실제 녹음 시간은 더 길어질 수 있습니다.';

  @override
  String settingsStorageUsed(String used, String total) {
    return '$total 중 $used 사용 중';
  }

  @override
  String get settingsAutosaveInterval => '자동 저장 간격';

  @override
  String get settingsAutosaveIntervalSubtitle =>
      '녹음 중인 오디오를 디스크에 기록하는 주기입니다. 앱이 중단되어도 최대 이 길이만 손실됩니다.';

  @override
  String seconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count초',
    );
    return '$_temp0';
  }

  @override
  String storageFullBody(String limit) {
    return '녹음 전체 크기가 한도($limit)에 도달하여 녹음을 중지했습니다. 녹음을 삭제하거나 설정에서 한도를 늘리세요.';
  }

  @override
  String get fileSizeLimitBody =>
      '이 녹음이 오디오 파일 하나에 담을 수 있는 최대 길이에 도달하여 녹음을 중지했습니다. 녹음은 저장되었으며, 계속하려면 새 녹음을 시작하세요.';

  @override
  String get recoveredRecordingBody => '중단된 녹음을 복구했습니다.';

  @override
  String get stop => '중지';

  @override
  String get notificationRecording => '녹음 중';

  @override
  String get noSpeechDetected => '이 녹음에서 음성을 감지하지 못했습니다.';

  @override
  String get modelNotReady => '음성 모델이 아직 준비되지 않았습니다.';

  @override
  String get transcriptionFailed => '텍스트 변환에 실패했습니다.';

  @override
  String transcribingPercent(int percent) {
    return '변환 중… $percent%';
  }

  @override
  String get playbackFailed => '이 녹음을 재생할 수 없습니다.';

  @override
  String get sttAuto => '자동 감지';

  @override
  String get sttMandarin => '중국어(표준어)';

  @override
  String get sttCantonese => '광둥어';

  @override
  String get sttEnglish => '영어';

  @override
  String get sttJapanese => '일본어';

  @override
  String get sttKorean => '한국어';

  @override
  String detectedLanguages(String languages) {
    return '감지된 언어: $languages';
  }

  @override
  String get rename => '이름 변경';

  @override
  String get renameTitle => '녹음 이름 변경';

  @override
  String get renameHint => '이름';

  @override
  String get renameEmpty => '이름을 입력하세요.';

  @override
  String get renameExists => '같은 이름의 녹음이 이미 있습니다.';

  @override
  String get renameFailed => '녹음 이름을 변경할 수 없습니다.';

  @override
  String get save => '저장';

  @override
  String get transcriptLabel => '변환된 텍스트';

  @override
  String get copyTranscript => '변환된 텍스트 복사';

  @override
  String get copied => '변환된 텍스트를 복사했습니다.';

  @override
  String get share => '공유';

  @override
  String get shareAudio => '오디오 공유';

  @override
  String get shareTranscript => '변환된 텍스트 공유';

  @override
  String get shareFailed => '이 녹음을 공유할 수 없습니다.';

  @override
  String get pause => '일시정지';

  @override
  String get resume => '계속';

  @override
  String get paused => '일시정지됨';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageKorean => '한국어';

  @override
  String get searchHint => '녹음과 텍스트 검색';

  @override
  String searchNoResults(String query) {
    return '“$query”와(과) 일치하는 항목이 없습니다.';
  }

  @override
  String get searchNoResultsHint => '말한 내용으로 검색하려면 먼저 텍스트로 변환해야 합니다.';

  @override
  String get searchHintNamesOnly => '녹음 검색';

  @override
  String get searchNoResultsHintNamesOnly => '검색은 녹음 이름과 일치합니다.';

  @override
  String get transcriptionLoadFailed => '이 기기에서는 음성 모델을 불러올 수 없습니다.';

  @override
  String get searchMatchedName => '이름 일치';

  @override
  String get clear => '지우기';

  @override
  String get liveHold => '길게 눌러 실시간 표시';

  @override
  String get liveListening => '듣는 중…';

  @override
  String get liveStarting => '시작하는 중…';

  @override
  String get liveEmpty => '버튼을 길게 누르고 말하세요. 한 문장이 끝날 때마다 텍스트가 표시됩니다.';

  @override
  String get liveUnavailable => '실시간 표시를 사용하려면 먼저 음성 모델을 다운로드하세요.';

  @override
  String get liveBusy => '진행 중인 텍스트 변환을 먼저 끝내세요.';

  @override
  String notEnoughSpaceBody(String needed, String available) {
    return '음성 모델을 다운로드하려면 $needed를 확보해야 합니다. 현재 $available 사용 가능합니다.';
  }

  @override
  String get waveformSeek => '이 녹음에서 이동';

  @override
  String get removeTranscript => '텍스트 삭제';

  @override
  String get removeTranscriptTitle => '이 텍스트를 삭제할까요?';

  @override
  String get removeTranscriptBody =>
      '텍스트가 삭제됩니다. 이 녹음은 언제든 다시 텍스트로 변환할 수 있습니다.';

  @override
  String get transcriptRemoved => '텍스트를 삭제했습니다.';

  @override
  String get livePanelHidden => '실시간 텍스트를 숨겼습니다. 자막 버튼을 길게 눌러 다시 표시하세요.';

  @override
  String get today => '오늘';

  @override
  String get yesterday => '어제';

  @override
  String get history => '기록';

  @override
  String get settingsHistorySubtitle =>
      '지금까지 녹음한 모든 파일이 최신순으로 표시됩니다. 홈 화면에는 오늘 녹음만 남고 나머지는 여기에 있습니다.';

  @override
  String historyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '녹음 $count개',
      zero: '녹음 없음',
    );
    return '$_temp0';
  }

  @override
  String get noRecordingsTodayTitle => '오늘 녹음한 파일이 없습니다';

  @override
  String get noRecordingsTodayBody => '녹음 버튼을 눌러 시작하세요. 이전 녹음은 기록에 있습니다.';

  @override
  String get openHistory => '기록 열기';

  @override
  String get searchNoResultsHintToday =>
      '여기서는 오늘 녹음만 검색합니다. 전체를 검색하려면 기록을 사용하세요.';

  @override
  String get playbackBlockedWhileRecording => '녹음을 중지한 후 다른 녹음을 재생하세요.';

  @override
  String get hideLiveText => '실시간 텍스트 숨기기';

  @override
  String get skipSilence => '무음 건너뛰기';

  @override
  String get skipSilenceOnTitle => '무음을 건너뜁니다';

  @override
  String get skipSilenceOnBody => '음성만 녹음합니다.';

  @override
  String get skipSilenceOffTitle => '전체 녹음';

  @override
  String get skipSilenceOffBody => '무음도 함께 녹음합니다.';

  @override
  String get skipSilenceUnavailable => '이 기기에서는 무음 건너뛰기를 사용할 수 없습니다.';

  @override
  String get settingsTheme => '테마';

  @override
  String get settingsThemeSubtitle =>
      '밝게 또는 어둡게. 기본값은 기기 설정을 따르며, 직접 고를 수도 있습니다. 어두운 방에서 밝게 설정된 기기로 녹음할 때 유용합니다.';

  @override
  String get themeSystem => '기기 설정 따르기';

  @override
  String get themeLight => '밝게';

  @override
  String get themeDark => '어둡게';

  @override
  String get noRecordingsOnDay => '이 날짜에는 녹음이 없습니다.';

  @override
  String get noRecordingsOnDayHint => '강조된 날짜를 다시 누르면 전체 기록이 표시됩니다.';

  @override
  String get recordingReconnecting => '마이크 연결이 끊겼습니다. 다시 연결하는 중…';

  @override
  String get recordingResumed => '다시 녹음합니다.';

  @override
  String get recordingInterruptedBody =>
      '녹음을 중지했습니다. 마이크를 계속 사용할 수 없었습니다. 그때까지 녹음한 내용은 모두 저장되었습니다.';

  @override
  String get recordingWriteFailedBody =>
      '녹음이 중지되었습니다: 오디오를 이 기기에 저장할 수 없습니다. 그때까지 녹음된 내용은 저장되었습니다.';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours시간 $minutes분';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count분',
      zero: '1분 미만',
    );
    return '$_temp0';
  }

  @override
  String settingsStorageDurations(String recorded, String remaining) {
    return '$recorded 녹음함 · 약 $remaining 더 녹음 가능';
  }
}
