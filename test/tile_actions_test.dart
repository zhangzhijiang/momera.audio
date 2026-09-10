import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/capabilities/capability.dart';
import 'package:momera_recording/core/services/transcription_service.dart';
import 'package:momera_recording/data/models/recording.dart';
import 'package:momera_recording/l10n/app_localizations.dart';
import 'package:momera_recording/presentation/providers/capability_provider.dart';
import 'package:momera_recording/presentation/widgets/recording_tile.dart';
import 'package:shared_preferences/shared_preferences.dart';

Recording _recording({String? transcript = 'the quick brown fox'}) {
  return Recording(
    path: '/tmp/recording_20260101_120000.wav',
    createdAt: DateTime(2026, 1, 1, 12),
    sizeBytes: 320044,
    duration: const Duration(seconds: 10),
    transcript: transcript,
    languages:
        transcript == null ? const [] : const [TranscriptionLanguage.english],
  );
}

Future<void> _pumpTile(WidgetTester tester, Recording recording) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transcriptionCapabilityProvider
            .overrideWith((_) async => const FeatureCapability.available()),
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
          body: ListView(children: [RecordingTile(recording: recording)]),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('the tile carries its actions inline, with no overflow menu',
      (tester) async {
    await _pumpTile(tester, _recording());

    expect(find.text('Transcript'), findsOneWidget);
    expect(find.byType(PopupMenuButton<dynamic>), findsNothing);
    // Translation was removed from the product; nothing should offer it.
    expect(find.byTooltip('Translate'), findsNothing);
    for (final tooltip in [
      'Rename',
      'Share audio',
      'Delete',
      'Copy transcript',
      'Share transcript',
      'Remove transcript',
    ]) {
      expect(find.byTooltip(tooltip), findsOneWidget, reason: tooltip);
    }
  });

  // Both paths pop the dialog, and the dialog keeps rebuilding through its exit
  // animation. Disposing the rename TextEditingController as soon as
  // showDialog's future completed left that animation holding a dead
  // controller, which threw on every rename attempt. pumpAndSettle runs the
  // exit transition to completion, which is what makes these catch it.
  for (final action in ['Cancel', 'Save']) {
    testWidgets('the rename dialog closes cleanly via $action', (tester) async {
      await _pumpTile(tester, _recording());

      await tester.tap(find.byTooltip('Rename'));
      await tester.pumpAndSettle();
      expect(find.text('Rename recording'), findsOneWidget);

      await tester.tap(find.text(action));
      await tester.pumpAndSettle();

      expect(find.text('Rename recording'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('the detected languages are still named on a transcript',
      (tester) async {
    // `transcriptionLanguageLabel` outlived the spoken-language *setting* —
    // recognition is automatic now, but the languages it detected are still
    // reported here, so the labels must keep resolving.
    await _pumpTile(
      tester,
      _recording().copyWith(languages: const [
        TranscriptionLanguage.english,
        TranscriptionLanguage.mandarin,
      ]),
    );

    expect(find.text('Detected: English · Mandarin Chinese'), findsOneWidget);
  });

  testWidgets('a recording with no transcript shows no transcript actions',
      (tester) async {
    await _pumpTile(tester, _recording(transcript: null));

    expect(find.text('Transcript'), findsNothing);
    expect(find.byTooltip('Copy transcript'), findsNothing);
    // Recording-level actions are still there.
    expect(find.byTooltip('Rename'), findsOneWidget);
  });
}
