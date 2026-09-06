import 'package:shared_preferences/shared_preferences.dart';

import '../../core/services/transcription_service.dart';
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
  static const String _keyTranscriptionLanguage =
      'settings.transcriptionLanguage';

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
      transcriptionLanguage: TranscriptionLanguage.fromName(
        prefs.getString(_keyTranscriptionLanguage),
      ),
    );
  }

  Future<void> save(AppSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyLanguage, settings.language.name);
    await prefs.setInt(_keyMaxStorageBytes, settings.maxStorageBytes);
    await prefs.setInt(_keyAutosaveSeconds, settings.autosaveInterval.inSeconds);
    await prefs.setString(
      _keyTranscriptionLanguage,
      settings.transcriptionLanguage.name,
    );
  }
}
