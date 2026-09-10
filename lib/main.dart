import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/utils/app_theme.dart';
import 'data/models/app_settings.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/splash_gate.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ProviderScope(child: MomeraRecordingApp()));
}

class MomeraRecordingApp extends ConsumerWidget {
  const MomeraRecordingApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null locale means "follow the device", which is the default.
    final locale = ref.watch(settingsProvider.select((s) => s.language.locale));
    final themeMode = ref.watch(settingsProvider.select((s) => s.themeMode));

    return MaterialApp(
      title: 'Momera Recorder',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: switch (themeMode) {
        AppThemeMode.system => ThemeMode.system,
        AppThemeMode.light => ThemeMode.light,
        AppThemeMode.dark => ThemeMode.dark,
      },
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The device may be set to a Chinese locale with no script subtag (plain
      // `zh`), or to a language we do not translate. Resolve those explicitly
      // rather than letting Flutter fall through to the first supported locale.
      localeResolutionCallback: resolveLocale,
      // The status and navigation bars are painted by the system, so they have
      // to be told which theme won — including when "system" resolves it, which
      // only the built subtree knows.
      home: const _SystemChrome(child: SplashGate()),
    );
  }

  /// Visible for testing.
  @visibleForTesting
  static Locale resolveLocale(Locale? device, Iterable<Locale> supported) {
    if (device == null) return const Locale('en');

    // Chinese must be handled before the generic exact match below. We ship
    // Simplified as plain `zh` (no script subtag), so a device set to zh-TW
    // would otherwise match `zh` on language+script — both have a null script
    // code — and get Simplified text on a Traditional device.
    if (device.languageCode == 'zh') {
      const traditionalRegions = {'HK', 'MO', 'TW'};
      final wantsTraditional = device.scriptCode == 'Hant' ||
          traditionalRegions.contains(device.countryCode);
      return wantsTraditional
          ? const Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')
          : const Locale('zh');
    }

    // Exact match, including script code.
    for (final locale in supported) {
      if (locale.languageCode == device.languageCode &&
          locale.scriptCode == device.scriptCode) {
        return locale;
      }
    }

    // Same language, any region (e.g. es-MX -> es).
    for (final locale in supported) {
      if (locale.languageCode == device.languageCode) return locale;
    }

    return const Locale('en');
  }
}

/// Keeps the system bars in step with the active theme.
///
/// Sits inside `MaterialApp` rather than being set once in `main`, because with
/// `ThemeMode.system` the answer changes when the device does, and only a
/// widget below the theme can see it.
class _SystemChrome extends StatelessWidget {
  const _SystemChrome({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        statusBarBrightness: dark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: colors.background,
        systemNavigationBarIconBrightness:
            dark ? Brightness.light : Brightness.dark,
      ),
      child: child,
    );
  }
}
