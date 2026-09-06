import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/utils/duration_format.dart';

void main() {
  group('formatDuration', () {
    test('shows mm:ss below an hour', () {
      expect(formatDuration(Duration.zero), '00:00');
      expect(formatDuration(const Duration(seconds: 7)), '00:07');
      expect(formatDuration(const Duration(minutes: 3, seconds: 5)), '03:05');
      expect(formatDuration(const Duration(minutes: 59, seconds: 59)), '59:59');
    });

    test('widens to h:mm:ss at an hour instead of wrapping', () {
      // The regression this guards: `inMinutes.remainder(60)` rendered 90
      // minutes as "30:00", indistinguishable from 30 minutes. Recordings run
      // in the background and while locked, so multi-hour is ordinary.
      expect(formatDuration(const Duration(hours: 1)), '1:00:00');
      expect(formatDuration(const Duration(minutes: 90)), '1:30:00');
      expect(
        formatDuration(const Duration(hours: 2, minutes: 5, seconds: 9)),
        '2:05:09',
      );
      expect(formatDuration(const Duration(hours: 12)), '12:00:00');
    });

    test('an hour and 30 minutes never renders the same as 30 minutes', () {
      expect(
        formatDuration(const Duration(minutes: 90)),
        isNot(formatDuration(const Duration(minutes: 30))),
      );
    });

    test('null is a placeholder, not a crash', () {
      expect(formatDuration(null), '--:--');
    });

    test('a negative duration clamps to zero', () {
      expect(formatDuration(const Duration(seconds: -5)), '00:00');
    });
  });
}
