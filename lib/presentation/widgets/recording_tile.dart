import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/audio/waveform.dart';
import '../../core/search/recording_search.dart';
import '../../core/services/audio_playback_service.dart';
import '../../core/services/transcription_service.dart';
import '../../core/utils/app_theme.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/recording.dart';
import '../../data/repositories/recording_repository.dart';
import '../../l10n/app_localizations.dart';
import '../providers/capability_provider.dart';
import '../providers/recordings_provider.dart';
import '../providers/service_providers.dart';
import '../providers/waveform_provider.dart';
import 'model_download_sheet.dart';
import 'waveform_bar.dart';

/// Fixed `yyyy-MM-dd HH:mm:ss`, 24-hour, in every language.
///
/// Deliberately *not* locale-aware. Recordings are identified by when they were
/// made, so a single unambiguous, sortable format that reads the same in every
/// language beats localised month names and AM/PM.
String formatCreatedAt(DateTime when) =>
    DateFormat('yyyy-MM-dd HH:mm:ss').format(when);

/// The date half of [formatCreatedAt], for History's day headers. Fixed and
/// non-localised for the same reason.
String formatDay(DateTime when) => DateFormat('yyyy-MM-dd').format(when);

/// Display name for a speech-recognition language.
///
/// These are the five the SenseVoice checkpoint actually supports, which is not
/// the same set as the five the UI is translated into: the model handles
/// Mandarin, Cantonese, English, Japanese and Korean, while the UI ships in
/// English, both Chinese scripts, Japanese and Korean.
///
/// Only ever labels languages the recogniser *detected*, now that recognition
/// is always automatic. `TranscriptionLanguage.fromTag` never yields `auto`, so
/// that arm is unreachable in practice; it is here to keep the switch total.
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

/// A single recording row: play/pause, metadata, transcript, and actions.
class RecordingTile extends ConsumerStatefulWidget {
  const RecordingTile({
    super.key,
    required this.recording,
    this.hits = const [],
    this.alternate = false,
  });

  final Recording recording;

  /// Whether this is an odd row, which is painted a shade off [AppColors.surface]
  /// so a long list can be read across without counting. Banding, not striping:
  /// the difference should register as texture rather than as a table.
  final bool alternate;

  /// Search hits inside this recording. Rendered as tappable snippets that
  /// seek playback to the moment the words were spoken.
  final List<SearchHit> hits;

  @override
  ConsumerState<RecordingTile> createState() => _RecordingTileState();
}

class _RecordingTileState extends ConsumerState<RecordingTile> {
  bool _transcribing = false;
  double _progress = 0;

  /// Where the finger is while scrubbing the waveform, overriding the played
  /// position. Null when not scrubbing.
  ///
  /// Held here rather than seeking continuously: dragging fires at display
  /// rate, and seeking on every update would hammer the player sixty times a
  /// second. The audio jumps once, on release.
  double? _scrubFraction;

  Recording get _recording => widget.recording;

  bool get _isThisPlaying {
    final playback = ref.read(audioPlaybackServiceProvider);
    return playback.currentlyPlaying == _recording.path;
  }

  /// Refuse to start playback while a recording is in progress, and say why.
  ///
  /// Capture and playback cannot share the audio route: on iOS `just_audio`
  /// activates its own `.playback` session, taking the session away from the
  /// recorder mid-recording, and on any device the speaker bleeds into the
  /// microphone. Refusing out loud beats a play button that does nothing.
  bool _refusedWhileRecording() {
    if (!ref.read(isRecordingProvider)) return false;
    _showSnack(AppLocalizations.of(context)!.playbackBlockedWhileRecording);
    return true;
  }

