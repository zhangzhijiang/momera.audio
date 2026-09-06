import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/search/recording_search.dart';
import '../../core/services/transcription_service.dart';
import '../../core/translation/translation_service.dart';
import '../../core/translation/translator.dart';
import '../../core/utils/app_theme.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/recording.dart';
import '../../data/repositories/recording_repository.dart';
import '../screens/settings_screen.dart' show transcriptionLanguageLabel;
import '../../l10n/app_localizations.dart';
import '../providers/recordings_provider.dart';
import '../providers/service_providers.dart';
import '../providers/settings_provider.dart';
import 'model_download_sheet.dart';

/// A single recording row: play/pause, metadata, transcript, and actions.
/// Fixed `yyyy-MM-dd HH:mm:ss`, 24-hour, in every language.
///
/// Deliberately *not* locale-aware. Recordings are identified by when they were
/// made, so a single unambiguous, sortable format that reads the same in every
/// language beats localised month names and AM/PM.
String formatCreatedAt(DateTime when) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(when);

class RecordingTile extends ConsumerStatefulWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    this.hits = const [],
  });

  final Recording recording;

  /// Search hits inside this recording. Rendered as tappable snippets that
  /// seek playback to the moment the words were spoken.
  final List<SearchHit> hits;

  @override
  ConsumerState<RecordingTile> createState() => _RecordingTileState();
}

class _RecordingTileState extends ConsumerState<RecordingTile> {
  bool _transcribing = false;
  bool _translating = false;
  double _progress = 0;

  Recording get _recording => widget.recording;

  bool get _isThisPlaying {
    final playback = ref.read(audioPlaybackServiceProvider);
    return playback.currentlyPlaying == _recording.path;
  }

  /// Play this recording from the moment a search hit was spoken.
  Future<void> _playFrom(Duration position) async {
    final l10n = AppLocalizations.of(context)!;
    final playback = ref.read(audioPlaybackServiceProvider);
    try {
      if (!_isThisPlaying) {
        await playback.play(_recording.path);
      }
      await playback.seek(position);
      if (!playback.isPlaying) await playback.resume();
    } catch (_) {
      if (mounted) _showSnack(l10n.playbackFailed);
    }
    if (mounted) setState(() {});
  }

