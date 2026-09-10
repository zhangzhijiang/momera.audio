import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/audio/wav.dart';
import '../../core/services/audio_recording_service.dart';
import '../../core/utils/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../data/models/app_settings.dart';
import '../../l10n/app_localizations.dart';
import '../providers/recordings_provider.dart';
import '../providers/settings_provider.dart';
import 'history_screen.dart';

/// Language, theme, auto-save interval, storage limit, and the way into
/// History.
///
/// One flat list, one line per row. Each row's explanation lives behind the ⓘ
/// beside its title rather than under it — after the first read it is noise,
/// and three sentences of grey body text made a three-row screen look dense.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        children: [
          // A header used to provide this gap; the flat list has to supply it.
          const SizedBox(height: 8),
          _SettingTile(
            title: l10n.settingsLanguage,
            subtitle: l10n.settingsLanguageSubtitle,
            value: _languageLabel(l10n, settings.language),
            onTap: () => _pickLanguage(context, ref, settings.language),
          ),
          _SettingTile(
            title: l10n.settingsTheme,
            subtitle: l10n.settingsThemeSubtitle,
            value: _themeLabel(l10n, settings.themeMode),
            onTap: () => _pickFromList<AppThemeMode>(
              context: context,
              title: l10n.settingsTheme,
              options: AppThemeMode.values,
              selected: settings.themeMode,
              labelFor: (m) => _themeLabel(l10n, m),
              onSelected: notifier.setThemeMode,
            ),
          ),
          _SettingTile(
            title: l10n.settingsAutosaveInterval,
            subtitle: l10n.settingsAutosaveIntervalSubtitle,
            value: l10n.seconds(settings.autosaveInterval.inSeconds),
            onTap: () => _pickFromList<Duration>(
              context: context,
              title: l10n.settingsAutosaveInterval,
              options: AppSettings.autosaveOptions,
              selected: settings.autosaveInterval,
              labelFor: (d) => l10n.seconds(d.inSeconds),
              onSelected: notifier.setAutosaveInterval,
            ),
          ),
          _SettingTile(
            title: l10n.settingsMaxStorage,
            subtitle: l10n.settingsMaxStorageSubtitle,
            value: formatBytes(settings.maxStorageBytes),
            // Bytes are the cap, but hours are the question a user actually
            // has: how much have I got, and how much more will fit.
            footer: _storageFooter(l10n, ref, settings.maxStorageBytes),
            onTap: () => _pickFromList<int>(
              context: context,
              title: l10n.settingsMaxStorage,
              options: AppSettings.storageOptions,
              selected: settings.maxStorageBytes,
              labelFor: formatBytes,
              onSelected: notifier.setMaxStorageBytes,
            ),
          ),
          // Not a setting but the way back to older recordings: the home
          // screen keeps only today, and this is where the rest lives. Last,
          // because it navigates away rather than changing a value.
          _SettingTile(
            title: l10n.history,
            subtitle: l10n.settingsHistorySubtitle,
            value: ref.watch(recordingsProvider).maybeWhen(
                  data: (recordings) => l10n.historyCount(recordings.length),
                  orElse: () => null,
                ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
            ),
          ),
        ],
      ),
    );
  }

  /// Storage as bytes, as audio already recorded, and as audio that still fits.
  ///
  /// Null until the byte count has been read off disk; the row simply shows no
  /// footer until then rather than flashing a zero.
  static String? _storageFooter(
    AppLocalizations l10n,
    WidgetRef ref,
    int capBytes,
  ) {
    final used = ref.watch(storageUsedProvider).valueOrNull;
    if (used == null) return null;

    // Summed from the recordings themselves rather than derived from the byte
    // count, which also includes transcript sidecars — the recorded length is a
    // fact about the audio, not about the folder.
    final recorded = ref.watch(recordingsProvider).maybeWhen(
          data: (recordings) => recordings.fold(
            Duration.zero,
            (total, r) => total + (r.duration ?? Duration.zero),
          ),
          orElse: () => null,
        );
    if (recorded == null) return null;

    // The remaining estimate deliberately uses the same byte count the cap is
    // enforced against, so "still fits" and "recording stopped" agree.
    final remaining = durationForPcmBytes(
      math.max(0, capBytes - used),
      sampleRate: AudioRecordingService.sampleRate,
      channels: AudioRecordingService.channels,
    );

    return '${l10n.settingsStorageUsed(
      formatBytes(used),
      formatBytes(capBytes),
    )}\n${l10n.settingsStorageDurations(
      _coarseDuration(l10n, recorded),
      _coarseDuration(l10n, remaining),
    )}';
  }

  /// "3 h 20 min", or minutes alone under an hour.
  ///
  /// Not [formatDuration], which is the `h:mm:ss` a stopwatch wants: at this
  /// scale seconds are noise, and a total of "11:20:07" invites being read as a
  /// time of day.
  static String _coarseDuration(AppLocalizations l10n, Duration d) {
    final hours = d.inHours;
    if (hours > 0) {
      return l10n.durationHoursMinutes(hours, d.inMinutes.remainder(60));
    }
    return l10n.durationMinutes(d.inMinutes);
  }

  String _themeLabel(AppLocalizations l10n, AppThemeMode mode) {
    switch (mode) {
      case AppThemeMode.system:
        return l10n.themeSystem;
      case AppThemeMode.light:
        return l10n.themeLight;
      case AppThemeMode.dark:
        return l10n.themeDark;
    }
  }

  String _languageLabel(AppLocalizations l10n, AppLanguage language) {
    switch (language) {
      case AppLanguage.system:
        return l10n.languageSystem;
      case AppLanguage.english:
        return l10n.languageEnglish;
      case AppLanguage.chineseSimplified:
        return l10n.languageChineseSimplified;
      case AppLanguage.chineseTraditional:
        return l10n.languageChineseTraditional;
      case AppLanguage.japanese:
        return l10n.languageJapanese;
      case AppLanguage.korean:
        return l10n.languageKorean;
    }
  }

  Future<void> _pickLanguage(
    BuildContext context,
    WidgetRef ref,
    AppLanguage current,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await _pickFromList<AppLanguage>(
      context: context,
      title: l10n.settingsLanguage,
      options: AppLanguage.values,
      selected: current,
      labelFor: (l) => _languageLabel(l10n, l),
      onSelected: ref.read(settingsProvider.notifier).setLanguage,
    );
  }

  /// Shared single-choice bottom sheet.
  Future<void> _pickFromList<T>({
    required BuildContext context,
    required String title,
    required List<T> options,
    required T selected,
    required String Function(T) labelFor,
    required void Function(T) onSelected,
  }) async {
    final colors = AppTheme.of(context);
    final chosen = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: colors.textPrimary,
                ),
              ),
            ),
            // Scrollable and shrink-wrapped: with five languages this sheet
            // overflows a short viewport (a small phone in landscape) if the
            // options are laid out unconstrained.
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      title: Text(
                        labelFor(option),
                        style: TextStyle(
                          fontSize: 15,
                          color: colors.textPrimary,
                        ),
                      ),
                      trailing: option == selected
                          ?  Icon(Icons.check_rounded,
                              color: colors.accent, size: 20)
                          : null,
                      onTap: () => Navigator.of(sheetContext).pop(option),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (chosen != null) onSelected(chosen);
  }
}

