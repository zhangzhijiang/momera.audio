import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/app_settings.dart';
import '../../data/repositories/settings_repository.dart';
import 'recordings_provider.dart';
import 'service_providers.dart';

/// Persistence for [AppSettings].
final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  return SettingsRepository();
});

/// Current settings.
///
/// Starts at the defaults so the first frame can render without waiting on
/// disk, then swaps in the stored values once loaded. That keeps `MaterialApp`
/// synchronous — an async gate here would flash a loading screen on every cold
/// start just to read three preferences.
final settingsProvider =
    NotifierProvider<SettingsNotifier, AppSettings>(SettingsNotifier.new);

class SettingsNotifier extends Notifier<AppSettings> {
  @override
  AppSettings build() {
    _load();
    return const AppSettings();
  }

  Future<void> _load() async {
    final loaded = await ref.read(settingsRepositoryProvider).load();
    if (loaded != state) state = loaded;
  }

  Future<void> setLanguage(AppLanguage language) =>
      _update(state.copyWith(language: language));

  Future<void> setMaxStorageBytes(int bytes) =>
      _update(state.copyWith(maxStorageBytes: bytes));

  Future<void> setAutosaveInterval(Duration interval) =>
      _update(state.copyWith(autosaveInterval: interval));

  Future<void> _update(AppSettings next) async {
    state = next;
    await ref.read(settingsRepositoryProvider).save(next);
  }
}


/// Bytes currently used by recordings.
///
/// Watches [recordingsProvider] so the settings screen updates after a
/// recording is added or deleted.
final storageUsedProvider = FutureProvider<int>((ref) async {
  ref.watch(recordingsProvider);
  return ref.read(recordingRepositoryProvider).totalBytes();
});
