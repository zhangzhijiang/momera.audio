import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_ja.dart';
import 'app_localizations_ko.dart';
import 'app_localizations_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('ja'),
    Locale('ko'),
    Locale('zh'),
    Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
  ];

  /// Application name, shown in the app bar
  ///
  /// In en, this message translates to:
  /// **'Momera Recorder'**
  String get appTitle;

  /// No description provided for @tapToRecord.
  ///
  /// In en, this message translates to:
  /// **'Tap to record'**
  String get tapToRecord;

  /// No description provided for @noRecordingsTitle.
  ///
  /// In en, this message translates to:
  /// **'No recordings yet'**
  String get noRecordingsTitle;

  /// No description provided for @noRecordingsBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the record button to capture audio.'**
  String get noRecordingsBody;

  /// No description provided for @micPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Microphone permission is required to record.'**
  String get micPermissionRequired;

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load: {error}'**
  String loadFailed(String error);

  /// No description provided for @transcribe.
  ///
  /// In en, this message translates to:
  /// **'Transcribe'**
  String get transcribe;

  /// No description provided for @deleteRecordingTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete recording?'**
  String get deleteRecordingTitle;

  /// No description provided for @deleteRecordingBody.
  ///
  /// In en, this message translates to:
  /// **'This cannot be undone.'**
  String get deleteRecordingBody;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @downloadModelTitle.
  ///
  /// In en, this message translates to:
  /// **'Download voice model'**
  String get downloadModelTitle;

  /// No description provided for @downloadModelBody.
  ///
  /// In en, this message translates to:
  /// **'Transcription runs fully offline. The speech model ({size}) is downloaded once and kept on this device.'**
  String downloadModelBody(String size);

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @downloadFailed.
  ///
  /// In en, this message translates to:
  /// **'Download failed. Check your connection and try again.'**
  String get downloadFailed;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @settingsLanguage.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get settingsLanguage;

  /// No description provided for @settingsLanguageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Language used throughout the app'**
  String get settingsLanguageSubtitle;

  /// No description provided for @settingsInfo.
  ///
  /// In en, this message translates to:
  /// **'About this setting'**
  String get settingsInfo;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System default'**
  String get languageSystem;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languageChineseSimplified.
  ///
  /// In en, this message translates to:
  /// **'简体中文'**
  String get languageChineseSimplified;

  /// No description provided for @languageChineseTraditional.
  ///
  /// In en, this message translates to:
  /// **'繁體中文'**
  String get languageChineseTraditional;

  /// No description provided for @settingsMaxStorage.
  ///
  /// In en, this message translates to:
  /// **'Maximum storage'**
  String get settingsMaxStorage;

  /// No description provided for @settingsMaxStorageSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Recording stops when your recordings reach this size. The times shown are lengths of audio — with Skip silence on, a session can run for longer than that.'**
  String get settingsMaxStorageSubtitle;

  /// No description provided for @settingsStorageUsed.
  ///
  /// In en, this message translates to:
  /// **'{used} of {total} used'**
  String settingsStorageUsed(String used, String total);

  /// No description provided for @settingsAutosaveInterval.
  ///
  /// In en, this message translates to:
  /// **'Auto-save interval'**
  String get settingsAutosaveInterval;

  /// No description provided for @settingsAutosaveIntervalSubtitle.
  ///
  /// In en, this message translates to:
  /// **'How often the recording in progress is written to disk. A crash loses at most this much audio.'**
  String get settingsAutosaveIntervalSubtitle;

  /// No description provided for @seconds.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 second} other{{count} seconds}}'**
  String seconds(int count);

  /// No description provided for @storageFullBody.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped because your recordings reached the {limit} limit. Delete some recordings or raise the limit in Settings.'**
  String storageFullBody(String limit);

  /// No description provided for @fileSizeLimitBody.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped because this recording reached the longest a single audio file can hold. It has been saved — start a new recording to keep going.'**
  String get fileSizeLimitBody;

  /// No description provided for @recoveredRecordingBody.
  ///
  /// In en, this message translates to:
  /// **'A recording that was interrupted has been recovered.'**
  String get recoveredRecordingBody;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// Android foreground-service notification body while recording
  ///
  /// In en, this message translates to:
  /// **'Recording in progress'**
  String get notificationRecording;

  /// No description provided for @noSpeechDetected.
  ///
  /// In en, this message translates to:
  /// **'No speech detected in this recording.'**
  String get noSpeechDetected;

  /// No description provided for @modelNotReady.
  ///
  /// In en, this message translates to:
  /// **'Voice model is not ready yet.'**
  String get modelNotReady;

  /// No description provided for @transcriptionFailed.
  ///
  /// In en, this message translates to:
  /// **'Transcription failed.'**
  String get transcriptionFailed;

  /// No description provided for @transcribingPercent.
  ///
  /// In en, this message translates to:
  /// **'Transcribing… {percent}%'**
  String transcribingPercent(int percent);

  /// No description provided for @playbackFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not play this recording.'**
  String get playbackFailed;

  /// No description provided for @sttAuto.
  ///
  /// In en, this message translates to:
  /// **'Automatic'**
  String get sttAuto;

  /// No description provided for @sttMandarin.
  ///
  /// In en, this message translates to:
  /// **'Mandarin Chinese'**
  String get sttMandarin;

  /// No description provided for @sttCantonese.
  ///
  /// In en, this message translates to:
  /// **'Cantonese'**
  String get sttCantonese;

  /// No description provided for @sttEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get sttEnglish;

  /// No description provided for @sttJapanese.
  ///
  /// In en, this message translates to:
  /// **'Japanese'**
  String get sttJapanese;

  /// No description provided for @sttKorean.
  ///
  /// In en, this message translates to:
  /// **'Korean'**
  String get sttKorean;

  /// No description provided for @detectedLanguages.
  ///
  /// In en, this message translates to:
  /// **'Detected: {languages}'**
  String detectedLanguages(String languages);

  /// No description provided for @rename.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get rename;

  /// No description provided for @renameTitle.
  ///
  /// In en, this message translates to:
  /// **'Rename recording'**
  String get renameTitle;

  /// No description provided for @renameHint.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get renameHint;

  /// No description provided for @renameEmpty.
  ///
  /// In en, this message translates to:
  /// **'Enter a name.'**
  String get renameEmpty;

  /// No description provided for @renameExists.
  ///
  /// In en, this message translates to:
  /// **'A recording with that name already exists.'**
  String get renameExists;

  /// No description provided for @renameFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not rename the recording.'**
  String get renameFailed;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @transcriptLabel.
  ///
  /// In en, this message translates to:
  /// **'Transcript'**
  String get transcriptLabel;

  /// No description provided for @copyTranscript.
  ///
  /// In en, this message translates to:
  /// **'Copy transcript'**
  String get copyTranscript;

  /// No description provided for @copied.
  ///
  /// In en, this message translates to:
  /// **'Transcript copied.'**
  String get copied;

  /// No description provided for @share.
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get share;

  /// No description provided for @shareAudio.
  ///
  /// In en, this message translates to:
  /// **'Share audio'**
  String get shareAudio;

  /// No description provided for @shareTranscript.
  ///
  /// In en, this message translates to:
  /// **'Share transcript'**
  String get shareTranscript;

  /// No description provided for @shareFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not share this recording.'**
  String get shareFailed;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @languageJapanese.
  ///
  /// In en, this message translates to:
  /// **'日本語'**
  String get languageJapanese;

  /// No description provided for @languageKorean.
  ///
  /// In en, this message translates to:
  /// **'한국어'**
  String get languageKorean;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search recordings and transcripts'**
  String get searchHint;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'Nothing matches “{query}”.'**
  String searchNoResults(String query);

  /// No description provided for @searchNoResultsHint.
  ///
  /// In en, this message translates to:
  /// **'Only recordings you have transcribed can be searched by what was said.'**
  String get searchNoResultsHint;

  /// No description provided for @searchHintNamesOnly.
  ///
  /// In en, this message translates to:
  /// **'Search recordings'**
  String get searchHintNamesOnly;

  /// No description provided for @searchNoResultsHintNamesOnly.
  ///
  /// In en, this message translates to:
  /// **'Search matches recording names.'**
  String get searchNoResultsHintNamesOnly;

  /// No description provided for @transcriptionLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'The voice model could not be loaded on this device.'**
  String get transcriptionLoadFailed;

  /// No description provided for @searchMatchedName.
  ///
  /// In en, this message translates to:
  /// **'Matched the name'**
  String get searchMatchedName;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @liveHold.
  ///
  /// In en, this message translates to:
  /// **'Hold for live text'**
  String get liveHold;

  /// No description provided for @liveListening.
  ///
  /// In en, this message translates to:
  /// **'Listening…'**
  String get liveListening;

  /// No description provided for @liveStarting.
  ///
  /// In en, this message translates to:
  /// **'Starting…'**
  String get liveStarting;

  /// No description provided for @liveEmpty.
  ///
  /// In en, this message translates to:
  /// **'Hold the button and speak — text appears as you finish each phrase.'**
  String get liveEmpty;

  /// No description provided for @liveUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Download the voice model first to use live text.'**
  String get liveUnavailable;

  /// No description provided for @liveBusy.
  ///
  /// In en, this message translates to:
  /// **'Finish the transcription in progress first.'**
  String get liveBusy;

  /// No description provided for @notEnoughSpaceBody.
  ///
  /// In en, this message translates to:
  /// **'Free up {needed} to download the voice model. {available} is free right now.'**
  String notEnoughSpaceBody(String needed, String available);

  /// No description provided for @waveformSeek.
  ///
  /// In en, this message translates to:
  /// **'Seek in this recording'**
  String get waveformSeek;

  /// No description provided for @removeTranscript.
  ///
  /// In en, this message translates to:
  /// **'Remove transcript'**
  String get removeTranscript;

  /// No description provided for @removeTranscriptTitle.
  ///
  /// In en, this message translates to:
  /// **'Remove this transcript?'**
  String get removeTranscriptTitle;

  /// No description provided for @removeTranscriptBody.
  ///
  /// In en, this message translates to:
  /// **'The transcript will be deleted. You can transcribe this recording again at any time.'**
  String get removeTranscriptBody;

  /// No description provided for @transcriptRemoved.
  ///
  /// In en, this message translates to:
  /// **'Transcript removed.'**
  String get transcriptRemoved;

  /// No description provided for @livePanelHidden.
  ///
  /// In en, this message translates to:
  /// **'Live text hidden. Hold the subtitles button to show it again.'**
  String get livePanelHidden;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @settingsHistorySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every recording you have made, newest first. The home screen keeps only today\'s; everything else is here.'**
  String get settingsHistorySubtitle;

  /// No description provided for @historyCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No recordings} =1{1 recording} other{{count} recordings}}'**
  String historyCount(int count);

  /// No description provided for @noRecordingsTodayTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded today'**
  String get noRecordingsTodayTitle;

  /// No description provided for @noRecordingsTodayBody.
  ///
  /// In en, this message translates to:
  /// **'Tap the record button to start. Earlier recordings are in History.'**
  String get noRecordingsTodayBody;

  /// No description provided for @openHistory.
  ///
  /// In en, this message translates to:
  /// **'Open History'**
  String get openHistory;

  /// No description provided for @searchNoResultsHintToday.
  ///
  /// In en, this message translates to:
  /// **'Only today\'s recordings are searched here. Use History to search everything.'**
  String get searchNoResultsHintToday;

  /// No description provided for @playbackBlockedWhileRecording.
  ///
  /// In en, this message translates to:
  /// **'Stop the recording before playing another one.'**
  String get playbackBlockedWhileRecording;

  /// No description provided for @hideLiveText.
  ///
  /// In en, this message translates to:
  /// **'Hide live text'**
  String get hideLiveText;

  /// No description provided for @skipSilence.
  ///
  /// In en, this message translates to:
  /// **'Skip silence'**
  String get skipSilence;

  /// No description provided for @skipSilenceOnTitle.
  ///
  /// In en, this message translates to:
  /// **'Skipping silence'**
  String get skipSilenceOnTitle;

  /// No description provided for @skipSilenceOnBody.
  ///
  /// In en, this message translates to:
  /// **'Only speech is recorded.'**
  String get skipSilenceOnBody;

  /// No description provided for @skipSilenceOffTitle.
  ///
  /// In en, this message translates to:
  /// **'Recording everything'**
  String get skipSilenceOffTitle;

  /// No description provided for @skipSilenceOffBody.
  ///
  /// In en, this message translates to:
  /// **'Silence is recorded too.'**
  String get skipSilenceOffBody;

  /// No description provided for @skipSilenceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Skipping silence is not available on this device.'**
  String get skipSilenceUnavailable;

  /// No description provided for @settingsTheme.
  ///
  /// In en, this message translates to:
  /// **'Theme'**
  String get settingsTheme;

  /// No description provided for @settingsThemeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Light or dark. Following the device is the default; choose one to override it — useful when recording in a dark room with a device set to light.'**
  String get settingsThemeSubtitle;

  /// No description provided for @themeSystem.
  ///
  /// In en, this message translates to:
  /// **'Follow the device'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get themeDark;

  /// No description provided for @noRecordingsOnDay.
  ///
  /// In en, this message translates to:
  /// **'Nothing recorded on this day.'**
  String get noRecordingsOnDay;

  /// No description provided for @noRecordingsOnDayHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the highlighted day again to see the whole archive.'**
  String get noRecordingsOnDayHint;

  /// No description provided for @recordingReconnecting.
  ///
  /// In en, this message translates to:
  /// **'Lost the microphone. Reconnecting…'**
  String get recordingReconnecting;

  /// No description provided for @recordingResumed.
  ///
  /// In en, this message translates to:
  /// **'Recording again.'**
  String get recordingResumed;

  /// No description provided for @recordingInterruptedBody.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped: the microphone stayed unavailable. Everything captured up to that point has been saved.'**
  String get recordingInterruptedBody;

  /// No description provided for @recordingWriteFailedBody.
  ///
  /// In en, this message translates to:
  /// **'Recording stopped: the audio could not be saved to this device. Everything recorded up to that point has been kept.'**
  String get recordingWriteFailedBody;

  /// No description provided for @durationHoursMinutes.
  ///
  /// In en, this message translates to:
  /// **'{hours} h {minutes} min'**
  String durationHoursMinutes(int hours, int minutes);

  /// No description provided for @durationMinutes.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{under a minute} =1{1 min} other{{count} min}}'**
  String durationMinutes(int count);

  /// No description provided for @settingsStorageDurations.
  ///
  /// In en, this message translates to:
  /// **'{recorded} recorded · about {remaining} still fits'**
  String settingsStorageDurations(String recorded, String remaining);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'ja', 'ko', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when language+script codes are specified.
  switch (locale.languageCode) {
    case 'zh':
      {
        switch (locale.scriptCode) {
          case 'Hant':
            return AppLocalizationsZhHant();
        }
        break;
      }
  }

  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'ja':
      return AppLocalizationsJa();
    case 'ko':
      return AppLocalizationsKo();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
