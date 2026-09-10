// store-kit capture helper.
//
// Copy or symlink this file into your app (e.g. integration_test/store_kit_shot.dart)
// and import it from your screenshot test.
//
// HOW CAPTURE WORKS
//   This does NOT take the screenshot itself. It settles the UI, prints a marker
//   line, then waits. The host runner (store-kit/bin/shoot.py) tails logcat and
//   runs `adb exec-out screencap` when it sees the marker.
//
//   Why not IntegrationTestWidgetsFlutterBinding.takeScreenshot()? That returns
//   only the Flutter surface — it excludes the system bars, so the image is not
//   the exact 9:16 the Play Console demands, and it needs test_driver/ plumbing.
//   screencap gives a true full-resolution frame with a real status bar and
//   keeps per-app setup to a single file.

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Must match `SHOT_MARKER` in store-kit/lib/playspec.py.
const String kShotMarker = 'STOREKIT_SHOT';

/// How long to hold still after signalling, giving the host time to capture.
/// Overridden by the runner via --dart-define=STOREKIT_DWELL_MS=...
const int _defaultDwellMs = 1500;

int get _dwellMs {
  const raw = String.fromEnvironment('STOREKIT_DWELL_MS');
  return raw.isEmpty ? _defaultDwellMs : (int.tryParse(raw) ?? _defaultDwellMs);
}

/// The locale this run should capture, injected by the runner via
/// --dart-define=STOREKIT_LOCALE=es. Empty means "whatever the app defaults to".
String get storeKitLocale =>
    const String.fromEnvironment('STOREKIT_LOCALE', defaultValue: '');

int _index = 0;

/// Settle, signal the host to capture, and hold still.
///
/// [name] becomes the descriptive tail of the filename
/// (`phone_03_en-US_word_detail.png`); the index below supplies the sequence
/// number, so pass a plain name like 'home' or 'word_detail'.
///
/// The index counts shot() calls rather than successful captures, so a frame the
/// host fails to grab leaves a gap instead of renumbering every later screen —
/// which is what keeps sequence NN the same screen in every locale.
Future<void> shot(WidgetTester tester, String name) async {
  await settle(tester);
  _index += 1;
  final stem = '${_index.toString().padLeft(2, '0')}_$name';

  // Printed, not logged, so it lands in logcat regardless of logging setup.
  debugPrint('$kShotMarker $stem');

  // Real wall-clock wait: the host is capturing during this window, so a fake
  // async pump would not give it time.
  await tester.runAsync(
    () => Future<void>.delayed(Duration(milliseconds: _dwellMs)),
  );
}

/// pumpAndSettle, but tolerant of screens that never fully settle.
///
/// Indefinite animations (spinners, looping hero art, autoplay audio UI) make
/// pumpAndSettle throw after its timeout. A screenshot tool should photograph
/// such a screen, not abort the run.
Future<void> settle(WidgetTester tester,
    {Duration timeout = const Duration(seconds: 8)}) async {
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, timeout);
  } on FlutterError {
    // Still animating — pump a few frames and photograph it as-is.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 120));
    }
  }
}

/// Wait in real time until [condition] holds, pumping frames as we go.
///
/// This is what `settle` cannot do. A splash screen with an indefinite progress
/// animation never settles, so pumpAndSettle gives up and you photograph the
/// splash instead of the app. Poll for something that proves the app is ready —
/// usually a widget that only exists once real content has loaded.
///
/// Returns false on timeout rather than throwing, so a slow boot degrades to a
/// reported problem instead of a dead run.
Future<bool> waitUntil(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 60),
  Duration interval = const Duration(milliseconds: 250),
  String? describe,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (condition()) return true;
    await tester.pump(interval);
    // Real wall-clock yield so the app's own async work (DB open, asset load,
    // network) can actually progress between polls.
    await tester.runAsync(() => Future<void>.delayed(interval));
  }
  debugPrint('$kShotMarker-SKIP timed out waiting for '
      '${describe ?? 'condition'}');
  return false;
}

/// Convenience: wait until a finder matches at least once.
Future<bool> waitForFinder(WidgetTester tester, Finder finder,
        {Duration timeout = const Duration(seconds: 60)}) =>
    waitUntil(tester, () => finder.evaluate().isNotEmpty,
        timeout: timeout, describe: finder.description);

/// Convenience: wait until every spinner is gone, i.e. loading has finished.
Future<bool> waitForNoSpinner(WidgetTester tester,
        {Duration timeout = const Duration(seconds: 60)}) =>
    waitUntil(tester,
        () => find.byType(CircularProgressIndicator).evaluate().isEmpty,
        timeout: timeout, describe: 'loading to finish');

/// Tap something and settle. Returns false instead of throwing when the target
/// is absent, so one missing screen doesn't kill a 20-screen run.
Future<bool> tapAndSettle(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    debugPrint('$kShotMarker-SKIP target not found: ${finder.description}');
    return false;
  }
  await tester.tap(finder.first, warnIfMissed: false);
  await settle(tester);
  return true;
}

/// Scroll a scrollable until [finder] is visible, then settle.
Future<bool> scrollTo(WidgetTester tester, Finder finder,
    {Finder? scrollable, double delta = 300}) async {
  try {
    await tester.scrollUntilVisible(finder, delta, scrollable: scrollable);
    await settle(tester);
    return true;
  } catch (_) {
    debugPrint('$kShotMarker-SKIP could not scroll to: ${finder.description}');
    return false;
  }
}

/// Reset the shot counter. Call at the start of each test body.
void resetShotIndex() => _index = 0;
