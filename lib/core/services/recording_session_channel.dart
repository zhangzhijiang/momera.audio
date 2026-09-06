import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Text for the Android foreground-service notification.
///
/// Android requires a visible, non-dismissable notification for the whole time
/// a foreground service runs — it is how the platform guarantees the user can
/// see that an app is recording. The strings are supplied from Dart so they are
/// localised with the rest of the UI.
///
/// iOS has no equivalent: the system shows its own recording indicator and this
/// text is unused there.
@immutable
class RecordingNotificationText {
  const RecordingNotificationText({
    required this.title,
    required this.body,
    required this.stopLabel,
  });

  final String title;

  /// Shown while recording; `{time}` is replaced with the elapsed duration.
  final String body;

  /// Label of the notification's stop action.
  final String stopLabel;

  Map<String, String> toMap() => {
        'title': title,
        'body': body,
        'stopLabel': stopLabel,
      };
}

/// Keeps audio capture alive while the app is backgrounded or the screen is
/// locked.
///
/// * **Android** — starts a foreground service typed `microphone`, which is the
///   only sanctioned way to keep recording after the app leaves the foreground.
/// * **iOS** — activates an `AVAudioSession` in the record category. Combined
///   with `UIBackgroundModes: audio` in `Info.plist`, capture survives
///   backgrounding and the lock screen.
/// * **Everywhere else** — a no-op, so desktop and web builds are unaffected.
class RecordingSessionChannel {
  const RecordingSessionChannel();

  static const MethodChannel _channel =
      MethodChannel('com.idatagear.momerarecording/recording_session');

  bool get _isSupported =>
      defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;

  Future<void> start(RecordingNotificationText? notification) async {
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('start', notification?.toMap() ?? {});
    } catch (e) {
      // A failed background session must not prevent recording — it just means
      // capture may stop when the app is backgrounded.
      debugPrint('RecordingSessionChannel.start failed: $e');
    }
  }

  /// Refresh the elapsed time shown in the Android notification.
  ///
  /// Called on every audio chunk, so it is throttled to whole seconds to avoid
  /// hammering the notification manager.
  Future<void> updateElapsed(Duration elapsed) async {
    if (defaultTargetPlatform != TargetPlatform.android) return;
    final seconds = elapsed.inSeconds;
    if (seconds == _lastPublishedSecond) return;
    _lastPublishedSecond = seconds;
    try {
      await _channel.invokeMethod<void>('update', {'seconds': seconds});
    } catch (_) {
      // Cosmetic only.
    }
  }

  Future<void> stop() async {
    _lastPublishedSecond = -1;
    if (!_isSupported) return;
    try {
      await _channel.invokeMethod<void>('stop');
    } catch (e) {
      debugPrint('RecordingSessionChannel.stop failed: $e');
    }
  }

  /// Invoked when the user taps Stop in the Android notification.
  static void setStopRequestedHandler(VoidCallback? onStopRequested) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'stopRequested') onStopRequested?.call();
      return null;
    });
  }
}

/// Last whole second pushed to the notification, to throttle updates.
int _lastPublishedSecond = -1;
