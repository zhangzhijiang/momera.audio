import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/data/models/app_settings.dart';
import 'package:momera_recording/l10n/app_localizations.dart';
import 'package:momera_recording/main.dart';
import 'package:momera_recording/core/utils/byte_format.dart';
import 'package:momera_recording/presentation/providers/recordings_provider.dart';
import 'package:momera_recording/data/models/recording.dart';
import 'package:momera_recording/presentation/screens/history_screen.dart';
import 'package:momera_recording/presentation/providers/settings_provider.dart';
import 'package:momera_recording/presentation/screens/settings_screen.dart';
import 'package:momera_recording/presentation/widgets/recording_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppLanguage', () {
    test('offers exactly the languages the model can transcribe', () {
      // The UI is never offered in a language whose speech the app cannot
      // handle. Cantonese has no separate written locale, so it is served by
      // Traditional Chinese.
      expect(AppLanguage.values.map((l) => l.name).toSet(), {
        'system',
        'english',
        'chineseSimplified',
        'chineseTraditional',
        'japanese',
        'korean',
      });
    });

    test('every language maps to a locale AppLocalizations supports', () {
      for (final language in AppLanguage.values) {
        final locale = language.locale;
        if (locale == null) continue; // `system` follows the device.
        expect(
          AppLocalizations.supportedLocales,
          contains(locale),
          reason: '${language.name} maps to $locale, which gen-l10n does not '
              'emit — MaterialApp would fail to resolve it',
        );
      }
    });

    test('Simplified Chinese is plain `zh`, not `zh-Hans`', () {
      // gen-l10n emits app_zh.arb as Locale('zh'). Using zh-Hans here would
      // hand MaterialApp an unsupported locale.
      expect(AppLanguage.chineseSimplified.locale, const Locale('zh'));
    });

    test('fromName round-trips, and unknown values fall back to system', () {
      for (final language in AppLanguage.values) {
        expect(AppLanguage.fromName(language.name), language);
      }
      expect(AppLanguage.fromName('klingon'), AppLanguage.system);
      expect(AppLanguage.fromName(null), AppLanguage.system);
    });
  });

  group('locale resolution', () {
    Locale resolve(Locale? device) =>
        MomeraRecordingApp.resolveLocale(device, AppLocalizations.supportedLocales);

    test('exact matches are kept', () {
      expect(resolve(const Locale('en')), const Locale('en'));
      expect(resolve(const Locale('ja')), const Locale('ja'));
      expect(resolve(const Locale('ko')), const Locale('ko'));
    });

    test('Chinese regions pick the right script', () {
      const hant = Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant');
      expect(resolve(const Locale('zh', 'TW')), hant);
      expect(resolve(const Locale('zh', 'HK')), hant);
      expect(resolve(const Locale('zh', 'MO')), hant);
      expect(resolve(const Locale('zh', 'CN')), const Locale('zh'));
      expect(resolve(const Locale('zh')), const Locale('zh'));
    });

    test('regional variants fall back to the base language', () {
      expect(resolve(const Locale('ja', 'JP')), const Locale('ja'));
      expect(resolve(const Locale('en', 'GB')), const Locale('en'));
    });

    test('untranslated languages and a null device fall back to English', () {
      expect(resolve(const Locale('de')), const Locale('en'));
      // Spanish was dropped: the model cannot transcribe it, so offering a
      // Spanish UI promised something the app could not deliver.
      expect(resolve(const Locale('es')), const Locale('en'));
      expect(resolve(const Locale('fr')), const Locale('en'));
      expect(resolve(null), const Locale('en'));
    });
  });

  group('AppSettings', () {
    test('defaults match the agreed behaviour', () {
      const settings = AppSettings();
      expect(settings.language, AppLanguage.system);
      expect(settings.autosaveInterval, const Duration(seconds: 10));
      expect(settings.maxStorageBytes, 2 * 1024 * 1024 * 1024);
      // Off by default: dropping audio has to be a choice the user makes, not
      // one they discover after the recording.
      expect(settings.skipSilence, isFalse);
      expect(settings.themeMode, AppThemeMode.system);
    });

    test('the default values are offered in the pickers', () {
      expect(AppSettings.storageOptions,
          contains(AppSettings.defaultMaxStorageBytes));
      expect(AppSettings.autosaveOptions,
          contains(AppSettings.defaultAutosaveInterval));
    });
  });

  group('formatBytes', () {
    test('renders whole gigabytes without a decimal point', () {
      expect(formatBytes(2 * 1024 * 1024 * 1024), '2 GB');
      expect(formatBytes(10 * 1024 * 1024 * 1024), '10 GB');
    });

    test('renders sub-gigabyte sizes in megabytes', () {
      expect(formatBytes(512 * 1024 * 1024), '512 MB');
    });
  });

  group('formatCreatedAt', () {
    test('is fixed yyyy-MM-dd HH:mm:ss, 24-hour', () {
      expect(
        formatCreatedAt(DateTime(2026, 9, 5, 16, 7, 3)),
        '2026-09-05 16:07:03',
      );
      // Afternoon times must not render as 12-hour with AM/PM.
      expect(formatCreatedAt(DateTime(2026, 1, 2, 23, 59, 59)),
          '2026-01-02 23:59:59');
      expect(formatCreatedAt(DateTime(2026, 12, 31, 0, 0, 0)),
          '2026-12-31 00:00:00');
    });
  });

  group('SettingsScreen', () {
    Future<void> pumpSettings(
      WidgetTester tester, {
      List<Override> overrides = const [],
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows every row and the default values', (tester) async {
      await pumpSettings(tester);

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);
      expect(find.text('2 GB'), findsOneWidget);
      expect(find.text('10 seconds'), findsOneWidget);
    });

    testWidgets('offers no spoken-language setting', (tester) async {
      // Recognition is always automatic: asking the user to pin a language
      // before recording asks a question they cannot answer, and can only make
      // results worse than per-segment detection. The section headers went with
      // it, since every remaining group held a single row.
      await pumpSettings(tester);

      expect(find.text('Spoken language'), findsNothing);
      expect(find.text('TRANSCRIPTION'), findsNothing);
      expect(find.text('STORAGE'), findsNothing);
      expect(find.text('RECORDING'), findsNothing);
    });

    testWidgets('the info icon explains a setting, and closes cleanly',
        (tester) async {
      await pumpSettings(tester);

      // The explanation is not on screen until asked for — that is the point
      // of moving it off the row.
      const explanation = 'Recording stops when your recordings reach this '
          'size. The times shown are lengths of audio — with Skip silence on, '
          'a session can run for longer than that.';
      expect(find.text(explanation), findsNothing);

      // Found through its own row rather than by position: the row order is
      // deliberate (see the order test below) and free to change again.
      await tester.tap(
        find.descendant(
          of: find.ancestor(
            of: find.text('Maximum storage'),
            matching: find.byType(ListTile),
          ),
          matching: find.byTooltip('About this setting'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(explanation), findsOneWidget);

      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(find.text(explanation), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('reports storage as bytes, as recorded time, and as time left',
        (tester) async {
      // 1 GB used of the 2 GB default leaves 1 GB, which at 16 kHz mono PCM16
      // (32000 bytes a second) is 9 h 19 min of audio.
      await pumpSettings(tester, overrides: [
        storageUsedProvider.overrideWith((ref) async => 1024 * 1024 * 1024),
        recordingsProvider.overrideWith(
          () => _FixedRecordings(const [
            Duration(hours: 1),
            Duration(minutes: 30),
          ]),
        ),
      ]);

      expect(find.text('1 GB of 2 GB used\n'
          '1 h 30 min recorded · about 9 h 19 min still fits'),
          findsOneWidget);
    });

    testWidgets('says nothing about time until the sizes are known',
        (tester) async {
      // Better a row with no footer for a frame than one claiming zero hours.
      await pumpSettings(tester, overrides: [
        storageUsedProvider.overrideWith((ref) => Completer<int>().future),
      ]);

      expect(find.textContaining('still fits'), findsNothing);
    });

    testWidgets('lists the rows in the agreed order, ending in History',
        (tester) async {
      await pumpSettings(tester);

      // Language first because it changes every other string on screen;
      // History last because it navigates away instead of setting a value.
      final titles = tester
          .widgetList<Text>(find.descendant(
            of: find.byType(ListTile),
            matching: find.byType(Text),
          ))
          .map((t) => t.data)
          .toList();
      expect(
        titles,
        containsAllInOrder(<String>[
          'Language',
          'Theme',
          'Auto-save interval',
          'Maximum storage',
          'History',
        ]),
      );
    });

    testWidgets('the History row opens History, not a picker', (tester) async {
      // Without a store the list never resolves and its spinner animates
      // forever, so nothing in the tree would ever settle.
      await pumpSettings(tester,
          overrides: [recordingsProvider.overrideWith(_NoRecordings.new)]);

      await tester.tap(find.text('History'));
      await tester.pumpAndSettle();

      expect(find.byType(HistoryScreen), findsOneWidget);
    });

    testWidgets('tapping the row still opens the picker, not the explanation',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('Maximum storage'));
      await tester.pumpAndSettle();

      // The sheet lists every storage option; the info dialog would not.
      expect(find.text('512 MB'), findsOneWidget);
      expect(find.text('10 GB'), findsOneWidget);
    });

    testWidgets('picking a language updates the displayed value',
        (tester) async {
      await pumpSettings(tester);

      await tester.tap(find.text('System default'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('日本語').last);
      await tester.pumpAndSettle();

      expect(find.text('日本語'), findsOneWidget);
    });
  });
}

/// A store that resolves immediately, with nothing in it.
class _NoRecordings extends RecordingsNotifier {
  @override
  Future<List<Recording>> build() async => const [];
}

/// A store that resolves immediately, with recordings of the given lengths.
class _FixedRecordings extends RecordingsNotifier {
  _FixedRecordings(this.lengths);

  final List<Duration> lengths;

  @override
  Future<List<Recording>> build() async => [
        for (var i = 0; i < lengths.length; i++)
          Recording(
            path: '/tmp/recording_$i.wav',
            createdAt: DateTime(2026, 1, 1, i),
            sizeBytes: 0,
            duration: lengths[i],
          ),
      ];
}
