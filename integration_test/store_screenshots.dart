// Store screenshots for McRecorder — the screen list for Play and Apple.
//
//   ./idatagear_app_release/store-kit shoot                  # every tier x locale
//   ./idatagear_app_release/store-kit shoot --tier phone --locale ja
//
// The runner injects the locale (--dart-define=STOREKIT_LOCALE) and grabs a
// frame at every `shot(...)`, so this file never taps a language picker and
// never hardcodes a coordinate. That is what lets one list serve five languages
// and three device tiers.
//
// FOUR THINGS THIS FILE IS RESPONSIBLE FOR
//
//   LOCALE — set directly through `SettingsNotifier.setLanguage`, and persisted
//   to SharedPreferences first so the notifier's own async load agrees with it
//   instead of resetting to "system" a few milliseconds in.
//
//   NO ONBOARDING — the app has none. What it does have is an animated splash
//   whose equalizer never settles, so `bootstrap` waits for the splash widget
//   to LEAVE rather than for the tree to go quiet. `pumpAndSettle` alone
//   photographs the splash.
//
//   NO RANDOMNESS — there is none in the app, and none here: every recording,
//   transcript and query in store_demo_data.dart is a literal. Two runs of the
//   same locale produce the same pictures.
//
//   CONTENT — a fresh install has no recordings, so most of the app has nothing
//   to show. `seedRecordings` writes a fixed library of twelve before the app
//   comes up. See store_demo_data.dart for what is real and what is seeded.
//
// FINDERS — the app has almost no widget keys, so this file finds by TYPE and
// by ICON, never by text. Both survive translation, which is the property that
// matters; adding keys to production widgets purely for this file was not worth
// the churn.

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:momera_recording/data/models/app_settings.dart';
import 'package:momera_recording/main.dart';
import 'package:momera_recording/presentation/providers/recordings_provider.dart';
import 'package:momera_recording/presentation/providers/service_providers.dart';
import 'package:momera_recording/presentation/providers/settings_provider.dart';
import 'package:momera_recording/presentation/screens/history_screen.dart';
import 'package:momera_recording/presentation/screens/settings_screen.dart';
import 'package:momera_recording/presentation/widgets/animated_logo_mark.dart';
import 'package:momera_recording/presentation/widgets/record_button.dart';
import 'package:momera_recording/presentation/widgets/recording_calendar.dart';
import 'package:momera_recording/presentation/widgets/recording_tile.dart';
import 'package:momera_recording/presentation/widgets/search_field.dart';
import 'package:momera_recording/presentation/widgets/skip_silence_button.dart';
import 'package:momera_recording/presentation/widgets/waveform_bar.dart';

import 'store_demo_data.dart';
import 'store_kit_shot.dart';

late ProviderContainer container;
late DemoContent demo;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('store screenshots', (tester) async {
    resetShotIndex();
    await bootstrap(tester, storeKitLocale);
    await captureAll(tester);
  });
}

// ---------------------------------------------------------------------------
// Bootstrap
// ---------------------------------------------------------------------------

Future<void> bootstrap(WidgetTester tester, String locale) async {
  demo = demoContentFor(locale);

  await tester.runAsync(() async {
    // Start from a genuine first-launch state: shot 01 is the real empty
    // screen, not a screen we cleared halfway through.
    await clearRecordings();

    // Persist the language BEFORE the app reads it. SettingsNotifier.build()
    // kicks off an async load that overwrites whatever is in state, so setting
    // the language on the notifier alone would be undone a few milliseconds
    // later — with the reset landing somewhere in the middle of the run.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('settings.language', _languageFor(locale).name);
    await prefs.setString('settings.themeMode', AppThemeMode.light.name);
  });

  container = ProviderContainer();
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const MomeraRecordingApp(),
    ),
  );

  // Belt and braces: the persisted value above is what survives the async
  // load; this makes the very first frame right as well.
  await container.read(settingsProvider.notifier).setLanguage(
        _languageFor(locale),
      );

  // The splash runs a repeating equalizer animation, so the tree never goes
  // quiet and pumpAndSettle would hand back a picture of the splash. Wait for
  // the splash's own widget to be gone instead — that is proof the recordings
  // list has loaded and HomeScreen is what is on screen.
  await waitUntil(
    tester,
    () => find.byType(AnimatedLogoMark).evaluate().isEmpty,
    timeout: const Duration(seconds: 40),
    describe: 'the splash to finish',
  );
  await settle(tester);
}

