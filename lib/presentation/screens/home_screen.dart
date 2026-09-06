import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/audio_recording_service.dart';
import '../../core/services/recording_session_channel.dart';
import '../../core/utils/app_theme.dart';
import '../../l10n/app_localizations.dart';
import '../providers/recordings_provider.dart';
import '../providers/service_providers.dart';
import '../providers/settings_provider.dart';
import '../widgets/record_button.dart';
import '../widgets/recording_tile.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _isRecording = false;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Stop tapped in the Android foreground-service notification. Dart owns the
    // recorder and the file being written, so the platform side only forwards
    // the intent and the teardown happens here.
    RecordingSessionChannel.setStopRequestedHandler(() {
      if (_isRecording) _toggleRecording();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    RecordingSessionChannel.setStopRequestedHandler(null);
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    final recorder = ref.read(audioRecordingServiceProvider);

    if (_isRecording) {
      await recorder.stopRecording();
      _onRecordingEnded();
      await ref.read(recordingsProvider.notifier).refresh();
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final settings = ref.read(settingsProvider);

    // Budget for this recording: the cap from settings minus what recordings
    // already occupy. Recording stops when this runs out rather than evicting
    // anything — deleting a user's audio to make room for more is not a
    // decision the app gets to make silently.
    final used = await ref.read(recordingRepositoryProvider).totalBytes();
    final available = settings.maxStorageBytes - used;
    if (available <= 0) {
      if (!mounted) return;
      _showStorageFull(l10n, settings.maxStorageBytes);
      return;
    }

    final path = await recorder.startRecording(
      availableBytes: available,
      flushInterval: settings.autosaveInterval,
      notification: RecordingNotificationText(
        title: l10n.appTitle,
        body: l10n.notificationRecording,
        stopLabel: l10n.stop,
      ),
      onStopped: _onStoppedByItself,
    );

    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.micPermissionRequired)),
      );
      return;
    }
    setState(() {
      _isRecording = true;
      _elapsed = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = recorder.elapsed);
    });
  }

  /// The recording ended without the user tapping stop — the storage cap was
  /// reached, or the audio stream was interrupted. Audio up to that point is
  /// kept either way.
  void _onStoppedByItself(RecordingResult result) {
    if (!mounted) return;
    _onRecordingEnded();
    ref.read(recordingsProvider.notifier).refresh();
    final l10n = AppLocalizations.of(context)!;
    if (result.reason == RecordingStopReason.storageFull) {
      _showStorageFull(l10n, ref.read(settingsProvider).maxStorageBytes);
    }
  }

  void _onRecordingEnded() {
    _timer?.cancel();
    _timer = null;
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _elapsed = Duration.zero;
    });
  }

  void _showStorageFull(AppLocalizations l10n, int limitBytes) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n.storageFullBody(formatBytes(limitBytes))),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final recordingsAsync = ref.watch(recordingsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined,
                color: AppTheme.textSecondary),
            tooltip: l10n.settings,
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const SettingsScreen(),
              ),
            ),
          ),
        ],
        title: Text(
          l10n.appTitle,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: Column(
          // The record bar is a full-width bottom bar (it draws a top border
          // across the screen). Column defaults to CrossAxisAlignment.center,
          // which would shrink it to the intrinsic width of its contents and
          // leave it floating as a narrow card.
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: recordingsAsync.when(
                loading: () =>
                    const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text(l10n.loadFailed('$e'))),
                data: (recordings) {
                  if (recordings.isEmpty) return const _EmptyState();
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: recordings.length,
                    itemBuilder: (context, i) =>
                        RecordingTile(recording: recordings[i]),
                  );
                },
              ),
            ),
            _RecordBar(
              tapToRecordLabel: l10n.tapToRecord,
              isRecording: _isRecording,
              elapsedLabel: _formatElapsed(_elapsed),
              onTap: _toggleRecording,
            ),
          ],
        ),
      ),
    );
  }
}

class _RecordBar extends StatelessWidget {
  const _RecordBar({
    required this.tapToRecordLabel,
    required this.isRecording,
    required this.elapsedLabel,
    required this.onTap,
  });

  final String tapToRecordLabel;
  final bool isRecording;
  final String elapsedLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.borderLight)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 22,
            child: isRecording
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const _RecPulse(),
                      const SizedBox(width: 8),
                      Text(
                        elapsedLabel,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  )
                : Text(
                    tapToRecordLabel,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
          ),
          const SizedBox(height: 10),
          RecordButton(isRecording: isRecording, onTap: onTap),
        ],
      ),
    );
  }
}

class _RecPulse extends StatelessWidget {
  const _RecPulse();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: const BoxDecoration(
        color: AppTheme.recordRed,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.mic_none_rounded, size: 56, color: AppTheme.textHint),
          const SizedBox(height: 12),
          Text(
            l10n.noRecordingsTitle,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.noRecordingsBody,
            style: const TextStyle(fontSize: 13, color: AppTheme.textHint),
          ),
        ],
      ),
    );
  }
}
