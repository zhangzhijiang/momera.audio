import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/utils/app_theme.dart';
import 'l10n/app_localizations.dart';
import 'presentation/providers/settings_provider.dart';
import 'presentation/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: AppTheme.background,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const ProviderScope(child: MomeraAudioApp()));
}

class MomeraAudioApp extends ConsumerWidget {
  const MomeraAudioApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Null locale means "follow the device", which is the default.
    final locale = ref.watch(settingsProvider.select((s) => s.language.locale));

    return MaterialApp(
      title: 'Momera.Audio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // The device may be set to a Chinese locale with no script subtag (plain
      // `zh`), or to a language we do not translate. Resolve those explicitly
      // rather than letting Flutter fall through to the first supported locale.
      localeResolutionCallback: resolveLocale,
      home: const HomeScreen(),
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