/// ARB code -> the app's own language enum. 'system' would follow the device,
/// which is exactly what a per-locale capture must not do.
AppLanguage _languageFor(String arbLocale) {
  switch (arbLocale) {
    case 'ja':
      return AppLanguage.japanese;
    case 'ko':
      return AppLanguage.korean;
    case 'zh':
      return AppLanguage.chineseSimplified;
    case 'zh_Hant':
      return AppLanguage.chineseTraditional;
    default:
      return AppLanguage.english;
  }
}

// ---------------------------------------------------------------------------
// The screens
//
// Order IS the sequence number in the filename, and selection.json refers to
// those numbers — so adding a screen in the middle renumbers everything after
// it. Append rather than insert once a selection exists.
// ---------------------------------------------------------------------------

Future<void> captureAll(WidgetTester tester) async {
  // --- first launch --------------------------------------------------------
  await shot(tester, 'home_first_launch'); // 01

  await _reseed(tester, demo.recordings);

  // --- home, light ---------------------------------------------------------
  await shot(tester, 'home_today'); // 02
  await _scrollFraction(tester, 0.18);
  await shot(tester, 'home_transcript'); // 03
  await _scrollFraction(tester, 0.45);
  await shot(tester, 'home_list_scrolled'); // 04
  await _scrollToTop(tester);

  // --- search, home --------------------------------------------------------
  await _search(tester, demo.speechQuery);
  await shot(tester, 'search_spoken_words'); // 05
  await _search(tester, demo.nameQuery);
  await shot(tester, 'search_matched_name'); // 06
  await _search(tester, demo.missQuery);
  await shot(tester, 'search_no_results'); // 07
  await _search(tester, '');

  // --- acting on a recording -----------------------------------------------
  await _tapInFirstTile(tester, Icons.edit_outlined);
  // The dialog autofocuses its field; without this the device keyboard covers
  // the very dialog being photographed.
  await _hideKeyboard(tester);
  await shot(tester, 'rename_dialog'); // 08
  await _dismissOverlay(tester);

  await _tapInFirstTile(tester, Icons.delete_outline_rounded);
  await shot(tester, 'delete_confirm'); // 09
  await _dismissOverlay(tester);

  await _tapInFirstTile(tester, Icons.close_rounded);
  await shot(tester, 'remove_transcript_confirm'); // 10
  await _dismissOverlay(tester);

  await _tapInFirstTile(tester, Icons.copy_rounded);
  await shot(tester, 'transcript_copied'); // 11
  await _clearSnackBars(tester);
  // Android's own clipboard-preview chip is system UI: it is not a SnackBar,
  // nothing in the app can dismiss it, and it sat in the corner of the next
  // frame. Wait it out rather than photograph it twice.
  await _holdStill(tester, seconds: 5);

  // Start playing, THEN seek. Seeking straight into `play()` lands before the
  // source has loaded and the playhead comes back to zero, which photographs as
  // an empty progress bar on a three-minute recording.
  await _tapInFirstTile(tester, Icons.play_arrow_rounded);
  await _holdStill(tester, seconds: 2);
  await _seekInFirstTile(tester, 0.42);
  await _holdStill(tester, seconds: 2);
  await shot(tester, 'playing'); // 12
  await _stopPlayback(tester);

  // The Transcribe button only exists on a recording without a transcript, and
  // on a device that has not downloaded the model it opens the download sheet —
  // which is exactly what a new user sees the first time they ask for text.
  await _scrollToIcon(tester, Icons.graphic_eq_rounded);
  await _tapIcon(tester, Icons.graphic_eq_rounded);
  await shot(tester, 'model_download_sheet'); // 13
  await _dismissOverlay(tester);
  await _scrollToTop(tester);

  // --- history -------------------------------------------------------------
  await _openHistory(tester);
  await shot(tester, 'history_calendar'); // 14
  await _scrollFraction(tester, 0.12);
  await shot(tester, 'history_by_day'); // 15
  await _scrollFraction(tester, 0.45);
  await shot(tester, 'history_older'); // 16
  await _scrollFraction(tester, 0.80);
  await shot(tester, 'history_long_transcript'); // 17
  await _scrollToTop(tester);

  await _tapMarkedDay(tester);
  await shot(tester, 'history_single_day'); // 18
  await _tapMarkedDay(tester); // tapping again clears the filter
  await settle(tester);

  await _search(tester, demo.speechQuery);
  await shot(tester, 'history_search'); // 19
  await _search(tester, demo.missQuery);
  await shot(tester, 'history_search_empty'); // 20
  await _search(tester, '');
  await _backToHome(tester);

  // --- settings ------------------------------------------------------------
  await _openSettings(tester);
  await shot(tester, 'settings'); // 21
  await _openSettingRow(tester, 0);
  await shot(tester, 'settings_language'); // 22
  await _dismissOverlay(tester);
  await _openSettingRow(tester, 1);
  await shot(tester, 'settings_theme'); // 23
  await _dismissOverlay(tester);
  await _openSettingRow(tester, 2);
  await shot(tester, 'settings_autosave'); // 24
  await _dismissOverlay(tester);
  await _openSettingRow(tester, 3);
  await shot(tester, 'settings_storage'); // 25
  await _dismissOverlay(tester);

  await _tapIcon(tester, Icons.info_outline_rounded, index: 3);
  await shot(tester, 'settings_storage_explained'); // 26
  await _dismissOverlay(tester);
  await _tapIcon(tester, Icons.info_outline_rounded);
  await shot(tester, 'settings_language_explained'); // 27
  await _dismissOverlay(tester);
  await _backToHome(tester);

  // --- recording -----------------------------------------------------------
  // A real recording, made by the real recorder, with the real foreground
  // service running. The audio is whatever the capture device's microphone
  // hears — silence on an emulator — which is why this section photographs the
  // recording UI and not a waveform.
  await tapAndSettle(tester, find.byType(RecordButton));
  await _holdStill(tester, seconds: 4);
  await shot(tester, 'recording'); // 28

  await _tapIcon(tester, Icons.pause_rounded, last: true);
  await _holdStill(tester, seconds: 1);
  await shot(tester, 'recording_paused'); // 29
  await _tapIcon(tester, Icons.play_arrow_rounded, last: true);

  await tapAndSettle(tester, find.byType(SkipSilenceButton));
  await shot(tester, 'skip_silence'); // 30
  await _holdStill(tester, seconds: 2);

  await tapAndSettle(tester, find.byType(RecordButton));
  await _holdStill(tester, seconds: 2);
  await _clearSnackBars(tester);
  await shot(tester, 'recording_saved'); // 31

  // Put the demo library back. The recording just made is genuine but empty —
  // a capture device has no one talking into it — so leaving it in place makes
  // it the newest recording, and every "first tile" screen from here on would
  // photograph a 00:00 waveform with no transcript instead of the library.
  await _reseed(tester, demo.recordings);

  // --- dark theme ----------------------------------------------------------
  // Not a repeat of the light screens: this app is used in dark rooms, the
  // palette is hand-built rather than an inversion, and the record button and
  // waveform read differently on it.
  await _setTheme(tester, AppThemeMode.dark);
  await shot(tester, 'dark_home'); // 32
  await _scrollFraction(tester, 0.18);
  await shot(tester, 'dark_transcript'); // 33
  await _scrollToTop(tester);

  await _search(tester, demo.speechQuery);
  await shot(tester, 'dark_search'); // 34
  await _search(tester, demo.missQuery);
  await shot(tester, 'dark_search_empty'); // 35
  await _search(tester, '');

  await _tapInFirstTile(tester, Icons.edit_outlined);
  await _hideKeyboard(tester);
  await shot(tester, 'dark_rename_dialog'); // 36
  await _dismissOverlay(tester);
  await _tapInFirstTile(tester, Icons.delete_outline_rounded);
  await shot(tester, 'dark_delete_confirm'); // 37
  await _dismissOverlay(tester);

  await _tapInFirstTile(tester, Icons.play_arrow_rounded);
  await _holdStill(tester, seconds: 2);
  await _seekInFirstTile(tester, 0.42);
  await _holdStill(tester, seconds: 2);
  await shot(tester, 'dark_playing'); // 38
  await _stopPlayback(tester);

  await _scrollToIcon(tester, Icons.graphic_eq_rounded);
  await _tapIcon(tester, Icons.graphic_eq_rounded);
  await shot(tester, 'dark_model_download_sheet'); // 39
  await _dismissOverlay(tester);
  await _scrollToTop(tester);

  await _openHistory(tester);
  await shot(tester, 'dark_history_calendar'); // 40
  await _tapMarkedDay(tester);
  await shot(tester, 'dark_history_single_day'); // 41
  await _tapMarkedDay(tester);
  await _search(tester, demo.speechQuery);
  await shot(tester, 'dark_history_search'); // 42
  await _search(tester, '');
  await _backToHome(tester);

  await _openSettings(tester);
  await shot(tester, 'dark_settings'); // 43
  await _openSettingRow(tester, 0);
  await shot(tester, 'dark_settings_language'); // 44
  await _dismissOverlay(tester);
  await _openSettingRow(tester, 3);
  await shot(tester, 'dark_settings_storage'); // 45
  await _dismissOverlay(tester);
  await _backToHome(tester);

  await tapAndSettle(tester, find.byType(RecordButton));
  await _holdStill(tester, seconds: 4);
  await shot(tester, 'dark_recording'); // 46
  await tapAndSettle(tester, find.byType(RecordButton));
  await _holdStill(tester, seconds: 2);
  await _clearSnackBars(tester);

  // --- the remaining empty states ------------------------------------------
  // "Nothing today" is a different screen from "no recordings at all": the
  // user's audio is safe and one tap away, and saying so is the whole job of
  // that screen. Reaching it means an archive with nothing from today.
  await _setTheme(tester, AppThemeMode.light);
  await _reseed(
    tester,
    [for (final r in demo.recordings) if (r.daysAgo > 0) r],
  );
  await shot(tester, 'nothing_today'); // 47

  await _openHistory(tester);
  await shot(tester, 'history_from_empty_day'); // 48
  await _backToHome(tester);

  await _reseed(tester, const []);
  await _openHistory(tester);
  await shot(tester, 'history_empty'); // 49
  // Settings with nothing recorded: "History — No recordings", and a storage
  // row reading 0 MB. The counterpart to shot 21, which is the same screen
  // with a full archive behind it.
  await _openSettings(tester);
  await shot(tester, 'settings_empty_archive'); // 50
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Rewrite the recordings folder and make the app re-read it.
///
/// Real disk work, so it runs inside `runAsync`; `refresh()` is the app's own
/// re-scan, which is what the recorder calls after saving.
Future<void> _reseed(WidgetTester tester, List<DemoRecording> recordings) async {
  await tester.runAsync(() async {
    await clearRecordings();
    if (recordings.isNotEmpty) {
      await seedRecordings(DemoContent(
        recordings: recordings,
        speechQuery: demo.speechQuery,
        nameQuery: demo.nameQuery,
        missQuery: demo.missQuery,
      ));
    }
    await container.read(recordingsProvider.notifier).refresh();
  });
  await settle(tester);
}

/// Wall-clock hold, then a few pumps.
///
/// The elapsed-time readout is driven by a one-second periodic timer, so a
/// screenshot taken without letting real time pass shows 00:00 — and the point
/// of the recording screens is that they are recording.
Future<void> _holdStill(WidgetTester tester, {required int seconds}) async {
  await tester.runAsync(
    () => Future<void>.delayed(Duration(seconds: seconds)),
  );
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Scroll the visible list down by [pixels] (negative scrolls back up).
///
/// Moves the ScrollPosition directly rather than synthesising a drag. Both
/// `tester.drag` and `tester.dragFrom` were tried first and neither moved this
/// list: the tiles are full of gesture-hungry widgets — a SelectableText
/// transcript, an InkWell per search hit, a horizontal-drag waveform — and the
/// injected pointer loses the arena to one of them. A screenshot script does
/// not need the gesture to be realistic, it needs the list to be at a known
/// offset, so it asks for that offset. The failure mode this replaces was
/// silent: three identical frames and a green run.
Future<void> _scrollBy(WidgetTester tester, double pixels) async {
  final position = _listPosition(tester);
  if (position == null) return;
  position.jumpTo(
    (position.pixels + pixels)
        .clamp(position.minScrollExtent, position.maxScrollExtent),
  );
  await settle(tester);
}

/// Scroll to [fraction] of the way down the list.
///
/// Proportional rather than a pixel count, because the same twelve recordings
/// are a different number of pixels in every language — a Japanese transcript
/// is far shorter than its English original, so "scroll 320 px" lands on a
/// different part of the list in each locale and sequence NN stops meaning the
/// same screen.
Future<void> _scrollFraction(WidgetTester tester, double fraction) async {
  final position = _listPosition(tester);
  if (position == null) return;
  final extent = position.maxScrollExtent - position.minScrollExtent;
  position.jumpTo(position.minScrollExtent + extent * fraction);
  await settle(tester);
}

/// Scroll down until [icon] is built and on screen, or give up.
///
/// For the Transcribe button, which lives on whichever recording has no
/// transcript — a different distance down the list in every language. A fixed
/// scroll would find it in English and miss it in Korean.
Future<bool> _scrollToIcon(WidgetTester tester, IconData icon) async {
  for (var step = 0; step < 12; step++) {
    final finder = find.byIcon(icon);
    if (finder.evaluate().isNotEmpty) {
      await tester.ensureVisible(finder.first);
      await settle(tester);
      return true;
    }
    final position = _listPosition(tester);
    if (position == null) return false;
    if (position.pixels >= position.maxScrollExtent) break;
    await _scrollBy(tester, 400);
  }
  debugPrint('$kShotMarker-SKIP never scrolled to icon: $icon');
  return false;
}

/// Back to the top of whatever list is on screen.
Future<void> _scrollToTop(WidgetTester tester) async {
  final position = _listPosition(tester);
  if (position == null) return;
  position.jumpTo(position.minScrollExtent);
  await settle(tester);
}

/// The scroll position of the screen's main list.
///
/// NOT `find.byType(Scrollable).last`. Every transcript on screen is a
/// `SelectableText`, and each one builds its own internal Scrollable as a
/// DESCENDANT of the list — so `.last` is a text box whose maxScrollExtent is
/// zero, and scrolling it moves nothing while reporting success. That produced
/// three byte-identical "different" screens and a green run.
///
/// The list is the one with something to scroll, so pick the largest extent.
ScrollPosition? _listPosition(WidgetTester tester) {
  ScrollPosition? best;
  for (final element in find.byType(Scrollable).evaluate()) {
    final state = element is StatefulElement ? element.state : null;
    if (state is! ScrollableState) continue;
    final position = state.position;
    if (!position.hasContentDimensions) continue;
    if (best == null || position.maxScrollExtent > best.maxScrollExtent) {
      best = position;
    }
  }
  return best;
}

/// Stop playback outright.
///
/// Through the app's own playback service rather than by hunting for a pause
/// icon: whether the tile is showing play or pause at any instant depends on a
/// stream that may not have ticked yet, and a missed pause leaves audio running
/// under every screen that follows.
Future<void> _stopPlayback(WidgetTester tester) async {
  await tester.runAsync(
    () => container.read(audioPlaybackServiceProvider).stop(),
  );
  await settle(tester);
}

/// Put [query] into whichever search field is on screen — home's or History's.
///
/// NOT `tester.enterText`. `IntegrationTestWidgetsFlutterBinding` deliberately
/// leaves the test text input unregistered so that real keyboard behaviour can
/// be tested, so `enterText` delivers nothing here — and worse, it focuses the
/// field, which raises the device's actual soft keyboard. That keyboard then
/// covers the bottom half of every subsequent frame, including dialogs.
///
/// Writing the controller and calling the field's own `onChanged` runs exactly
/// what typing would run — the query provider updates and the list filters —
/// while leaving focus, and the keyboard, alone.
Future<void> _search(WidgetTester tester, String query) async {
  final finder = find.descendant(
    of: find.byType(SearchField),
    matching: find.byType(TextField),
  );
  if (finder.evaluate().isEmpty) return;
  final field = tester.widget<TextField>(finder.first);
  field.controller?.text = query;
  field.onChanged?.call(query);
  await settle(tester);
}

/// Tap the nth (or last) widget carrying [icon], anywhere on screen.
///
/// Exists because `find.byIcon(x).first` THROWS "Bad state: No element" when
/// nothing matches — including inside `tapAndSettle`'s own emptiness check, so
/// the guard there cannot save you. One absent icon should skip one screen, not
/// end a fifty-screen run.
Future<bool> _tapIcon(
  WidgetTester tester,
  IconData icon, {
  int index = 0,
  bool last = false,
}) async {
  final finder = find.byIcon(icon);
  final count = finder.evaluate().length;
  if (count == 0 || (!last && index >= count)) {
    debugPrint('$kShotMarker-SKIP icon not found: $icon');
    return false;
  }
  await tester.tap(last ? finder.last : finder.at(index), warnIfMissed: false);
  await settle(tester);
  return true;
}

/// Send the soft keyboard away and wait for it to actually go.
///
/// The rename dialog autofocuses its field, which is right for the app and
/// wrong for a screenshot: the keyboard covers the dialog it belongs to. The
/// hide is a real platform animation, so this waits in wall-clock time.
Future<void> _hideKeyboard(WidgetTester tester) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await tester.runAsync(
    () => SystemChannels.textInput.invokeMethod<void>('TextInput.hide'),
  );
  await _holdStill(tester, seconds: 1);
}

/// Tap an action inside the first recording tile, scoped so that an icon which
/// also appears elsewhere (close, play) cannot be picked up from the app bar,
/// the search field or another tile.
Future<bool> _tapInFirstTile(WidgetTester tester, IconData icon) async {
  final tile = find.byType(RecordingTile);
  if (tile.evaluate().isEmpty) return false;
  return tapAndSettle(
    tester,
    find.descendant(of: tile.first, matching: find.byIcon(icon)),
  );
}

/// Close the topmost route — a dialog, or a bottom sheet.
///
/// Pops the navigator instead of tapping Cancel or the scrim, both of which
/// were tried and both of which misfired: `find.byType(ModalBarrier).last` is
/// not reliably the sheet's own scrim, and one stray tap landed on the language
/// sheet's FIRST OPTION — silently switching the app to "System default" for
/// every screen after it, which on a per-locale capture would have quietly
/// changed the language of a whole listing's screenshots. Popping is what
/// Cancel does anyway, and it cannot choose anything.
Future<void> _dismissOverlay(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  if (nav.canPop()) nav.pop();
  await settle(tester);
}

/// Unwind to the home screen, wherever we are.
///
/// History is reached THROUGH Settings, so a single `pageBack()` out of it
/// lands on Settings, not home — and the drift compounds until a later
/// `find.byType(RecordButton)` finds nothing and a run loses its recording
/// screens. `popUntil(isFirst)` cannot drift.
Future<void> _backToHome(WidgetTester tester) async {
  final nav = tester.state<NavigatorState>(find.byType(Navigator).first);
  nav.popUntil((route) => route.isFirst);
  await settle(tester);
}

/// Drain any SnackBar so it cannot photobomb the next screen.
Future<void> _clearSnackBars(WidgetTester tester) async {
  final scaffold = find.byType(Scaffold);
  if (scaffold.evaluate().isEmpty) return;
  ScaffoldMessenger.of(tester.element(scaffold.first)).clearSnackBars();
  await settle(tester);
}

/// Home -> Settings. Always starts from home, so it cannot be a no-op that
/// happens to look right because we were already there.
Future<void> _openSettings(WidgetTester tester) async {
  await _backToHome(tester);
  await _tapIcon(tester, Icons.settings_outlined);
  await waitForFinder(tester, find.byType(SettingsScreen),
      timeout: const Duration(seconds: 10));
  await settle(tester);
}

/// Settings is the only way into History, and it is the last row there.
Future<void> _tapSettingsHistoryRow(WidgetTester tester) async {
  await _openSettingRow(tester, 4);
  await waitForFinder(tester, find.byType(HistoryScreen),
      timeout: const Duration(seconds: 10));
  await settle(tester);
}

Future<void> _openHistory(WidgetTester tester) async {
  await _openSettings(tester);
  await _tapSettingsHistoryRow(tester);
}

/// Open the picker for the nth settings row: 0 language, 1 theme, 2 auto-save,
/// 3 storage, 4 history.
///
/// Anchored on each row's own chevron rather than on `find.byType(ListTile)`.
/// The pickers are bottom sheets built out of ListTiles too, so while one is
/// open — or still animating shut — the index of "the third ListTile" is not
/// the third setting, and taps land on whatever happens to be there. Only the
/// five setting rows have a chevron, so this count is stable. The chevron is
/// decoration, not a button, so tapping it taps the row.
Future<void> _openSettingRow(WidgetTester tester, int index) async {
  await _tapIcon(tester, Icons.chevron_right_rounded, index: index);
}

/// Tap a day the calendar has marked, which filters History to it.
///
/// Days with no recordings are deliberately inert in this app — their cell is
/// built with a null `onTap` — so the tap has to land on a marked one. Asking
/// for the cells that actually accept a tap is what makes this work in every
/// locale: the grid's first column is a MaterialLocalizations value, so no
/// fixed row/column would be the same day twice.
Future<void> _tapMarkedDay(WidgetTester tester) async {
  final calendar = find.byType(RecordingCalendar);
  if (calendar.evaluate().isEmpty) return;
  final cells = find.descendant(
    of: calendar,
    matching: find.byWidgetPredicate(
      (w) => w is InkResponse && w.onTap != null,
    ),
  );
  // Last in tree order is the latest day holding a recording, i.e. today.
  if (cells.evaluate().isEmpty) return;
  await tapAndSettle(tester, cells.last);
}

/// Tap the waveform of the first tile at [fraction] of its width.
///
/// The strip seeks on tap-down and starts playback if it was not already
/// running, so this is both the seek gesture and the play gesture — and it
/// leaves the progress fill somewhere worth photographing, which three seconds
/// of playback on a three-minute recording does not.
Future<void> _seekInFirstTile(WidgetTester tester, double fraction) async {
  final tile = find.byType(RecordingTile);
  if (tile.evaluate().isEmpty) return;
  final bar = find.descendant(
    of: tile.first,
    matching: find.byType(WaveformBar),
  );
  if (bar.evaluate().isEmpty) return;
  final rect = tester.getRect(bar.first);
  await tester.tapAt(
    Offset(rect.left + rect.width * fraction, rect.center.dy),
  );
  await settle(tester);
}

Future<void> _setTheme(WidgetTester tester, AppThemeMode mode) async {
  await tester.runAsync(
    () => container.read(settingsProvider.notifier).setThemeMode(mode),
  );
  await settle(tester);
}
