import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/audio/silence_gate.dart';
import 'package:momera_recording/core/capabilities/capability.dart';
import 'package:momera_recording/core/services/audio_recording_service.dart';
import 'package:momera_recording/data/models/recording.dart';
import 'package:momera_recording/l10n/app_localizations.dart';
import 'package:momera_recording/presentation/providers/capability_provider.dart';
import 'package:momera_recording/presentation/providers/recordings_provider.dart';
import 'package:momera_recording/presentation/providers/service_providers.dart';
import 'package:momera_recording/presentation/screens/home_screen.dart';
import 'package:momera_recording/presentation/widgets/record_button.dart';
import 'package:momera_recording/presentation/widgets/skip_silence_button.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A detector that never hears anything. Enough to prove the gate was built:
/// the tests here are about the control, not about the audio.
class _SilentDetector implements SpeechDetector {
  @override
  bool detect(Float32List window) => false;

  @override
  void reset() {}

  @override
  void dispose() {}
}

class _NoRecordings extends RecordingsNotifier {
  @override
  Future<List<Recording>> build() async => const [];
}

/// Pump the home screen with a recorder whose detector is ours to choose.
///
/// [canDetect] false stands in for a device that cannot run a VAD — a 32-bit
/// process, or a missing native library — which is exactly what the real
/// factory hits in a test environment anyway.
Future<void> _pumpHome(WidgetTester tester, {bool canDetect = true}) async {
  final recorder = AudioRecordingService(
    detectorFactory: () async => canDetect ? _SilentDetector() : null,
  );
  addTearDown(recorder.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        recordingsProvider.overrideWith(_NoRecordings.new),
        transcriptionCapabilityProvider
            .overrideWith((_) async => const FeatureCapability.available()),
        audioRecordingServiceProvider.overrideWithValue(recorder),
      ],
      child: const MaterialApp(
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: HomeScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('the skip-silence button', () {
    testWidgets('sits in the record panel, off by default, with no label',
        (tester) async {
      await _pumpHome(tester);

      expect(find.byType(SkipSilenceButton), findsOneWidget);
      expect(
        tester.widget<SkipSilenceButton>(find.byType(SkipSilenceButton)).enabled,
        isFalse,
        reason: 'recording everything is the behaviour a recorder is expected '
            'to have until the user says otherwise',
      );
      // Icon only: the words live in the tooltip and in the popup on toggle.
      expect(
        find.descendant(
          of: find.byType(SkipSilenceButton),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
      expect(find.byTooltip('Skip silence'), findsOneWidget);
    });

    testWidgets('does not push the status text off the record button\'s centre',
        (tester) async {
      // The toggle is stacked over the status row rather than laid out beside
      // it, so the timer stays on the same centre line as the record button.
      await _pumpHome(tester);

      final status = tester.getRect(find.text('Tap to record'));
      final screen = tester.getRect(find.byType(MaterialApp));
      final toggle = tester.getRect(find.byType(SkipSilenceButton));

      expect(status.center.dx, closeTo(screen.center.dx, 0.5));
      // Pinned to the panel's right edge, not merely somewhere right of centre:
      // the row has to span the bar's width for `right: 0` to mean the corner,
      // and it does not by default.
      expect(toggle.right, closeTo(screen.right - 16, 1),
          reason: 'flush against the panel padding');
    });

    testWidgets('lives in the record panel, not the title bar', (tester) async {
      await _pumpHome(tester);

      expect(
        find.ancestor(
          of: find.byType(SkipSilenceButton),
          matching: find.byType(AppBar),
        ),
        findsNothing,
      );
      // Same panel as the record button, so the two read as one control group.
      expect(
        find.ancestor(
          of: find.byType(SkipSilenceButton),
          matching: find.ancestor(
            of: find.byType(RecordButton),
            matching: find.byType(Container),
          ),
        ),
        findsWidgets,
      );
    });

    testWidgets('draws a waveform, and never a mute symbol', (tester) async {
      // A crossed speaker on a recorder reads as "the microphone is off", which
      // is close to the opposite of what this does; scissors and fast-forward
      // describe editing and playback rather than what is being captured.
      await _pumpHome(tester);

      for (final wrong in [
        Icons.volume_off_rounded,
        Icons.mic_off_rounded,
        Icons.content_cut_rounded,
        Icons.fast_forward_rounded,
      ]) {
        expect(find.byIcon(wrong), findsNothing, reason: '$wrong');
      }
      expect(
        find.descendant(
          of: find.byType(SkipSilenceButton),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });

    testWidgets('turning it on says what changed, then gets out of the way',
        (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byType(SkipSilenceButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Skipping silence'), findsOneWidget);
      expect(find.text('Only speech is recorded.'), findsOneWidget);
      expect(
        tester.widget<SkipSilenceButton>(find.byType(SkipSilenceButton)).enabled,
        isTrue,
      );

      // The popup leaves on its own: show + hold + fade is under two seconds.
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(find.text('Skipping silence'), findsNothing);
    });

    testWidgets('turning it back off says so too', (tester) async {
      await _pumpHome(tester);

      await tester.tap(find.byType(SkipSilenceButton));
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(SkipSilenceButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Recording everything'), findsOneWidget);
      expect(
        tester.widget<SkipSilenceButton>(find.byType(SkipSilenceButton)).enabled,
        isFalse,
      );
    });

    testWidgets('the popup lets taps through to the controls under it',
        (tester) async {
      // The splash overlay absorbs taps on purpose; this one must not, or it
      // would swallow a tap on the record button for the second it is up.
      await _pumpHome(tester);

      await tester.tap(find.byType(SkipSilenceButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.ancestor(
          of: find.text('Skipping silence'),
          matching: find.byType(IgnorePointer),
        ),
        findsWidgets,
      );
    });

    testWidgets('a device that cannot run a detector is told, and stays off',
        (tester) async {
      await _pumpHome(tester, canDetect: false);

      await tester.tap(find.byType(SkipSilenceButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.text('Skipping silence is not available on this device.'),
          findsOneWidget);
      // The preference must not be stored: a pill reading "on" over a recording
      // that keeps every sample would be a lie.
      expect(
        tester.widget<SkipSilenceButton>(find.byType(SkipSilenceButton)).enabled,
        isFalse,
      );
    });

    testWidgets('the choice is remembered', (tester) async {
      SharedPreferences.setMockInitialValues({'settings.skipSilence': true});
      await _pumpHome(tester);

      expect(
        tester.widget<SkipSilenceButton>(find.byType(SkipSilenceButton)).enabled,
        isTrue,
      );
    });
  });

  group('AudioRecordingService.setSkipSilence', () {
    test('reports failure without ever refusing to record', () async {
      final recorder = AudioRecordingService(detectorFactory: () async => null);
      addTearDown(recorder.dispose);

      expect(await recorder.setSkipSilence(true), isFalse);
      expect(recorder.isSkippingSilence, isFalse,
          reason: 'no gate means every sample is kept');
    });

    test('turning it off disposes the detector', () async {
      final detector = _SilentDetector();
      final recorder =
          AudioRecordingService(detectorFactory: () async => detector);
      addTearDown(recorder.dispose);

      expect(await recorder.setSkipSilence(true), isTrue);
      expect(recorder.isSkippingSilence, isTrue);

      expect(await recorder.setSkipSilence(false), isTrue);
      expect(recorder.isSkippingSilence, isFalse);
    });
  });
}
