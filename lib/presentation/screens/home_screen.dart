import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/audio_recording_service.dart';
import '../../core/search/recording_search.dart';
import '../../core/services/recording_session_channel.dart';
import '../../core/utils/app_theme.dart';
import '../../core/utils/duration_format.dart';
import '../../l10n/app_localizations.dart';
import '../providers/live_transcript_provider.dart';
import '../providers/recordings_provider.dart';
import '../providers/service_providers.dart';
import '../providers/settings_provider.dart';
import '../widgets/live_transcript_panel.dart';
import '../widgets/record_button.dart';
import '../widgets/recording_tile.dart';
import 'settings_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();

  /// Held while a live pass is running so it can be torn down without `ref`,
  /// which is not usable once this widget starts unmounting.
  AudioRecordingService? _liveRecorder;
  LiveTranscriptNotifier? _liveNotifier;

  bool _isRecording = false;
  bool _isPaused = false;
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
    _stopLive();
    _searchController.dispose();
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
    // A new recording starts with an empty live panel.
    ref.read(liveTranscriptProvider.notifier).reset();
    setState(() {
      _isRecording = true;
      _isPaused = false;
      _elapsed = Duration.zero;
    });
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = recorder.elapsed);
    });
  }

  /// Start live transcription — the user has pressed and is holding the live
  /// button.
  ///
  /// The hold is what bounds the cost: audio is only tapped, and utterances only
  /// decoded, while the finger is down. Nothing extra runs otherwise, which is
  /// why this feature does not need a background-battery story.
  Future<void> _startLive() async {
    final recorder = ref.read(audioRecordingServiceProvider);
    if (!recorder.isRecording) return;

    final l10n = AppLocalizations.of(context)!;
    final notifier = ref.read(liveTranscriptProvider.notifier);

    final started = await notifier.start(fromByteOffset: recorder.bytesWritten);
    if (!started) {
      if (!mounted) return;
      // Two reasons it can fail, and they need different advice.
      final busy = ref.read(transcriptionServiceProvider).isBusy;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(busy ? l10n.liveBusy : l10n.liveUnavailable)),
      );
      return;
    }

    // Tap the recorded audio only now, so there is zero per-chunk work when
    // live transcription is not running.
    recorder.onLiveAudio = (pcm, _) => notifier.feed(pcm);

    // Held directly rather than re-read through `ref` on the way out: teardown
    // can happen while this widget is unmounting, and failing to release then
    // would strand the shared recogniser for the rest of the session.
    _liveRecorder = recorder;
    _liveNotifier = notifier;
  }

  /// The live button was released, or recording ended under it.
  ///
  /// Reached from several directions — button release, recording ending under a
  /// held finger, and the hold button being disposed mid-press — so it must be
  /// safe to call repeatedly and while tearing down. Failing to release here
  /// would strand the shared recogniser and block the post-recording
  /// Transcribe for the rest of the session.
  void _stopLive() {
    _liveRecorder?.onLiveAudio = null;
    _liveNotifier?.stop();
    _liveRecorder = null;
    _liveNotifier = null;
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
    // Recording can end under a held finger — cap reached, interruption, or the
    // notification's Stop action — so the live pass must be torn down here too,
    // not only on button release. Leaving it running would hold the shared
    // recogniser and block the post-recording Transcribe.
    _stopLive();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _isPaused = false;
      _elapsed = Duration.zero;
    });
  }

  /// Pause or resume without ending the recording. The file and the background
  /// session stay open, so this is instant and the elapsed time simply stops
  /// advancing.
  void _togglePause() {
    final recorder = ref.read(audioRecordingServiceProvider);
    if (!recorder.isRecording) return;
    setState(() {
      if (recorder.isPaused) {
        recorder.resume();
        _isPaused = false;
      } else {
        recorder.pause();
        _isPaused = true;
      }
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

  @override
  Widget build(BuildContext context) {
    final recordingsAsync = ref.watch(recordingsProvider);
    final l10n = AppLocalizations.of(context)!;

    // A recording recovered from an interrupted session should be explained,
    // not just silently appear in the list.
    ref.listen<int>(recoveredCountProvider, (previous, count) {
      if (count <= 0) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.recoveredRecordingBody),
          duration: const Duration(seconds: 5),
        ),
      );
      ref.read(recoveredCountProvider.notifier).state = 0;
    });

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

                  final query = ref.watch(searchQueryProvider);
                  final searching = query.trim().isNotEmpty;
                  final hits = searching
                      ? const RecordingSearch().search(recordings, query)
                      : const <SearchHit>[];
                  final visible = searching
                      ? const RecordingSearch().filter(recordings, query)
                      : recordings;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _SearchField(
                        controller: _searchController,
                        hint: l10n.searchHint,
                        clearTooltip: l10n.clear,
                        onChanged: (v) =>
                            ref.read(searchQueryProvider.notifier).state = v,
                      ),
                      if (searching && visible.isEmpty)
                        Expanded(
                          child: _NoResults(
                            message: l10n.searchNoResults(query),
                            hint: l10n.searchNoResultsHint,
                          ),
                        )
                      else
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: visible.length,
                            itemBuilder: (context, i) {
                              final recording = visible[i];
                              return RecordingTile(
                                recording: recording,
                                // Hits let the tile show where the words are
                                // and seek playback to them.
                                hits: [
                                  for (final h in hits)
                                    if (h.recording.path == recording.path) h,
                                ],
                              );
                            },
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
            // Live panel sits between the list and the record bar, and only
            // exists while recording. It watches its own provider so a new
            // utterance does not rebuild the list above it.
            if (_isRecording) const LiveTranscriptPanel(),
            _RecordBar(
              tapToRecordLabel: l10n.tapToRecord,
              pausedLabel: l10n.paused,
              pauseTooltip: _isPaused ? l10n.resume : l10n.pause,
              liveTooltip: l10n.liveHold,
              isRecording: _isRecording,
              isPaused: _isPaused,
              elapsedLabel: formatDuration(_elapsed),
              onTap: _toggleRecording,
              onTogglePause: _togglePause,
              onLivePressed: _startLive,
              onLiveReleased: _stopLive,
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
    required this.pausedLabel,
    required this.pauseTooltip,
    required this.liveTooltip,
    required this.isRecording,
    required this.isPaused,
    required this.elapsedLabel,
    required this.onTap,
    required this.onTogglePause,
    required this.onLivePressed,
    required this.onLiveReleased,
  });

  final String tapToRecordLabel;
  final String pausedLabel;
  final String pauseTooltip;
  final String liveTooltip;
  final bool isRecording;
  final bool isPaused;
  final String elapsedLabel;
  final VoidCallback onTap;
  final VoidCallback onTogglePause;
  final VoidCallback onLivePressed;
  final VoidCallback onLiveReleased;

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
                      if (!isPaused) const _RecPulse(),
                      if (isPaused)
                        const Icon(Icons.pause_rounded,
                            size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        isPaused ? '$pausedLabel · $elapsedLabel' : elapsedLabel,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pause sits beside the record button and only exists while
              // recording, so the resting state stays a single obvious action.
              SizedBox(
                width: 56,
                child: isRecording
                    ? IconButton(
                        onPressed: onTogglePause,
                        tooltip: pauseTooltip,
                        icon: Icon(
                          isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 26,
                          color: AppTheme.textSecondary,
                        ),
                      )
                    : null,
              ),
              RecordButton(isRecording: isRecording, onTap: onTap),
              // Hold-to-transcribe. A hold rather than a toggle because it
              // bounds the extra CPU work to exactly as long as the user wants
              // to watch — releasing stops decoding immediately.
              SizedBox(
                width: 56,
                child: isRecording
                    ? _LiveHoldButton(
                        tooltip: liveTooltip,
                        onPressed: onLivePressed,
                        onReleased: onLiveReleased,
                      )
                    : null,
              ),
            ],
          ),
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


