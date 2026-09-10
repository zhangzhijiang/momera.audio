import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/capabilities/capability.dart';
import 'package:momera_recording/presentation/providers/live_transcript_provider.dart';
import 'package:momera_recording/core/services/transcription_service.dart';
import 'package:momera_recording/data/models/recording.dart';
import 'package:momera_recording/l10n/app_localizations.dart';
import 'package:momera_recording/presentation/providers/capability_provider.dart';
import 'package:momera_recording/presentation/widgets/recording_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Recording _recording({String? transcript}) {
  return Recording(
    path: '/tmp/recording_20260101_120000.wav',
    createdAt: DateTime(2026, 1, 1, 12),
    sizeBytes: 320044,
    duration: const Duration(seconds: 10),
    transcript: transcript,
    languages: transcript == null
        ? const []
        : const [TranscriptionLanguage.english],
  );
}

/// Pumps a single tile with the capability verdicts forced.
Future<void> _pumpTile(
  WidgetTester tester, {
  required FeatureCapability transcription,
  Recording? recording,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transcriptionCapabilityProvider.overrideWith((_) async => transcription),
      ],
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: ListView(
            children: [RecordingTile(recording: recording ?? _recording())],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('an unsupported device is not offered Transcribe', (tester) async {
    await _pumpTile(
      tester,
      transcription: const FeatureCapability.unsupported(
          CapabilityBlocker.processIs32Bit),
    );

    expect(find.text('Transcribe'), findsNothing);
  });

  testWidgets('a device that merely needs the download still sees Transcribe',
      (tester) async {
    // The blocked/unsupported distinction, at the UI. Hiding this would leave
    // the user no way to start the download that unblocks it.
    await _pumpTile(
      tester,
      transcription: const FeatureCapability.blocked(
          CapabilityBlocker.modelNotDownloaded),
    );

    expect(find.text('Transcribe'), findsOneWidget);
  });

  testWidgets('a capable device sees Transcribe', (tester) async {
    await _pumpTile(
      tester,
      transcription: const FeatureCapability.available(),
    );

    expect(find.text('Transcribe'), findsOneWidget);
  });

  testWidgets('an existing transcript still displays on an unsupported device',
      (tester) async {
    // The gate is on *producing* transcripts, never on reading ones that
    // already exist — a restored backup, or a recording made before the device
    // was written off, must not lose its text.
    await _pumpTile(
      tester,
      transcription: const FeatureCapability.unsupported(
          CapabilityBlocker.modelLoadFailedBefore),
      recording: _recording(transcript: 'the quick brown fox'),
    );

    expect(find.textContaining('the quick brown fox'), findsOneWidget);
    // ...and Transcribe is still not offered, because there is nothing to redo.
    expect(find.text('Transcribe'), findsNothing);
  });

  // Settings no longer has a transcription section to gate: recognition is
  // always automatic, so there is nothing there for a capability verdict to
  // hide. The remaining gates are all on the tile, above.

  group('live panel dismissal', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    LiveTranscriptNotifier notifier() =>
        container.read(liveTranscriptProvider.notifier);
    LiveTranscriptState read() => container.read(liveTranscriptProvider);

    test('dismiss hides the panel without clearing its lines', () {
      // The property that separates dismiss from reset: closing the panel is
      // presentational, and must not touch the live pass or what it captured.
      notifier().dismissPanel();

      expect(read().dismissed, isTrue);
      expect(read().lines, isEmpty);
    });

    test('showPanel brings it back', () {
      notifier().dismissPanel();
      notifier().showPanel();

      expect(read().dismissed, isFalse);
    });

    test('a new recording un-dismisses the panel', () {
      // reset() assigns a fresh const state, which clears `dismissed` for free.
      // Pinned because a future refactor of reset() into a copyWith would break
      // it silently, and the symptom — panel invisible for the rest of the
      // session — is a long way from the cause.
      notifier().dismissPanel();
      notifier().reset();

      expect(read().dismissed, isFalse);
    });
  });

}
