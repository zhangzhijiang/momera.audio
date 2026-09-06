import 'package:flutter/widgets.dart';

/// The UI languages Momera.Audio ships.
///
/// [system] follows the device language, falling back to English when the
/// device language is not one we translate.
enum AppLanguage {
  system(null),
  english(Locale('en')),
  spanish(Locale('es')),
  // gen-l10n emits Simplified Chinese as plain `zh` (from app_zh.arb), not
  // `zh-Hans`. Using `zh-Hans` here would hand MaterialApp a locale that is
  // not in AppLocalizations.supportedLocales.
  chineseSimplified(Locale('zh')),
  chineseTraditional(Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant'));

  const AppLanguage(this.locale);

  /// The locale to force, or null to follow the system.
  final Locale? locale;

  static AppLanguage fromName(String? name) => AppLanguage.values.firstWhere(
        (l) => l.name == name,
        orElse: () => AppLanguage.system,
      );
}

/// User-configurable settings, persisted across launches.
@immutable
class AppSettings {
  const AppSettings({
    this.language = AppLanguage.system,
    this.maxStorageBytes = defaultMaxStorageBytes,
    this.autosaveInterval = defaultAutosaveInterval,
  });

  /// 2 GB. Roughly 18 hours at 16 kHz mono PCM16 (~1.83 MB/minute), which is
  /// generous for a voice recorder without being able to fill a small device.
  static const int defaultMaxStorageBytes = 2 * 1024 * 1024 * 1024;

  /// How often an in-progress recording is flushed to disk. A crash or force
  /// quit loses at most this much audio.
  static const Duration defaultAutosaveInterval = Duration(seconds: 10);

  /// Offered in the settings UI.
  static const List<int> storageOptions = [
    512 * 1024 * 1024,
    1024 * 1024 * 1024,
    2 * 1024 * 1024 * 1024,
    5 * 1024 * 1024 * 1024,
    10 * 1024 * 1024 * 1024,
  ];

  static const List<Duration> autosaveOptions = [
    Duration(seconds: 5),
    Duration(seconds: 10),
    Duration(seconds: 30),
    Duration(seconds: 60),
  ];

  final AppLanguage language;
  final int maxStorageBytes;
  final Duration autosaveInterval;

  AppSettings copyWith({
    AppLanguage? language,
    int? maxStorageBytes,
    Duration? autosaveInterval,
  }) {
    return AppSettings(
      language: language ?? this.language,
      maxStorageBytes: maxStorageBytes ?? this.maxStorageBytes,
      autosaveInterval: autosaveInterval ?? this.autosaveInterval,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.language == language &&
      other.maxStorageBytes == maxStorageBytes &&
      other.autosaveInterval == autosaveInterval;

  @override
  int get hashCode => Object.hash(language, maxStorageBytes, autosaveInterval);
}