  /// Play this recording from the moment a search hit was spoken.
  Future<void> _playFrom(Duration position) async {
    if (_refusedWhileRecording()) return;
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
    if (_refusedWhileRecording()) return;
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
    } on TranscriptionBusyException {
      if (mounted) _showSnack(l10n.liveBusy);
    } on SttNativeUnavailableException {
      // Permanent. Re-resolving the capability is what makes the button
      // disappear rather than sit there failing every time it is tapped.
      if (mounted) {
        invalidateCapabilities(ref);
        _showSnack(l10n.transcriptionLoadFailed);
      }
    } on SttModelLoadFailedException {
      if (mounted) {
        invalidateCapabilities(ref);
        _showSnack(l10n.transcriptionLoadFailed);
      }
    } catch (_) {
      if (mounted) _showSnack(l10n.transcriptionFailed);
    } finally {
      if (mounted) setState(() => _transcribing = false);
    }
  }

  /// Ask before discarding a transcript: producing one is minutes of CPU, and
  /// a mis-tap in a menu must not silently destroy it.
  Future<void> _confirmRemoveTranscript() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(AppLocalizations.of(ctx)!.removeTranscriptTitle),
        content: Text(AppLocalizations.of(ctx)!.removeTranscriptBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(AppLocalizations.of(ctx)!.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(AppLocalizations.of(ctx)!.removeTranscript,
                style: TextStyle(color: AppTheme.of(ctx).recordRed)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(recordingsProvider.notifier).removeTranscript(_recording);
    if (mounted) _showSnack(l10n.transcriptRemoved);
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
                style: TextStyle(color: AppTheme.of(ctx).recordRed)),
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

  Future<void> _rename() async {
    final l10n = AppLocalizations.of(context)!;

    // The controller belongs to the dialog's own State, not to this method.
    // `showDialog`'s future completes the moment the route is popped, while the
    // dialog keeps rebuilding through its exit animation — so disposing the
    // controller here would leave the still-animating TextField holding a dead
    // one, which throws on both Cancel and Save.
    final newName = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(
        initialName: _recording.customName ?? _recording.baseName,
      ),
    );
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
    final colors = AppTheme.of(context);
    final playback = ref.watch(audioPlaybackServiceProvider);
    final r = _recording;
    final l10n = AppLocalizations.of(context)!;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: widget.alternate ? colors.rowAlternate : colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r.customName ?? formatCreatedAt(r.createdAt),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textPrimary,
                      ),
                    ),
                    // The duration now sits on the waveform, so this second
                    // line only earns its space when a name has displaced the
                    // timestamp from the title.
                    if (r.customName != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        formatCreatedAt(r.createdAt),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Actions on the recording itself. Transcript actions live on
              // the transcript block below, so each section owns exactly what
              // it can act on.
              _IconAction(
                icon: Icons.edit_outlined,
                tooltip: l10n.rename,
                onTap: _rename,
                size: 32,
                iconSize: 18,
                color: colors.textSecondary,
              ),
              _IconAction(
                icon: Icons.ios_share_rounded,
                tooltip: l10n.shareAudio,
                onTap: _shareAudio,
                size: 32,
                iconSize: 18,
                color: colors.textSecondary,
              ),
              _IconAction(
                icon: Icons.delete_outline_rounded,
                tooltip: l10n.delete,
                onTap: _confirmDelete,
                size: 32,
                iconSize: 18,
                color: colors.recordRed,
              ),
            ],
          ),
          _WaveformRow(
            recording: r,
            playback: playback,
            scrubFraction: _scrubFraction,
            onScrub: (fraction) => setState(() => _scrubFraction = fraction),
            onTogglePlay: _togglePlay,
            onSeek: (position) {
              setState(() => _scrubFraction = null);
              _playFrom(position);
            },
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
                        Icon(Icons.play_circle_outline_rounded,
                            size: 16, color: colors.accent),
                        const SizedBox(width: 8),
                        Text(
                          formatDuration(hit.segment!.start),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: colors.accent,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            hit.segment!.text,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.35,
                              color: colors.textPrimary,
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
                    style: TextStyle(
                        fontSize: 12, color: colors.textHint),
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
                    color: colors.textHint,
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
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.textHint,
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
                color: colors.background,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.transcriptLabel,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                      _IconAction(
                        icon: Icons.copy_rounded,
                        tooltip: l10n.copyTranscript,
                        onTap: _copyTranscript,
                        color: colors.textSecondary,
                      ),
                      _IconAction(
                        icon: Icons.ios_share_rounded,
                        tooltip: l10n.shareTranscript,
                        onTap: _shareTranscript,
                        color: colors.textSecondary,
                      ),
                      // Copy, share and remove stay available wherever a
                      // transcript exists, even where the device cannot
                      // transcribe: the gate is on *producing* text, not on
                      // reading text that already exists — a restored backup
                      // must not lose access to its own transcript.
                      //
                      // Remove is disabled mid-run, or an in-flight write would
                      // land after the delete and recreate the sidecar.
                      _IconAction(
                        icon: Icons.close_rounded,
                        tooltip: l10n.removeTranscript,
                        onTap: _transcribing ? null : _confirmRemoveTranscript,
                        color: colors.recordRed,
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  // Selectable, so a user can lift a quote out without copying
                  // the whole thing. Deliberately SelectableText per block
                  // rather than a SelectionArea higher up: the search-hit
                  // snippets above are Text inside an InkWell whose whole job
                  // is tap-to-seek, and a SelectionArea over them would turn
                  // that tap into a drag.
                  SelectableText(
                    r.transcript!,
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.4,
                      color: colors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            // Offered only where the device can actually run the model. A
            // device that is merely missing the download still sees this — the
            // button is how it starts that download.
          ] else if (watchTranscriptionVisible(ref)) ...[
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
                  foregroundColor: colors.accent,
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

/// The play control, the waveform strip and its playback fill.
///
/// Split out so the position `StreamBuilder` wraps *only* the strip. Hoisting it
/// to the whole tile would rebuild the transcript's SelectableText — selection
/// overlay, gesture recognisers and all — several times a second for every
/// visible recording while audio plays. For the same reason the play button's
/// own `playerState` stream sits *outside* the position stream: it changes when
/// playback starts or stops, not on every tick.
class _WaveformRow extends ConsumerWidget {
  const _WaveformRow({
    required this.recording,
    required this.playback,
    required this.scrubFraction,
    required this.onScrub,
    required this.onSeek,
    required this.onTogglePlay,
  });

  final Recording recording;
  final AudioPlaybackService playback;
  final double? scrubFraction;
  final ValueChanged<double?> onScrub;
  final ValueChanged<Duration> onSeek;
  final VoidCallback onTogglePlay;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final total = recording.duration;
    final peaks = ref.watch(waveformProvider(recording.path)).maybeWhen(
          data: (data) => data,
          orElse: () => null,
        );
    // Unavailable, not absent: the button stays tappable so it can explain
    // itself, but it must not look ready.
    final unavailable = ref.watch(isRecordingProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          StreamBuilder<PlayerState>(
            stream: playback.playerState,
            builder: (context, snapshot) {
              final playing = playback.currentlyPlaying == recording.path &&
                  (snapshot.data?.playing ?? false);
              return _RoundIconButton(
                icon: playing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                onTap: onTogglePlay,
                muted: unavailable,
              );
            },
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _WaveformStrip(
              recording: recording,
              playback: playback,
              peaks: peaks,
              total: total,
              l10n: l10n,
              scrubFraction: scrubFraction,
              onScrub: onScrub,
              onSeek: onSeek,
            ),
          ),
        ],
      ),
    );
  }
}

/// The strip itself. Everything under the per-frame position stream lives here.
class _WaveformStrip extends StatelessWidget {
  const _WaveformStrip({
    required this.recording,
    required this.playback,
    required this.peaks,
    required this.total,
    required this.l10n,
    required this.scrubFraction,
    required this.onScrub,
    required this.onSeek,
  });

  final Recording recording;
  final AudioPlaybackService playback;
  final PeakData? peaks;
  final Duration? total;
  final AppLocalizations l10n;
  final double? scrubFraction;
  final ValueChanged<double?> onScrub;
  final ValueChanged<Duration> onSeek;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return StreamBuilder<Duration?>(
      stream: playback.position,
      builder: (context, snapshot) {
        // Re-read which file is playing *inside* the builder. Nothing reactive
        // watches that, so a tile which stopped being the playing one has no
        // other way to find out — and would otherwise keep painting the
        // progress it had when playback moved elsewhere. This stream belongs to
        // the shared player, so every mounted tile ticks and every stale tile
        // gets the chance to clear itself.
        final isThis = playback.currentlyPlaying == recording.path;
        // Non-seeded BehaviorSubject: the first frame can arrive with no value.
        final elapsed = snapshot.data ?? Duration.zero;
        // Copied to a local: a field cannot be type-promoted by a null check.
        final total = this.total;

        final double progress;
        if (scrubFraction != null) {
          progress = scrubFraction!;
        } else if (isThis && total != null && total.inMilliseconds > 0) {
          progress = (elapsed.inMilliseconds / total.inMilliseconds)
              .clamp(0.0, 1.0);
        } else {
          progress = 0.0;
        }

        return Stack(
          children: [
            Semantics(
              label: l10n.waveformSeek,
              value: total == null
                  ? null
                  : '${formatDuration(total * progress)} / '
                      '${formatDuration(total)}',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  void report(double dx, {required bool commit}) {
                    if (total == null || constraints.maxWidth <= 0) return;
                    final fraction =
                        (dx / constraints.maxWidth).clamp(0.0, 1.0);
                    if (commit) {
                      onSeek(total * fraction);
                    } else {
                      onScrub(fraction);
                    }
                  }

                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapDown: (d) => report(d.localPosition.dx, commit: true),
                    // Horizontal only, so the list keeps its vertical drag.
                    onHorizontalDragUpdate: (d) =>
                        report(d.localPosition.dx, commit: false),
                    onHorizontalDragEnd: (_) {
                      final fraction = scrubFraction;
                      onScrub(null);
                      if (fraction != null && total != null) {
                        onSeek(total * fraction);
                      }
                    },
                    onHorizontalDragCancel: () => onScrub(null),
                    // Taller than the 36 default to leave the readout room to
                    // sit over the bars without burying them.
                    child: WaveformBar(
                      peaks: peaks,
                      progress: progress,
                      height: 44,
                    ),
                  );
                },
              ),
            ),
            // Length centred over the strip. While this recording plays it
            // becomes a position readout; the pill keeps it legible over the
            // bars, and being an overlay it costs the row no height and does
            // not resize the strip when playback starts.
            if (total != null)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.surface.withValues(alpha: 0.9),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1),
                        child: Text(
                          isThis
                              ? '${formatDuration(elapsed)} / '
                                  '${formatDuration(total)}'
                              : formatDuration(total),
                          style: TextStyle(
                            fontSize: 11,
                            color: colors.textSecondary,
                            // Digits must not jitter as the seconds tick over.
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Rename prompt.
///
/// A `StatefulWidget` purely so the `TextEditingController` is owned by an
/// element whose lifetime matches the dialog's. `State.dispose` runs once the
/// route is gone, not when it starts animating out.
class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initialName});

  final String initialName;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialName);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.renameTitle),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(labelText: l10n.renameHint),
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(l10n.cancel),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(l10n.save),
        ),
      ],
    );
  }
}

/// A compact icon action for a section's top-right corner.
///
/// A default `IconButton` is 48x48 and would dominate a content block's header,
/// so the constraints and padding are pinned rather than left to Material. The
/// defaults are the in-block size; the tile header passes a slightly larger one.
///
/// A null [onTap] disables the button, which Material renders greyed out.
class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.color,
    this.size = 28,
    this.iconSize = 16,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;

  /// Null means the accent colour of the active theme, which a default value
  /// cannot express: defaults must be compile-time constants, and the palette
  /// is now resolved from the context.
  final Color? color;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      tooltip: tooltip,
      icon: Icon(icon, size: iconSize),
      color: color ?? AppTheme.of(context).accent,
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: BoxConstraints.tightFor(width: size, height: size),
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    this.muted = false,
  });

  final IconData icon;
  final VoidCallback onTap;

  /// Drawn as unavailable while still accepting taps, so tapping can explain
  /// why it is unavailable instead of the button ignoring the finger.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Material(
      color: muted ? colors.borderLight : colors.accentLight,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(
            icon,
            color: muted ? colors.textHint : colors.accent,
            size: 26,
          ),
        ),
      ),
    );
  }
}
