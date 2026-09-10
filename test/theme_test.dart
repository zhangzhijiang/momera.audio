import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/utils/app_theme.dart';
import 'package:momera_recording/data/models/app_settings.dart';
import 'package:momera_recording/l10n/app_localizations.dart';
import 'package:momera_recording/presentation/providers/settings_provider.dart';
import 'package:momera_recording/presentation/screens/settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('AppColors', () {
    test('the two palettes are genuinely different grounds', () {
      expect(AppColors.light.background.computeLuminance(),
          greaterThan(0.8));
      expect(AppColors.dark.background.computeLuminance(), lessThan(0.05));
    });

    test('text stays legible on its own ground', () {
      // Not a full WCAG audit — just the guard that would catch a palette
      // edited into invisibility.
      for (final palette in [AppColors.light, AppColors.dark]) {
        final contrast = (palette.textPrimary.computeLuminance() -
                palette.surface.computeLuminance())
            .abs();
        expect(contrast, greaterThan(0.5),
            reason: 'primary text must stand off the surface it sits on');
      }
    });

    test('the accent lightens for dark, rather than being reused', () {
      // A violet tuned for white would sink into a near-black ground.
      expect(AppColors.dark.accent.computeLuminance(),
          greaterThan(AppColors.light.accent.computeLuminance()));
    });

    test('lerp moves every role, so a theme change animates as one', () {
      final mid = AppColors.light.lerp(AppColors.dark, 0.5);
      expect(mid.background, isNot(AppColors.light.background));
      expect(mid.rowAlternate, isNot(AppColors.light.rowAlternate));
    });
  });

  group('AppTheme.of', () {
    Future<AppColors> resolve(WidgetTester tester, ThemeData theme) async {
      late AppColors seen;
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Builder(builder: (context) {
            seen = AppTheme.of(context);
            return const SizedBox();
          }),
        ),
      );
      // MaterialApp animates between themes, so a palette read on the frame
      // after the swap is a half-way lerp, not the destination.
      await tester.pumpAndSettle();
      return seen;
    }

    testWidgets('hands each theme its own palette', (tester) async {
      expect(await resolve(tester, AppTheme.light), AppColors.light);
      expect(await resolve(tester, AppTheme.dark), AppColors.dark);
    });

    testWidgets('falls back to light rather than throwing', (tester) async {
      // Several tests pump widgets under a bare MaterialApp with no theme of
      // ours. Those should render, not crash.
      expect(await resolve(tester, ThemeData()), AppColors.light);
    });
  });

  group('the theme setting', () {
    testWidgets('defaults to following the device, and can be changed',
        (tester) async {
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(builder: (context, r, _) {
              ref = r;
              return const SettingsScreen();
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(ref.read(settingsProvider).themeMode, AppThemeMode.system);
      expect(find.text('Follow the device'), findsOneWidget);

      await tester.tap(find.text('Theme'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dark').last);
      await tester.pumpAndSettle();

      expect(ref.read(settingsProvider).themeMode, AppThemeMode.dark);
      expect(find.text('Dark'), findsOneWidget,
          reason: 'the row shows the chosen value');
    });

    testWidgets('is remembered across launches', (tester) async {
      SharedPreferences.setMockInitialValues({'settings.themeMode': 'dark'});
      late WidgetRef ref;
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(builder: (context, r, _) {
              ref = r;
              return const SettingsScreen();
            }),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(ref.read(settingsProvider).themeMode, AppThemeMode.dark);
    });
  });
}
