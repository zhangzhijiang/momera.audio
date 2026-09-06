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
  String get transcribing => 'Transcribing…';

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
  String get languageSpanish => 'Español';

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
  String get storageFullTitle => 'Storage limit reached';

  @override
  String storageFullBody(String limit) {
    return 'Recording stopped because your recordings reached the $limit limit. Delete some recordings or raise the limit in Settings.';
  }

  @override
  String get recoveredRecordingTitle => 'Recovered a recording';

  @override
  String get recoveredRecordingBody =>
      'A recording that was interrupted has been recovered.';
}
