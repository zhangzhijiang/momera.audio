import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/services/audio_recording_service.dart';
import '../../core/search/recording_search.dart';
import '../../core/services/recording_session_channel.dart';
import '../../core/utils/app_theme.dart';
import '../../core/utils/byte_format.dart';
import '../../core/utils/duration_format.dart';
import '../../l10n/app_localizations.dart';
import '../providers/capability_provider.dart';
import '../providers/live_transcript_provider.dart';
import '../providers/recordings_provider.dart';
import '../providers/service_providers.dart';
import '../providers/settings_provider.dart';
import '../widgets/fading_notice.dart';
import '../widgets/live_transcript_panel.dart';
import '../widgets/no_results.dart';
import '../widgets/record_button.dart';
import '../widgets/recording_tile.dart';
import '../widgets/search_field.dart';
import '../widgets/skip_silence_button.dart';
import 'history_screen.dart';
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

    // A frozen timer with no explanation reads as a crash. Say what happened,
    // and say when it is over.
    recorder.onCaptureInterrupted = (interrupted) {
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(interrupted
              ? l10n.recordingReconnecting
              : l10n.recordingResumed),
          duration: Duration(seconds: interrupted ? 10 : 2),
        ),
      );
    };

    if (path == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.micPermissionRequired)),
      );
      return;
    }
    // Playback and capture cannot share the audio route: on iOS just_audio
    // activates its own session and would take this one away mid-recording, and
    // on any device the speaker would bleed into the microphone. Tiles refuse
    // to start playback while `isRecordingProvider` is set; audio already
    // playing when the user hits record is stopped here.
    await ref.read(audioPlaybackServiceProvider).stop();
    ref.read(isRecordingProvider.notifier).state = true;

    // Apply the persisted preference to this recording. Deliberately not
    // awaited: building the detector takes a moment, and delaying the record
    // button for it would be felt. Until it attaches everything is written,
    // which is the safe direction to be wrong in.
    if (settings.skipSilence && !recorder.isSkippingSilence) {
      unawaited(recorder.setSkipSilence(true));
    }

    // A new recording starts with an empty live panel.
    ref.read(liveTranscriptProvider.notifier).reset();

    unawaited(_warmUpTranscription());
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

  /// Load the speech model now, rather than under a held finger.
  ///
  /// Unawaited and non-throwing: warming is an optimisation, and the live hold
  /// reports its own failure if this has not finished in time. Uses `read`
  /// rather than the `watch` helper because this runs outside build.
  Future<void> _warmUpTranscription() async {
    final capabilities = ref.read(deviceCapabilityServiceProvider);
    final transcription = ref.read(transcriptionServiceProvider);
    if (!(await capabilities.transcription()).isVisible) return;
    await transcription.warmUp();
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

    // Bring the panel back on press, before the await, so it is on screen
    // showing "Starting…" rather than appearing a beat later. Left shown even
    // if start() fails — vanishing again would make the button feel broken.
    notifier.showPanel();

    final started = await notifier.start(
      fromByteOffset: recorder.bytesWritten,
    );
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
  void _onStoppedByItself(
    RecordingStopReason reason,
    RecordingResult? result,
  ) {
    if (!mounted) return;
    _onRecordingEnded();
    ref.read(recordingsProvider.notifier).refresh();
    final l10n = AppLocalizations.of(context)!;
    switch (reason) {
      case RecordingStopReason.storageFull:
        _showStorageFull(l10n, ref.read(settingsProvider).maxStorageBytes);
      case RecordingStopReason.fileSizeLimit:
        // Nothing the user can change in Settings — the limit is the audio
        // file format's — so this says what happened and moves on.
        _showRecordingNotice(l10n.fileSizeLimitBody);
      case RecordingStopReason.interrupted:
        // Reached only after every reconnection attempt failed, so this is not
        // a blip the user can wait out — it needs saying.
        _showRecordingNotice(l10n.recordingInterruptedBody);
      case RecordingStopReason.writeFailed:
        // The filesystem refused a write. Distinct from storageFull, which is
        // the app's own cap: there is no setting to raise here, so the message
        // says what happened and confirms the audio so far survived.
        _showRecordingNotice(l10n.recordingWriteFailedBody);
      case RecordingStopReason.user:
        break;
    }
  }

  void _onRecordingEnded() {
    _timer?.cancel();
    _timer = null;
    ref.read(audioRecordingServiceProvider).onCaptureInterrupted = null;
    // Re-enables playback on every tile, wherever it is on screen.
    ref.read(isRecordingProvider.notifier).state = false;
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

  /// Turn silence-skipping on or off, and say what changed.
  ///
  /// The recorder is told first: if this device cannot run a detector, the
  /// preference must not be stored, because a pill reading "on" over a
  /// recording that keeps every sample is a lie.
  Future<void> _toggleSkipSilence() async {
    final l10n = AppLocalizations.of(context)!;
    final recorder = ref.read(audioRecordingServiceProvider);
    final wanted = !ref.read(settingsProvider).skipSilence;

    final ok = await recorder.setSkipSilence(wanted);
    if (!mounted) return;
    if (!ok) {
      // A SnackBar rather than the fading notice: this is a failure the user
      // may want to read twice, and every other failure here is a SnackBar.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.skipSilenceUnavailable)),
      );
      return;
    }

    await ref.read(settingsProvider.notifier).setSkipSilence(wanted);
    if (!mounted) return;
    showFadingNotice(
      context,
      icon: wanted ? Icons.graphic_eq_rounded : Icons.multitrack_audio_rounded,
      title: wanted ? l10n.skipSilenceOnTitle : l10n.skipSilenceOffTitle,
      subtitle: wanted ? l10n.skipSilenceOnBody : l10n.skipSilenceOffBody,
    );
  }

  void _showStorageFull(AppLocalizations l10n, int limitBytes) {
    _showRecordingNotice(l10n.storageFullBody(formatBytes(limitBytes)));
  }

  /// Explain why a recording ended on its own. Held long enough to read, since
  /// the user was not looking at the screen when it happened.
  void _showRecordingNotice(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final recordingsAsync = ref.watch(recordingsProvider);
    final l10n = AppLocalizations.of(context)!;
    // Whether this device can run transcription at all. Recording, playback,
    // rename, share and name-search are the baseline and never depend on it.
    final sttVisible = watchTranscriptionVisible(ref);
    // `.select` is load-bearing: a bare watch here would rebuild the recordings
    // list, re-run the search and rebuild every waveform on each decoded
    // utterance — exactly what LiveTranscriptPanel is a leaf Consumer to avoid.
    final liveDismissed =
        ref.watch(liveTranscriptProvider.select((s) => s.dismissed));
    // `.select` for the same reason as above: the whole settings object changes
    // for reasons this bar does not care about.
    final skipSilence =
        ref.watch(settingsProvider.select((s) => s.skipSilence));

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
      backgroundColor: colors.background,
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(Icons.settings_outlined,
                color: colors.textSecondary),
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
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: colors.textPrimary,
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
                data: (all) {
                  if (all.isEmpty) return const _EmptyState();

                  // The home list is today's work, not an archive. Everything
                  // older is one tap away in History, so nothing is hidden —
                  // it is just not in the way of the next recording.
                  final recordings = recordedToday(all);
                  if (recordings.isEmpty) return const _NothingToday();

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
                      SearchField(
                        controller: _searchController,
                        // Without transcription, search still matches recording
                        // names — so the field stays, but must not advertise
                        // searching speech this device cannot produce.
                        hint: sttVisible
                            ? l10n.searchHint
                            : l10n.searchHintNamesOnly,
                        clearTooltip: l10n.clear,
                        onChanged: (v) =>
                            ref.read(searchQueryProvider.notifier).state = v,
                      ),
                      // States the scope of the list below it, so a missing
                      // older recording reads as "not today" rather than
                      // "gone".
                      _TodayHeader(label: l10n.today),
                      if (searching && visible.isEmpty)
                        Expanded(
                          child: NoResults(
                            message: l10n.searchNoResults(query),
                            // The likeliest reason for a miss here is not a
                            // typo or a missing transcript but the scope: the
                            // recording is older than today.
                            hint: l10n.searchNoResultsHintToday,
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
                                alternate: i.isOdd,
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
            if (_isRecording && sttVisible && !liveDismissed)
              const LiveTranscriptPanel(),
            _RecordBar(
              liveEnabled: sttVisible,
              skipSilence: skipSilence,
              skipSilenceTooltip: l10n.skipSilence,
              onToggleSkipSilence: _toggleSkipSilence,
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
    required this.liveEnabled,
    required this.skipSilence,
    required this.skipSilenceTooltip,
    required this.onToggleSkipSilence,
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

  /// Whether the hold-for-live-text button should exist. False on a device
  /// that cannot run the speech model.
  final bool liveEnabled;

  /// Whether silence is being dropped rather than recorded.
  final bool skipSilence;

  final String skipSilenceTooltip;
  final VoidCallback onToggleSkipSilence;

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
    final colors = AppTheme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border(top: BorderSide(color: colors.borderLight)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Stacked, not laid out in a row: the timer has to stay centred on
          // the record button below it, whatever width the toggle takes. The
          // row is as tall as the toggle's tap target, and the gap under it is
          // trimmed to pay that back.
          SizedBox(
            height: 40,
            // Full width, or the Column's centre alignment shrinks this row to
            // the width of the status text and `right: 0` pins the toggle to
            // the text's edge instead of the panel's.
            width: double.infinity,
            child: Stack(
              alignment: Alignment.center,
              children: [
                if (isRecording)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (!isPaused) const _RecPulse(),
                      if (isPaused)
                        Icon(Icons.pause_rounded,
                            size: 14, color: colors.textSecondary),
                      const SizedBox(width: 8),
                      Text(
                        isPaused ? '$pausedLabel · $elapsedLabel' : elapsedLabel,
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: colors.textPrimary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  )
                else
                  Text(
                    tapToRecordLabel,
                    style: TextStyle(
                      fontSize: 15,
                      color: colors.textSecondary,
                    ),
                  ),
                Positioned(
                  right: 0,
                  child: SkipSilenceButton(
                    enabled: skipSilence,
                    tooltip: skipSilenceTooltip,
                    onTap: onToggleSkipSilence,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Pause sits beside the record button and only exists while
              // recording, so the resting state stays a single obvious action.
              SizedBox(
                width: 64,
                child: isRecording
                    ? IconButton(
                        onPressed: onTogglePause,
                        tooltip: pauseTooltip,
                        icon: Icon(
                          isPaused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 28,
                          color: colors.textSecondary,
                        ),
                      )
                    : null,
              ),
              RecordButton(isRecording: isRecording, onTap: onTap),
              // Hold-to-transcribe. A hold rather than a toggle because it
              // bounds the extra CPU work to exactly as long as the user wants
              // to watch — releasing stops decoding immediately.
              SizedBox(
                width: 64,
                child: isRecording && liveEnabled
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
    final colors = AppTheme.of(context);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: colors.recordRed,
        shape: BoxShape.circle,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.mic_none_rounded, size: 56, color: colors.textHint),
          const SizedBox(height: 12),
          Text(
            l10n.noRecordingsTitle,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: colors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.noRecordingsBody,
            style: TextStyle(fontSize: 13, color: colors.textHint),
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
    final colors = AppTheme.of(context);
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
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _held ? colors.accentLight : Colors.transparent,
          ),
          child: Icon(
            Icons.subtitles_rounded,
            size: 26,
            color: _held ? colors.accent : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}


/// The "Today" label above the home list.
///
/// Small and quiet on purpose: it is a scope note, not a section the user is
/// meant to act on. It matches the day headers in History so the two lists read
/// as one system.
class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.4,
          color: colors.textHint,
        ),
      ),
    );
  }
}

/// Shown when recordings exist but none of them are from today.
///
/// Distinct from [_EmptyState], which means the app has never recorded
/// anything: here the user's audio is safe and one tap away, and saying so is
/// the whole job of this screen.
class _NothingToday extends StatelessWidget {
  const _NothingToday();

  @override
  Widget build(BuildContext context) {
    final colors = AppTheme.of(context);
    final l10n = AppLocalizations.of(context)!;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.mic_none_rounded, size: 56, color: colors.textHint),
            const SizedBox(height: 12),
            Text(
              l10n.noRecordingsTodayTitle,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.noRecordingsTodayBody,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: colors.textHint),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
              ),
              icon: const Icon(Icons.history_rounded, size: 18),
              label: Text(l10n.openHistory),
              style: TextButton.styleFrom(foregroundColor: colors.accent),
            ),
          ],
        ),
      ),
    );
  }
}
