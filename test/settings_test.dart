import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momera_audio/data/models/app_settings.dart';
import 'package:momera_audio/l10n/app_localizations.dart';
import 'package:momera_audio/main.dart';
import 'package:momera_audio/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppLanguage', () {
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
      expect(resolve(const Locale('es')), const Locale('es'));
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
      expect(resolve(const Locale('es', 'MX')), const Locale('es'));
      expect(resolve(const Locale('en', 'GB')), const Locale('en'));
    });

    test('untranslated languages and a null device fall back to English', () {
      expect(resolve(const Locale('de')), const Locale('en'));
      expect(resolve(const Locale('ja')), const Locale('en'));
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

      await tester.tap(find.text('Español').last);
      await tester.pumpAndSettle();

      expect(find.text('Español'), findsOneWidget);
    });
  });
}
