// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Momera.Audio';

  @override
  String get tapToRecord => 'Tap to record';

  @override
  String get noRecordingsTitle => 'No recordings yet';

  @override
  String get noRecordingsBody => 'Tap the record button to capture audio.';

  @override
  String get micPermissionRequired =>
      'Microphone permission is required to record.';

  @override
  String loadFailed(String error) {
    return 'Failed to load: $error';
  }

  @override
  String get transcribe => 'Transcribe';

  @override
  String get deleteRecordingTitle => 'Delete recording?';

  @override
  String get deleteRecordingBody => 'This cannot be undone.';

  @override
  String get delete => 'Delete';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get downloadModelTitle => 'Download voice model';

  @override
  String downloadModelBody(String size) {
    return 'Transcription runs fully offline. The speech model ($size) is downloaded once and kept on this device.';
  }

  @override
  String get download => 'Download';

  @override
  String get downloadFailed =>
      'Download failed. Check your connection and try again.';

  @override
  String get settings => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get settingsLanguageSubtitle => 'Language used throughout the app';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsStorage => 'Storage';

  @override
  String get settingsMaxStorage => 'Maximum storage';

  @override
  String get settingsMaxStorageSubtitle =>
      'Recording stops when your recordings reach this size.';

  @override
  String settingsStorageUsed(String used, String total) {
    return '$used of $total used';
  }

  @override
  String get settingsRecording => 'Recording';

  @override
  String get settingsAutosaveInterval => 'Auto-save interval';

  @override
  String get settingsAutosaveIntervalSubtitle =>
      'How often the recording in progress is written to disk. A crash loses at most this much audio.';

  @override
  String seconds(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String storageFullBody(String limit) {
    return 'Recording stopped because your recordings reached the $limit limit. Delete some recordings or raise the limit in Settings.';
  }

  @override
  String get recoveredRecordingBody =>
      'A recording that was interrupted has been recovered.';

  @override
  String get stop => 'Stop';

  @override
  String get notificationRecording => 'Recording in progress';

  @override
  String get noSpeechDetected => 'No speech detected in this recording.';

  @override
  String get modelNotReady => 'Voice model is not ready yet.';

  @override
  String get transcriptionFailed => 'Transcription failed.';

  @override
  String transcribingPercent(int percent) {
    return 'Transcribing… $percent%';
  }

  @override
  String get playbackFailed => 'Could not play this recording.';

  @override
  String get settingsTranscription => 'Transcription';

  @override
  String get settingsTranscriptionLanguage => 'Spoken language';

  @override
  String get settingsTranscriptionLanguageSubtitle =>
      'Automatic detects the language of each phrase, so a conversation that switches language still transcribes correctly. Choose a language if the audio is always in one.';

  @override
  String get sttAuto => 'Automatic';

  @override
  String get sttMandarin => 'Mandarin Chinese';

  @override
  String get sttCantonese => 'Cantonese';

  @override
  String get sttEnglish => 'English';

  @override
  String get sttJapanese => 'Japanese';

  @override
  String get sttKorean => 'Korean';

  @override
  String detectedLanguages(String languages) {
    return 'Detected: $languages';
  }

  @override
  String get rename => 'Rename';

  @override
  String get renameTitle => 'Rename recording';

  @override
  String get renameHint => 'Name';

  @override
  String get renameEmpty => 'Enter a name.';

  @override
  String get renameExists => 'A recording with that name already exists.';

  @override
  String get renameFailed => 'Could not rename the recording.';

  @override
  String get save => 'Save';

  @override
  String get copyTranscript => 'Copy transcript';

  @override
  String get copied => 'Transcript copied.';

  @override
  String get share => 'Share';

  @override
  String get shareAudio => 'Share audio';

  @override
  String get shareTranscript => 'Share transcript';

  @override
  String get shareFailed => 'Could not share this recording.';

  @override
  String get pause => 'Pause';

  @override
  String get resume => 'Resume';

  @override
  String get paused => 'Paused';

  @override
  String get languageJapanese => '日本語';

  @override
  String get languageKorean => '한국어';

  @override
  String get searchHint => 'Search recordings and transcripts';

  @override
  String searchNoResults(String query) {
    return 'Nothing matches “$query”.';
  }

  @override
  String get searchNoResultsHint =>
      'Only recordings you have transcribed can be searched by what was said.';

  @override
  String searchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get searchMatchedName => 'Matched the name';

  @override
  String get clear => 'Clear';

  @override
  String get translate => 'Translate';

  @override
  String get translateTo => 'Translate to';

  @override
  String get translating => 'Translating…';

  @override
  String get translationFailed => 'Translation failed.';

  @override
  String get translationUnsupported =>
      'This language pair cannot be translated on this device.';

  @override
  String get translationCantonese =>
      'Cantonese translation needs an online translator, which is not available yet.';

  @override
  String translationOf(String language) {
    return 'Translation ($language)';
  }

  @override
  String get translationSourceUnknown =>
      'Translate needs a single detected language. This recording has none or several.';

  @override
  String get langEnglish => 'English';

  @override
  String get langChineseSimplified => 'Chinese (Simplified)';

  @override
  String get langChineseTraditional => 'Chinese (Traditional)';

  @override
  String get langJapanese => 'Japanese';

  @override
  String get langKorean => 'Korean';

  @override
  String get langCantonese => 'Cantonese';
}
