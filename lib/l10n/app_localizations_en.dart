// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'McRecorder';

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
  String get settingsInfo => 'About this setting';

  @override
  String get languageSystem => 'System default';

  @override
  String get languageEnglish => 'English';

  @override
  String get languageChineseSimplified => '简体中文';

  @override
  String get languageChineseTraditional => '繁體中文';

  @override
  String get settingsMaxStorage => 'Maximum storage';

  @override
  String get settingsMaxStorageSubtitle =>
      'Recording stops when your recordings reach this size. The times shown are lengths of audio — with Skip silence on, a session can run for longer than that.';

  @override
  String settingsStorageUsed(String used, String total) {
    return '$used of $total used';
  }

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
  String get fileSizeLimitBody =>
      'Recording stopped because this recording reached the longest a single audio file can hold. It has been saved — start a new recording to keep going.';

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
  String get transcriptLabel => 'Transcript';

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
  String get searchHintNamesOnly => 'Search recordings';

  @override
  String get searchNoResultsHintNamesOnly => 'Search matches recording names.';

  @override
  String get transcriptionLoadFailed =>
      'The voice model could not be loaded on this device.';

  @override
  String get searchMatchedName => 'Matched the name';

  @override
  String get clear => 'Clear';

  @override
  String get liveHold => 'Hold for live text';

  @override
  String get liveListening => 'Listening…';

  @override
  String get liveStarting => 'Starting…';

  @override
  String get liveEmpty =>
      'Hold the button and speak — text appears as you finish each phrase.';

  @override
  String get liveUnavailable =>
      'Download the voice model first to use live text.';

  @override
  String get liveBusy => 'Finish the transcription in progress first.';

  @override
  String notEnoughSpaceBody(String needed, String available) {
    return 'Free up $needed to download the voice model. $available is free right now.';
  }

  @override
  String get waveformSeek => 'Seek in this recording';

  @override
  String get removeTranscript => 'Remove transcript';

  @override
  String get removeTranscriptTitle => 'Remove this transcript?';

  @override
  String get removeTranscriptBody =>
      'The transcript will be deleted. You can transcribe this recording again at any time.';

  @override
  String get transcriptRemoved => 'Transcript removed.';

  @override
  String get livePanelHidden =>
      'Live text hidden. Hold the subtitles button to show it again.';

  @override
  String get today => 'Today';

  @override
  String get yesterday => 'Yesterday';

  @override
  String get history => 'History';

  @override
  String get settingsHistorySubtitle =>
      'Every recording you have made, newest first. The home screen keeps only today\'s; everything else is here.';

  @override
  String historyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recordings',
      one: '1 recording',
      zero: 'No recordings',
    );
    return '$_temp0';
  }

  @override
  String get noRecordingsTodayTitle => 'Nothing recorded today';

  @override
  String get noRecordingsTodayBody =>
      'Tap the record button to start. Earlier recordings are in History.';

  @override
  String get openHistory => 'Open History';

  @override
  String get searchNoResultsHintToday =>
      'Only today\'s recordings are searched here. Use History to search everything.';

  @override
  String get playbackBlockedWhileRecording =>
      'Stop the recording before playing another one.';

  @override
  String get hideLiveText => 'Hide live text';

  @override
  String get skipSilence => 'Skip silence';

  @override
  String get skipSilenceOnTitle => 'Skipping silence';

  @override
  String get skipSilenceOnBody => 'Only speech is recorded.';

  @override
  String get skipSilenceOffTitle => 'Recording everything';

  @override
  String get skipSilenceOffBody => 'Silence is recorded too.';

  @override
  String get skipSilenceUnavailable =>
      'Skipping silence is not available on this device.';

  @override
  String get settingsTheme => 'Theme';

  @override
  String get settingsThemeSubtitle =>
      'Light or dark. Following the device is the default; choose one to override it — useful when recording in a dark room with a device set to light.';

  @override
  String get themeSystem => 'Follow the device';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get noRecordingsOnDay => 'Nothing recorded on this day.';

  @override
  String get noRecordingsOnDayHint =>
      'Tap the highlighted day again to see the whole archive.';

  @override
  String get recordingReconnecting => 'Lost the microphone. Reconnecting…';

  @override
  String get recordingResumed => 'Recording again.';

  @override
  String get recordingInterruptedBody =>
      'Recording stopped: the microphone stayed unavailable. Everything captured up to that point has been saved.';

  @override
  String get recordingWriteFailedBody =>
      'Recording stopped: the audio could not be saved to this device. Everything recorded up to that point has been kept.';

  @override
  String durationHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String durationMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count min',
      one: '1 min',
      zero: 'under a minute',
    );
    return '$_temp0';
  }

  @override
  String settingsStorageDurations(String recorded, String remaining) {
    return '$recorded recorded · about $remaining still fits';
  }
}