  Future<void> _togglePlay() async {
    final l10n = AppLocalizations.of(context)!;
    final playback = ref.read(audioPlaybackServiceProvider);
    if (_isThisPlaying && playback.isPlaying) {
      await playback.pause();
    } else if (_isThisPlaying) {
      await playback.resume();
    } else {
      try {
        await playback.play(_recording.path);
      } catch (_) {
        if (mounted) _showSnack(l10n.playbackFailed);
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _transcribe() async {
    // Captured before the first await: reading it after an async gap risks a
    // deactivated context.
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(transcriptionServiceProvider);

    // Ensure the model is downloaded + the service initialized.
    if (!await service.isModelReady()) {
      if (!mounted) return;
      final ok = await showModelDownloadSheet(context);
      if (ok != true) return;
    }

    setState(() {
      _transcribing = true;
      _progress = 0;
    });
    try {
      final result = await service.transcribeFile(
        _recording.path,
        language: ref.read(settingsProvider).transcriptionLanguage,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await ref.read(recordingsProvider.notifier).setTranscript(
            _recording,
            result.text,
            languages: result.languages,
            segments: result.segments,
          );
      if (mounted && result.isEmpty) {
        _showSnack(l10n.noSpeechDetected);
      }
    } on ModelNotReadyException {
      if (mounted) _showSnack(l10n.modelNotReady);
    } catch (_) {
      if (mounted) _showSnack(l10n.transcriptionFailed);
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  Future<void> _confirmDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.deleteRecordingTitle),
        content: Text(AppLocalizations.of(ctx)!.deleteRecordingBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.delete,
                style: TextStyle(color: Colors.red.shade400)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    final playback = ref.read(audioPlaybackServiceProvider);
    if (_isThisPlaying) await playback.stop();
    await ref.read(recordingsProvider.notifier).delete(_recording);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  /// Ask for a target language, then translate the transcript into it.
  Future<void> _translate() async {
    final l10n = AppLocalizations.of(context)!;
    final service = ref.read(translationServiceProvider);

    // ML Kit needs one definite source language. A recording with none, or
    // with several, cannot be handed to it — say so rather than guessing.
    final source = TranslationService.sourceFor(_recording.languages);
    if (source == null) {
      _showSnack(l10n.translationSourceUnknown);
      return;
    }
    if (source == TranslationLanguage.cantonese) {
      _showSnack(l10n.translationCantonese);
      return;
    }

    final available = await service.supportedTargets();
    if (!mounted) return;

    final target = await showModalBottomSheet<TranslationLanguage>(
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
                l10n.translateTo,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final language in TranslationLanguage.values)
                    if (language != source)
                      ListTile(
                        enabled: available.contains(language),
                        title: Text(
                          translationLanguageLabel(l10n, language),
                          style: TextStyle(
                            fontSize: 15,
                            color: available.contains(language)
                                ? AppTheme.textPrimary
                                : AppTheme.textHint,
                          ),
                        ),
                        // Cantonese is listed but disabled: it is the concrete
                        // reason the online engine slot exists.
                        subtitle: language == TranslationLanguage.cantonese
                            ? Text(
                                l10n.translationCantonese,
                                style: const TextStyle(
                                    fontSize: 11, color: AppTheme.textHint),
                              )
                            : null,
                        trailing:
                            _recording.translations.containsKey(language)
                                ? const Icon(Icons.check_rounded,
                                    color: AppTheme.accent, size: 20)
                                : null,
                        onTap: () => Navigator.of(sheetContext).pop(language),
                      ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (target == null || !mounted) return;

    setState(() => _translating = true);
    try {
      final outcome = await service.translate(
        _recording.transcript ?? '',
        from: source,
        to: target,
      );
      await ref
          .read(recordingsProvider.notifier)
          .addTranslation(_recording, outcome);
    } on TranslationException catch (e) {
      if (mounted) {
        _showSnack(e.reason == TranslationFailure.unsupportedPair
            ? l10n.translationUnsupported
            : l10n.translationFailed);
      }
    } catch (_) {
      if (mounted) _showSnack(l10n.translationFailed);
    } finally {
      if (mounted) setState(() => _translating = false);
    }
  }

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context)!;
    final controller =
        TextEditingController(text: _recording.customName ?? _recording.baseName);

    final newName = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.renameTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(labelText: l10n.renameHint),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newName == null) return;

    if (RecordingRepository.sanitizeFileName(newName).isEmpty) {
      if (mounted) _showSnack(l10n.renameEmpty);
      return;
    }
    try {
      await ref.read(recordingsProvider.notifier).rename(_recording, newName);
    } on RenameCollisionException {
      if (mounted) _showSnack(l10n.renameExists);
    } catch (_) {
      if (mounted) _showSnack(l10n.renameFailed);
    }
  }

  Future<void> _copyTranscript() async {
    final l10n = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: _recording.transcript ?? ''));
    if (mounted) _showSnack(l10n.copied);
  }

  /// The share sheet needs an anchor rect on iPad, where it is presented as a
  /// popover rather than a modal. Harmless elsewhere.
  Rect? _shareOrigin() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  String get _shareSubject =>
      _recording.customName ?? formatCreatedAt(_recording.createdAt);

  Future<void> _shareAudio() async {
    final l10n = AppLocalizations.of(context)!;
    final origin = _shareOrigin();
    try {
      await Share.shareXFiles(
        [XFile(_recording.path, mimeType: 'audio/wav')],
        subject: _shareSubject,
        sharePositionOrigin: origin,
      );
    } catch (_) {
      if (mounted) _showSnack(l10n.shareFailed);
    }
  }

  Future<void> _shareTranscript() async {
    final l10n = AppLocalizations.of(context)!;
    final text = _recording.transcript?.trim() ?? '';
    // Share.share asserts on empty text, so an untranscribed recording must
    // never reach it.
    if (text.isEmpty) return;
    final origin = _shareOrigin();
    try {
      await Share.share(
        text,
        subject: _shareSubject,
        sharePositionOrigin: origin,
      );
    } catch (_) {
      if (mounted) _showSnack(l10n.shareFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final playback = ref.watch(audioPlaybackServiceProvider);
    final r = _recording;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StreamBuilder<PlayerState>(
                stream: playback.playerState,
                builder: (context, snapshot) {
                  final playing =
                      _isThisPlaying && (snapshot.data?.playing ?? false);
                  return _RoundIconButton(
                    icon: playing
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    onTap: _togglePlay,
                  );
                },
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.customName ?? formatCreatedAt(r.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      // A renamed recording still needs its timestamp shown,
                      // since the name has replaced it above.
                      r.customName == null
                          ? formatDuration(r.duration)
                          : '${formatCreatedAt(r.createdAt)} · '
                              '${formatDuration(r.duration)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<_TileAction>(
                icon: const Icon(Icons.more_horiz_rounded,
                    size: 20, color: AppTheme.textHint),
                tooltip: null,
                onSelected: (action) {
                  switch (action) {
                    case _TileAction.rename:
                      _rename();
                    case _TileAction.translate:
                      _translate();
                    case _TileAction.copyTranscript:
                      _copyTranscript();
                    case _TileAction.shareAudio:
                      _shareAudio();
                    case _TileAction.shareTranscript:
                      _shareTranscript();
                    case _TileAction.delete:
                      _confirmDelete();
                  }
                },
                itemBuilder: (context) {
                  final l10n = AppLocalizations.of(context)!;
                  return [
                    PopupMenuItem(
                      value: _TileAction.rename,
                      child: _menuRow(Icons.edit_outlined, l10n.rename),
                    ),
                    PopupMenuItem(
                      value: _TileAction.shareAudio,
                      child: _menuRow(Icons.ios_share_rounded, l10n.shareAudio),
                    ),
                    // Transcript actions only make sense once there is one.
                    if (r.hasTranscript) ...[
                      PopupMenuItem(
                        value: _TileAction.translate,
                        child: _menuRow(Icons.translate_rounded, l10n.translate),
                      ),
                      PopupMenuItem(
                        value: _TileAction.copyTranscript,
                        child: _menuRow(
                            Icons.copy_all_outlined, l10n.copyTranscript),
                      ),
                      PopupMenuItem(
                        value: _TileAction.shareTranscript,
                        child: _menuRow(
                            Icons.text_snippet_outlined, l10n.shareTranscript),
                      ),
                    ],
                    PopupMenuItem(
                      value: _TileAction.delete,
                      child: _menuRow(
                        Icons.delete_outline_rounded,
                        l10n.delete,
                        color: Colors.red.shade400,
                      ),
                    ),
                  ];
                },
              ),
            ],
          ),
          // Search hits: one tappable line per matching phrase, showing where
          // in the recording it was said.
          if (widget.hits.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final hit in widget.hits)
              if (hit.segment != null)
                InkWell(
                  onTap: () => _playFrom(hit.segment!.start),
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: 6, horizontal: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.play_circle_outline_rounded,
                            size: 16, color: AppTheme.accent),
                        const SizedBox(width: 8),
                        Text(
                          formatDuration(hit.segment!.start),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.accent,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hit.segment!.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else if (hit.matchedName)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: Text(
                    AppLocalizations.of(context)!.searchMatchedName,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textHint),
                  ),
                ),
          ],
          if (r.hasTranscript) ...[
            // Which languages the recogniser heard. Worth surfacing because the
            // model detects per phrase, so a bilingual conversation lists more
            // than one.
            if (r.languages.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    r.isMultilingual
                        ? Icons.translate_rounded
                        : Icons.language_rounded,
                    size: 14,
                    color: AppTheme.textHint,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.detectedLanguages(
                        [
                          for (final l in r.languages)
                            transcriptionLanguageLabel(
                                AppLocalizations.of(context)!, l)
                        ].join(' · '),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textHint,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppTheme.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                r.transcript!,
                style: const TextStyle(
                  fontSize: 13,
                  height: 1.4,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            // Translations, one block per target language.
            for (final entry in r.translations.entries) ...[
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.accentLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.translationOf(
                        translationLanguageLabel(
                            AppLocalizations.of(context)!, entry.key),
                      ),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.accent,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      entry.value.text,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.4,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            if (_translating) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    AppLocalizations.of(context)!.translating,
                    style: const TextStyle(
                        fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ],
          ] else ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _transcribing ? null : _transcribe,
                icon: _transcribing
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          // Determinate once there is progress to show, so a
                          // long transcription visibly advances.
                          value: _progress > 0 ? _progress : null,
                        ),
                      )
                    : const Icon(Icons.graphic_eq_rounded, size: 18),
                label: Text(_transcribing
                    ? AppLocalizations.of(context)!
                        .transcribingPercent((_progress * 100).round())
                    : AppLocalizations.of(context)!.transcribe),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.accent,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.accentLight,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: AppTheme.accent, size: 26),
        ),
      ),
    );
  }
}


/// Overflow-menu actions on a recording.
enum _TileAction {
  rename,
  shareAudio,
  translate,
  copyTranscript,
  shareTranscript,
  delete,
}

Widget _menuRow(IconData icon, String label, {Color? color}) {
  return Row(
    children: [
      Icon(icon, size: 18, color: color ?? AppTheme.textSecondary),
      const SizedBox(width: 10),
      Text(label, style: TextStyle(fontSize: 14, color: color)),
    ],
  );
}