class _SettingTile extends StatelessWidget {
  const _SettingTile({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
    this.footer,
  });

  final String title;

  /// What the setting does. Not drawn inline — it is one tap away, behind the
  /// ⓘ next to [title].
  final String subtitle;

  /// The current value, or null while it is still being loaded.
  final String? value;
  final VoidCallback onTap;

  /// Optional live readout, e.g. current storage usage. Unlike [subtitle] this
  /// changes as the app is used, so it stays on screen.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    // Material, not a coloured Container: ListTile paints its ink splash onto
    // the nearest Material ancestor, so a plain Container would swallow the
    // tap feedback.
    return Material(
      color: colors.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: colors.textPrimary,
                ),
              ),
            ),
            _InfoButton(title: title, body: subtitle),
          ],
        ),
        subtitle: footer == null
            ? null
            : Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  footer!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: colors.textSecondary,
                  ),
                ),
              ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (value != null)
              Text(
                value!,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: colors.textSecondary,
                ),
              ),
            const SizedBox(width: 4),
            Icon(Icons.chevron_right_rounded,
                color: colors.textHint, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// The ⓘ beside a setting's title. Tapping it explains the setting.
///
/// Sits inside the tile's own ink well, but as a button it wins the hit test:
/// tapping the ⓘ explains, tapping anywhere else on the row opens the picker.
class _InfoButton extends StatelessWidget {
  const _InfoButton({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return IconButton(
      icon: const Icon(Icons.info_outline_rounded),
      iconSize: 16,
      color: colors.textHint,
      tooltip: l10n.settingsInfo,
      padding: EdgeInsets.zero,
      // A default IconButton reserves 48dp and would make every row taller
      // than the single line this screen is built around.
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 32, height: 32),
      onPressed: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: colors.surface,
          title: Text(
            title,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: colors.textPrimary,
            ),
          ),
          content: Text(
            body,
            style: TextStyle(
              fontSize: 14,
              color: colors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              // Flutter already translates this for every locale we ship, so
              // the button needs no key of our own.
              child: Text(MaterialLocalizations.of(dialogContext).okButtonLabel),
            ),
          ],
        ),
      ),
    );
  }
}
