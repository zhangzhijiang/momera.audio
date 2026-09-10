import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/data/models/recording.dart';
import 'package:momera_recording/main.dart';
import 'package:momera_recording/presentation/providers/recordings_provider.dart';
import 'package:momera_recording/presentation/screens/home_screen.dart';
import 'package:momera_recording/presentation/widgets/animated_logo_mark.dart';

/// Advance past the splash's hard ceiling and its outro.
///
/// Explicit pumps rather than `pumpAndSettle`: HomeScreen sits under the splash
/// showing a CircularProgressIndicator while the recordings load, and that
/// animates indefinitely, so nothing in this tree ever "settles".
Future<void> _pumpPastSplash(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 2100)); // the 2s cap fires
  await tester.pump(const Duration(milliseconds: 700)); // the 620ms outro ends
  await tester.pump(); // rebuild without the overlay
}

void main() {
  testWidgets('the splash animates, then hands off to the home screen',
      (tester) async {
    await tester.pumpWidget(const ProviderScope(child: MomeraRecordingApp()));
    await tester.pump();

    expect(find.byType(AnimatedLogoMark), findsOneWidget);
    // HomeScreen is mounted underneath from the very first frame — that is what
    // lets its ref.listen on recoveredCountProvider see the recovery count.
    expect(find.byType(HomeScreen), findsOneWidget);

    await _pumpPastSplash(tester);

    expect(find.byType(AnimatedLogoMark), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });

  testWidgets('HomeScreen survives the splash retiring', (tester) async {
    // The overlay is dropped from the Stack rather than the Stack being
    // replaced by HomeScreen. Replacing it changes the child's widget type at
    // that slot, so Flutter remounts HomeScreen — which loses its state and
    // re-runs init right as the user first sees it, defeating the reason it is
    // mounted from frame 0 at all.
    await tester.pumpWidget(const ProviderScope(child: MomeraRecordingApp()));
    await tester.pump();
    final before = tester.state(find.byType(HomeScreen));

    await _pumpPastSplash(tester);

    expect(identical(tester.state(find.byType(HomeScreen)), before), isTrue,
        reason: 'HomeScreen was torn down and remounted');
  });

  testWidgets('the splash title inherits a real text style', (tester) async {
    // Regression guard. The overlay deliberately avoids Scaffold so the mark
    // lands on the screen centre, which also means nothing supplies a
    // DefaultTextStyle unless the overlay itself does. Without one the title
    // silently renders in monospace with a yellow underline — it looks broken
    // but throws nothing, so only a check like this catches it.
    await tester.pumpWidget(const ProviderScope(child: MomeraRecordingApp()));
    await tester.pump();

    final style = tester
        .widget<DefaultTextStyle>(
          find
              .ancestor(
                of: find.byType(AnimatedLogoMark),
                matching: find.byType(DefaultTextStyle),
              )
              .first,
        )
        .style;
    expect(style.decoration, isNot(TextDecoration.underline));
    expect(style.fontFamily, isNot('monospace'));

    // Let the splash's timers run out, or the test ends with them pending.
    await _pumpPastSplash(tester);
  });

  testWidgets('the splash still retires when the recordings list never loads',
      (tester) async {
    // Pins the hard ceiling in SplashGate. It has to be an independent
    // Future.delayed rather than a timeout on this provider, or a load that
    // never returns would strand the user on the splash forever.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [recordingsProvider.overrideWith(_NeverLoads.new)],
        child: const MomeraRecordingApp(),
      ),
    );
    await tester.pump();
    expect(find.byType(AnimatedLogoMark), findsOneWidget);

    await _pumpPastSplash(tester);

    expect(find.byType(AnimatedLogoMark), findsNothing);
    expect(find.byType(HomeScreen), findsOneWidget);
  });
}

class _NeverLoads extends RecordingsNotifier {
  @override
  Future<List<Recording>> build() => Completer<List<Recording>>().future;
}
