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

  Future<void> setSkipSilence(bool skip) =>
      _update(state.copyWith(skipSilence: skip));

  Future<void> setThemeMode(AppThemeMode mode) =>
      _update(state.copyWith(themeMode: mode));

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


/// The home screen's search query, over today's recordings. Empty means "show
/// everything from today".
final searchQueryProvider = StateProvider<String>((ref) => '');

/// The day History is filtered to, or null for the whole archive.
///
/// Held here rather than in the screen so a round trip into a recording and
/// back does not silently widen the list the user narrowed.
final historySelectedDayProvider = StateProvider<DateTime?>((ref) => null);

/// History's search query, over every recording ever made.
///
/// Separate from [searchQueryProvider] so the two fields never filter each
/// other: each one's scope has to match the list drawn under it.
final historySearchQueryProvider = StateProvider<String>((ref) => '');
