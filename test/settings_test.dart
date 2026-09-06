import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momera_audio/data/models/app_settings.dart';
import 'package:momera_audio/l10n/app_localizations.dart';
import 'package:momera_audio/main.dart';
import 'package:momera_audio/presentation/screens/settings_screen.dart';
import 'package:momera_audio/presentation/widgets/recording_tile.dart';
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
        MomeraAudioApp.resolveLocale(device, AppLocalizations.supportedLocales);

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
    testWidgets('shows every section and the default values', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('System default'), findsOneWidget);
      expect(find.text('2 GB'), findsOneWidget);
      expect(find.text('10 seconds'), findsOneWidget);
    });

    testWidgets('picking a language updates the displayed value',
        (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('System default'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('日本語').last);
      await tester.pumpAndSettle();

      expect(find.text('日本語'), findsOneWidget);
    });
  });
}
