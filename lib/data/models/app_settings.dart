import 'package:flutter/widgets.dart';

import '../../core/services/transcription_service.dart';

/// The UI languages Momera.Audio ships.
///
/// These mirror the five languages the speech model can transcribe, so the
/// interface is never offered in a language whose audio the app cannot
/// actually handle. Cantonese has no separate written locale — Hong Kong and
/// Macau read Traditional Chinese — so it maps to [chineseTraditional].
///
/// [system] follows the device language, falling back to English when the
/// device language is not one we translate.
enum AppLanguage {
  system(null),
  english(Locale('en')),
  // gen-l10n emits Simplified Chinese as plain `zh` (from app_zh.arb), not
  // `zh-Hans`. Using `zh-Hans` here would hand MaterialApp a locale that is
  // not in AppLocalizations.supportedLocales.
  chineseSimplified(Locale('zh')),
  chineseTraditional(Locale.fromSubtags(languageCode: 'zh', scriptCode: 'Hant')),
  japanese(Locale('ja')),
  korean(Locale('ko'));

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
    this.transcriptionLanguage = TranscriptionLanguage.auto,
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

  /// Which language the recogniser is told to expect. `auto` detects per
  /// speech segment, which is what makes a conversation that switches language
  /// transcribe correctly; pinning a language helps when content is known to
  /// be monolingual.
  final TranscriptionLanguage transcriptionLanguage;

  AppSettings copyWith({
    AppLanguage? language,
    int? maxStorageBytes,
    Duration? autosaveInterval,
    TranscriptionLanguage? transcriptionLanguage,
  }) {
    return AppSettings(
      language: language ?? this.language,
      maxStorageBytes: maxStorageBytes ?? this.maxStorageBytes,
      autosaveInterval: autosaveInterval ?? this.autosaveInterval,
      transcriptionLanguage:
          transcriptionLanguage ?? this.transcriptionLanguage,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is AppSettings &&
      other.language == language &&
      other.maxStorageBytes == maxStorageBytes &&
      other.autosaveInterval == autosaveInterval &&
      other.transcriptionLanguage == transcriptionLanguage;

  @override
  int get hashCode => Object.hash(
        language,
        maxStorageBytes,
        autosaveInterval,
        transcriptionLanguage,
      );
}
