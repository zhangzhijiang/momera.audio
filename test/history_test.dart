import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/capabilities/capability.dart';
import 'package:momera_recording/data/models/recording.dart';
import 'package:momera_recording/l10n/app_localizations.dart';
import 'package:momera_recording/presentation/providers/capability_provider.dart';
import 'package:momera_recording/presentation/providers/recordings_provider.dart';
import 'package:momera_recording/presentation/providers/service_providers.dart';
import 'package:momera_recording/presentation/screens/history_screen.dart';
import 'package:momera_recording/presentation/screens/home_screen.dart';
import 'package:momera_recording/presentation/widgets/recording_calendar.dart';
import 'package:momera_recording/presentation/widgets/recording_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Recording _at(DateTime when, {String name = 'recording'}) {
  return Recording(
    path: '/tmp/${name}_${when.millisecondsSinceEpoch}.wav',
    createdAt: when,
    sizeBytes: 320044,
    duration: const Duration(seconds: 10),
  );
}

/// A store that resolves immediately with a fixed list.
class _FixedRecordings extends RecordingsNotifier {
  _FixedRecordings(this.recordings);

  final List<Recording> recordings;

  @override
  Future<List<Recording>> build() async => recordings;
}

/// Give the test a viewport tall enough for the fixtures.
///
/// The default 800x600 surface fits two tiles, so a third would simply never be
/// built by the lazy list — an assertion about grouping would then be measuring
/// the viewport, not the grouping.
void _tallViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 6000);
  tester.view.devicePixelRatio = 3.0;
  addTearDown(tester.view.reset);
}

