import 'package:shared_preferences/shared_preferences.dart';

import '../models/app_settings.dart';

/// Persists [AppSettings] in shared preferences.
///
/// Reads are defensive: a missing or malformed value falls back to the default
/// rather than throwing, so a corrupted preference store degrades to defaults
/// instead of preventing the app from launching.
class SettingsRepository {
  static const String _keyLanguage = 'settings.language';
  static const String _keyMaxStorageBytes = 'settings.maxStorageBytes';
  static const String _keyAutosaveSeconds = 'settings.autosaveSeconds';
  static const String _keySkipSilence = 'settings.skipSilence';
  static const String _keyThemeMode = 'settings.themeMode';
  // A 'settings.transcriptionLanguage' key written by an older build is simply
  // never read again. Recognition is always automatic now, so there is nothing
  // for a stored value to mean.

  Future<AppSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    final maxStorage = prefs.getInt(_keyMaxStorageBytes);
    final autosaveSeconds = prefs.getInt(_keyAutosaveSeconds);

    return AppSettings(
      language: AppLanguage.fromName(prefs.getString(_keyLanguage)),
      maxStorageBytes: (maxStorage != null && maxStorage > 0)
          ? maxStorage
          : AppSettings.defaultMaxStorageBytes,
      autosaveInterval: (autosaveSeconds != null && autosaveSeconds > 0)
          ? Duration(seconds: autosaveSeconds)
          : AppSettings.defaultAutosaveInterval,
      skipSilence:
          prefs.getBool(_keySkipSilence) ?? AppSettings.defaultSkipSilence,
      themeMode: AppThemeMode.fromName(prefs.getString(_keyThemeMode)),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, settings.language.name);
    await prefs.setInt(_keyMaxStorageBytes, settings.maxStorageBytes);
    await prefs.setInt(_keyAutosaveSeconds, settings.autosaveInterval.inSeconds);
    await prefs.setBool(_keySkipSilence, settings.skipSilence);
    await prefs.setString(_keyThemeMode, settings.themeMode.name);
  }
}
