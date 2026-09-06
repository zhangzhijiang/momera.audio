import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/services/transcription_service.dart';
import '../../core/utils/app_theme.dart';
import '../../core/utils/duration_format.dart';
import '../../data/models/recording.dart';
import '../../l10n/app_localizations.dart';
import '../providers/recordings_provider.dart';
import '../providers/service_providers.dart';
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
  const RecordingTile({super.key, required this.recording});

  final Recording recording;

  @override
  ConsumerState<RecordingTile> createState() => _RecordingTileState();
}

class _RecordingTileState extends ConsumerState<RecordingTile> {
  bool _transcribing = false;
  double _progress = 0;

  Recording get _recording => widget.recording;

  bool get _isThisPlaying {
    final playback = ref.read(audioPlaybackServiceProvider);
    return playback.currentlyPlaying == _recording.path;
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
      final text = await service.transcribeFile(
        _recording.path,
        onProgress: (p) {
          if (mounted) setState(() => _progress = p);
        },
      );
      await ref
          .read(recordingsProvider.notifier)
          .setTranscript(_recording, text);
      if (mounted && text.isEmpty) {
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
                      formatCreatedAt(r.createdAt),
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      formatDuration(r.duration),
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded,
                    size: 20, color: AppTheme.textHint),
                onPressed: _confirmDelete,
                tooltip: AppLocalizations.of(context)!.delete,
              ),
            ],
          ),
          if (r.hasTranscript) ...[
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
