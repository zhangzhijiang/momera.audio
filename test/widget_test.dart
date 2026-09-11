import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:momera_recording/main.dart';

void main() {
  // Anything pumping MomeraRecordingApp now starts on SplashGate, which holds
  // for up to ~2.6s before handing over. Settle past it before asserting on
  // anything HomeScreen-only, and note that taps cannot reach through it — the
  // overlay is an AbsorbPointer.
  testWidgets('Home screen shows the app title and record prompt',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MomeraRecordingApp()));
    await tester.pump();

    // Two: the splash title and the app bar behind it. FadeTransition keeps its
    // child mounted at zero opacity, so both exist from the first frame.
    expect(find.text('McRecorder'), findsWidgets);
    // Lives in the record bar, outside the recordings AsyncLoading branch, so
    // it is already laid out under the splash.
    expect(find.text('Tap to record'), findsOneWidget);

    // Explicit pumps, not pumpAndSettle: HomeScreen's loading spinner animates
    // indefinitely, so this tree never settles. See test/splash_test.dart.
    await tester.pump(const Duration(milliseconds: 2100));
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump();

    expect(find.text('McRecorder'), findsOneWidget);
    expect(find.text('Tap to record'), findsOneWidget);
  });
}
