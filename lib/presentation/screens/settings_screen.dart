import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/transcription_service.dart';
import '../../core/utils/app_theme.dart';
import '../../data/models/app_settings.dart';
import '../../l10n/app_localizations.dart';
import '../providers/settings_provider.dart';

/// Language, storage limit and auto-save interval.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final settings = ref.watch(settingsProvider);
    final notifier = ref.read(settingsProvider.notifier);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(
          l10n.settings,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: ListView(
        children: [
          _SectionHeader(l10n.settingsLanguage),
          _SettingTile(
            title: l10n.settingsLanguage,
            subtitle: l10n.settingsLanguageSubtitle,
            value: _languageLabel(l10n, settings.language),
            onTap: () => _pickLanguage(context, ref, settings.language),
          ),

          _SectionHeader(l10n.settingsStorage),
          _SettingTile(
            title: l10n.settingsMaxStorage,
            subtitle: l10n.settingsMaxStorageSubtitle,
            value: formatBytes(settings.maxStorageBytes),
            footer: ref.watch(storageUsedProvider).maybeWhen(
                  data: (used) => l10n.settingsStorageUsed(
                    formatBytes(used),
                    formatBytes(settings.maxStorageBytes),
                  ),
                  orElse: () => null,
                ),
            onTap: () => _pickFromList<int>(
              context: context,
              title: l10n.settingsMaxStorage,
              options: AppSettings.storageOptions,
              selected: settings.maxStorageBytes,
              labelFor: formatBytes,
              onSelected: notifier.setMaxStorageBytes,
            ),
          ),

          _SectionHeader(l10n.settingsTranscription),
          _SettingTile(
            title: l10n.settingsTranscriptionLanguage,
            subtitle: l10n.settingsTranscriptionLanguageSubtitle,
            value: transcriptionLanguageLabel(
                l10n, settings.transcriptionLanguage),
            onTap: () => _pickFromList<TranscriptionLanguage>(
              context: context,
              title: l10n.settingsTranscriptionLanguage,
              options: TranscriptionLanguage.values,
              selected: settings.transcriptionLanguage,
              labelFor: (t) => transcriptionLanguageLabel(l10n, t),
              onSelected: notifier.setTranscriptionLanguage,
            ),
          ),

          _SectionHeader(l10n.settingsRecording),
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
        ],
      ),
    );
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
    final chosen = await showModalBottomSheet<T>(
      context: context,
      backgroundColor: AppTheme.surface,
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
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
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
                        style: const TextStyle(
                          fontSize: 15,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      trailing: option == selected
                          ? const Icon(Icons.check_rounded,
                              color: AppTheme.accent, size: 20)
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

/// Display name for a speech-recognition language.
///
/// These are the five the SenseVoice checkpoint actually supports. Note that
/// Spanish is a UI language but **not** a transcription language — the model is
/// not trained for it.
String transcriptionLanguageLabel(
  AppLocalizations l10n,
  TranscriptionLanguage language,
) {
  switch (language) {
    case TranscriptionLanguage.auto:
      return l10n.sttAuto;
    case TranscriptionLanguage.mandarin:
      return l10n.sttMandarin;
    case TranscriptionLanguage.cantonese:
      return l10n.sttCantonese;
    case TranscriptionLanguage.english:
      return l10n.sttEnglish;
    case TranscriptionLanguage.japanese:
      return l10n.sttJapanese;
    case TranscriptionLanguage.korean:
      return l10n.sttKorean;
  }
}

/// Human-readable byte size, e.g. `512 MB` / `2 GB`.
String formatBytes(int bytes) {
  const gb = 1024 * 1024 * 1024;
  const mb = 1024 * 1024;
  if (bytes >= gb) {
    final value = bytes / gb;
    // Whole numbers read better than "2.0 GB".
    return value == value.roundToDouble()
        ? '${value.round()} GB'
        : '${value.toStringAsFixed(1)} GB';
  }
  return '${(bytes / mb).round()} MB';
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
      child: Text(
        label.toUpperCase(),
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w700,
          color: AppTheme.textHint,
          letterSpacing: 0.6,
        ),
      ),
    );
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
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  /// Optional extra line below the subtitle, e.g. current storage usage.
  final String? footer;

  @override
  Widget build(BuildContext context) {
    // Material, not a coloured Container: ListTile paints its ink splash onto
    // the nearest Material ancestor, so a plain Container would swallow the
    // tap feedback.
    return Material(
      color: AppTheme.surface,
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: AppTheme.textPrimary,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                subtitle,
                style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
              ),
              if (footer != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    footer!,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
            ],
          ),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textHint, size: 20),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
