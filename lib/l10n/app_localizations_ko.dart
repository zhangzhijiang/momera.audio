// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Korean (`ko`).
class AppLocalizationsKo extends AppLocalizations {
  AppLocalizationsKo([String locale = 'ko']) : super(locale);

  @override
  String get appTitle => 'Momera Recorder';

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
  String get languageSystem => '시스템 기본값';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsStorage => '저장 공간';

  @override
  String get settingsMaxStorage => '최대 저장 공간';

  @override
  String get settingsMaxStorageSubtitle =>
      '녹음 전체 크기가 이 한도에 도달하면 녹음이 자동으로 중지됩니다.';

  @override
  String settingsStorageUsed(String used, String total) {
    return '$total 중 $used 사용 중';
  }

  @override
  String get settingsRecording => '녹음';

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
  String get settingsTranscription => '텍스트 변환';

  @override
  String get settingsTranscriptionLanguage => '말하는 언어';

  @override
  String get settingsTranscriptionLanguageSubtitle =>
      '자동 감지는 구절마다 언어를 판별하므로 대화 중 언어가 바뀌어도 정확하게 변환됩니다. 오디오가 항상 한 언어라면 직접 지정하세요.';

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
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '결과 $count개',
    );
    return '$_temp0';
  }

  @override
  String get searchMatchedName => '이름 일치';

  @override
  String get clear => '지우기';

  @override
  String get translate => '번역';

  @override
  String get translateTo => '번역할 언어';

  @override
  String get translating => '번역 중…';

  @override
  String get translationFailed => '번역에 실패했습니다.';

  @override
  String get translationUnsupported => '이 기기에서는 해당 언어 조합을 번역할 수 없습니다.';

  @override
  String get translationCantonese => '광둥어 번역에는 온라인 번역기가 필요하지만 아직 제공되지 않습니다.';

  @override
  String translationOf(String language) {
    return '번역 ($language)';
  }

  @override
  String get translationSourceUnknown =>
      '번역하려면 감지된 언어가 하나여야 합니다. 이 녹음은 언어가 없거나 여러 개입니다.';

  @override
  String get langEnglish => '영어';

  @override
  String get langChineseSimplified => '중국어(간체)';

  @override
  String get langChineseTraditional => '중국어(번체)';

  @override
  String get langJapanese => '일본어';

  @override
  String get langKorean => '한국어';

  @override
  String get langCantonese => '광둥어';

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
  String get liveTranslateOff => '번역 안 함';
}
