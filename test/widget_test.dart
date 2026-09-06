import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:momera_recording/main.dart';

void main() {
  testWidgets('Home screen shows the app title and record prompt',
      (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MomeraRecordingApp()));
    await tester.pump();

    expect(find.text('Momera Recorder'), findsOneWidget);
    expect(find.text('Tap to record'), findsOneWidget);
  });
}