/// Press-and-hold control that runs live transcription only while held.
///
/// Uses raw pointer callbacks rather than a button's `onPressed` so the release
/// is detected wherever the finger goes — `onTapUp` alone would miss a drag off
/// the button, leaving the recogniser running with nothing showing it.
class _LiveHoldButton extends StatefulWidget {
  const _LiveHoldButton({
    required this.tooltip,
    required this.onPressed,
    required this.onReleased,
  });

  final String tooltip;
  final VoidCallback onPressed;
  final VoidCallback onReleased;

  @override
  State<_LiveHoldButton> createState() => _LiveHoldButtonState();
}

class _LiveHoldButtonState extends State<_LiveHoldButton> {
  bool _held = false;

  void _press() {
    if (_held) return;
    setState(() => _held = true);
    widget.onPressed();
  }

  void _release() {
    if (!_held) return;
    setState(() => _held = false);
    widget.onReleased();
  }

  @override
  void dispose() {
    // Navigating away mid-hold must not strand the live pass.
    if (_held) widget.onReleased();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Deliberately no Tooltip: a tooltip fires on long-press, which is exactly
    // the gesture that operates this control, so it would pop up over the UI
    // every single time the button is used. The panel header above already
    // carries the "hold for live text" affordance.
    return Semantics(
      button: true,
      label: widget.tooltip,
      child: Listener(
        onPointerDown: (_) => _press(),
        onPointerUp: (_) => _release(),
        onPointerCancel: (_) => _release(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _held ? AppTheme.accentLight : Colors.transparent,
          ),
          child: Icon(
            Icons.subtitles_rounded,
            size: 24,
            color: _held ? AppTheme.accent : AppTheme.textSecondary,
          ),
        ),
      ),
    );
  }
}

/// Search field pinned above the recording list.
class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.hint,
    required this.clearTooltip,
    required this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final String clearTooltip;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: const TextStyle(fontSize: 14, color: AppTheme.textPrimary),
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: const TextStyle(fontSize: 14, color: AppTheme.textHint),
          prefixIcon:
              const Icon(Icons.search_rounded, size: 20, color: AppTheme.textHint),
          suffixIcon: ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              if (value.text.isEmpty) return const SizedBox.shrink();
              return IconButton(
                icon: const Icon(Icons.close_rounded,
                    size: 18, color: AppTheme.textHint),
                tooltip: clearTooltip,
                onPressed: () {
                  controller.clear();
                  onChanged('');
                },
              );
            },
          ),
          isDense: true,
          filled: true,
          fillColor: AppTheme.surface,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults({required this.message, required this.hint});

  final String message;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.search_off_rounded,
                size: 48, color: AppTheme.textHint),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            // The most likely reason for a miss is not a typo but that the
            // recording was never transcribed. Say so.
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
            ),
          ],
        ),
      ),
    );
  }
}