Future<void> _pump(
  WidgetTester tester,
  Widget home, {
  List<Recording> recordings = const [],
  bool recordingInProgress = false,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recordingsProvider.overrideWith(() => _FixedRecordings(recordings)),
        transcriptionCapabilityProvider
            .overrideWith((_) async => const FeatureCapability.available()),
        isRecordingProvider.overrideWith((ref) => recordingInProgress),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('recordedToday', () {
    final now = DateTime(2026, 9, 9, 10, 30);

    test('keeps the calendar day, not the last 24 hours', () {
      final all = [
        _at(DateTime(2026, 9, 9, 10)), // earlier today
        _at(DateTime(2026, 9, 9, 0, 0, 1)), // just after midnight
        _at(DateTime(2026, 9, 8, 23, 59, 59)), // last night — yesterday's
        _at(DateTime(2026, 9, 8, 11)),
        _at(DateTime(2025, 9, 9, 10, 30)), // same day, a year earlier
      ];

      final today = recordedToday(all, now: now);

      expect(today.map((r) => r.createdAt), [
        DateTime(2026, 9, 9, 10),
        DateTime(2026, 9, 9, 0, 0, 1),
      ]);
    });

    test('a recording made a minute ago is still today at 23:59', () {
      final late = DateTime(2026, 9, 9, 23, 59);
      expect(recordedToday([_at(late)], now: late), hasLength(1));
    });

    test('holds no opinion when nothing is from today', () {
      expect(recordedToday([_at(DateTime(2026, 9, 8))], now: now), isEmpty);
    });
  });

  group('HomeScreen', () {
    testWidgets('lists today and leaves older recordings to History',
        (tester) async {
      final now = DateTime.now();
      await _pump(
        tester,
        const HomeScreen(),
        recordings: [
          _at(now.subtract(const Duration(minutes: 5)), name: 'fresh'),
          _at(now.subtract(const Duration(days: 3)), name: 'old'),
        ],
      );

      expect(find.text('Today'), findsOneWidget);
      expect(find.byType(RecordingTile), findsOneWidget);
    });

    testWidgets('explains an empty today rather than looking empty',
        (tester) async {
      await _pump(
        tester,
        const HomeScreen(),
        recordings: [_at(DateTime.now().subtract(const Duration(days: 2)))],
      );

      // Distinct from the never-recorded-anything state: the audio is safe,
      // and the screen has to say where it went.
      expect(find.text('Nothing recorded today'), findsOneWidget);
      expect(find.text('No recordings yet'), findsNothing);
      expect(find.byType(RecordingTile), findsNothing);

      await tester.tap(find.text('Open History'));
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('still shows the first-run state when nothing was ever recorded',
        (tester) async {
      await _pump(tester, const HomeScreen());

      expect(find.text('No recordings yet'), findsOneWidget);
      expect(find.text('Nothing recorded today'), findsNothing);
    });
  });

  group('HistoryScreen', () {
    testWidgets('shows every recording under a header for its day',
        (tester) async {
      _tallViewport(tester);
      final now = DateTime.now();
      await _pump(
        tester,
        const HistoryScreen(),
        recordings: [
          _at(now.subtract(const Duration(minutes: 5)), name: 'fresh'),
          _at(now.subtract(const Duration(days: 1)), name: 'yesterday'),
          _at(DateTime(2026, 1, 2, 9), name: 'old'),
        ],
      );

      expect(find.byType(RecordingTile), findsNWidgets(3));
      expect(find.text('Today'), findsOneWidget);
      expect(find.text('Yesterday'), findsOneWidget);
      expect(find.text('2026-01-02'), findsOneWidget);
    });

    testWidgets('two recordings on one day share a single header',
        (tester) async {
      _tallViewport(tester);
      await _pump(
        tester,
        const HistoryScreen(),
        recordings: [
          _at(DateTime(2026, 1, 2, 15), name: 'afternoon'),
          _at(DateTime(2026, 1, 2, 9), name: 'morning'),
        ],
      );

      expect(find.text('2026-01-02'), findsOneWidget);
      expect(find.byType(RecordingTile), findsNWidgets(2));
    });
  });

  group('the History calendar', () {
    // Days inside the month the calendar opens on, so they are on screen
    // without paging. Which month that is depends on the day the suite runs,
    // which is exactly why these are derived rather than hard-coded.
    final month = DateTime(DateTime.now().year, DateTime.now().month);
    final ninth = DateTime(month.year, month.month, 9, 10);
    final tenth = DateTime(month.year, month.month, 10, 11);

    Finder dayCell(String day) => find.descendant(
          of: find.byType(RecordingCalendar),
          matching: find.text(day),
        );

    testWidgets('marks the days that hold recordings and filters to one',
        (tester) async {
      _tallViewport(tester);
      await _pump(
        tester,
        const HistoryScreen(),
        recordings: [
          _at(tenth, name: 'tenth'),
          _at(ninth, name: 'ninth'),
        ],
      );

      expect(find.byType(RecordingCalendar), findsOneWidget);
      expect(find.byType(RecordingTile), findsNWidgets(2));

      await tester.tap(dayCell('9'));
      await tester.pumpAndSettle();

      expect(find.byType(RecordingTile), findsOneWidget,
          reason: 'only the ninth survives the filter');
    });

    testWidgets('tapping the chosen day again returns the whole archive',
        (tester) async {
      _tallViewport(tester);
      await _pump(
        tester,
        const HistoryScreen(),
        recordings: [_at(tenth, name: 'tenth'), _at(ninth, name: 'ninth')],
      );

      await tester.tap(dayCell('9'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordingTile), findsOneWidget);

      await tester.tap(dayCell('9'));
      await tester.pumpAndSettle();
      expect(find.byType(RecordingTile), findsNWidgets(2),
          reason: 'the only way back to everything without a separate control');
    });

    testWidgets('does not overflow a short screen', (tester) async {
      // A phone in landscape is barely taller than the calendar itself. The
      // month grid plus a search field plus a list has to survive that.
      tester.view.physicalSize = const Size(1600, 900);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);

      await _pump(
        tester,
        const HistoryScreen(),
        recordings: [_at(ninth, name: 'ninth')],
      );

      expect(tester.takeException(), isNull);
    });

    testWidgets('a day with nothing on it is inert', (tester) async {
      _tallViewport(tester);
      await _pump(
        tester,
        const HistoryScreen(),
        recordings: [_at(ninth, name: 'ninth')],
      );

      // The 11th holds nothing; tapping it must not empty the list, because
      // the highlight is what says where there is something to see.
      await tester.tap(dayCell('11'));
      await tester.pumpAndSettle();

      expect(find.byType(RecordingTile), findsOneWidget);
    });
  });

  group('alternating rows', () {
    testWidgets('bands every other recording within its day', (tester) async {
      _tallViewport(tester);
      final day = DateTime(2026, 1, 2);
      await _pump(
        tester,
        const HistoryScreen(),
        recordings: [
          _at(DateTime(day.year, day.month, day.day, 15), name: 'third'),
          _at(DateTime(day.year, day.month, day.day, 12), name: 'second'),
          _at(DateTime(day.year, day.month, day.day, 9), name: 'first'),
        ],
      );

      final tiles = tester
          .widgetList<RecordingTile>(find.byType(RecordingTile))
          .toList();
      expect(tiles.map((t) => t.alternate), [false, true, false],
          reason: 'banding restarts at each day header, so it counts within '
              'the day rather than down the whole archive');
    });
  });

  group('playback while recording', () {
    testWidgets('is refused, with a reason', (tester) async {
      await _pump(
        tester,
        const HistoryScreen(),
        recordings: [_at(DateTime(2026, 1, 2, 9))],
        recordingInProgress: true,
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      expect(
        find.text('Stop the recording before playing another one.'),
        findsOneWidget,
      );
    });

    testWidgets('is allowed the rest of the time', (tester) async {
      await _pump(
        tester,
        const HistoryScreen(),
        recordings: [_at(DateTime(2026, 1, 2, 9))],
      );

      await tester.tap(find.byIcon(Icons.play_arrow_rounded));
      await tester.pump();

      // The file does not exist, so playback fails — but it was attempted,
      // which is the difference being asserted.
      expect(
        find.text('Stop the recording before playing another one.'),
        findsNothing,
      );
    });
  });
}
