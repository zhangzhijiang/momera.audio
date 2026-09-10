import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// What the app has learned about this device's ability to run the speech model.
@immutable
class LearnedCapability {
  const LearnedCapability({
    this.nativeProbeFailed = false,
    this.attemptPending = false,
    this.failedAttempts = 0,
  });

  /// True once `initBindings()` has been seen to throw. Sticky across launches
  /// because a missing native library will not appear later.
  final bool nativeProbeFailed;

  /// A model load was started and never reported an outcome — meaning the
  /// process died inside it.
  final bool attemptPending;

  /// How many model loads have failed or died.
  final int failedAttempts;

  LearnedCapability copyWith({
    bool? nativeProbeFailed,
    bool? attemptPending,
    int? failedAttempts,
  }) {
    return LearnedCapability(
      nativeProbeFailed: nativeProbeFailed ?? this.nativeProbeFailed,
      attemptPending: attemptPending ?? this.attemptPending,
      failedAttempts: failedAttempts ?? this.failedAttempts,
    );
  }
}

/// Persists what the app has learned about this device.
///
/// Reads are defensive in the same way [SettingsRepository] is: a missing or
/// malformed value falls back to "nothing learned yet", so a corrupt preference
/// store degrades to offering the feature rather than to hiding it. Erring
/// towards *offering* matters — a wrong "unsupported" verdict is invisible to
/// the user and has no in-app remedy.
class CapabilityRepository {
  static const String _keyGeneration = 'capability.probeGeneration';
  static const String _keyNativeProbe = 'capability.stt.nativeProbeFailed';
  static const String _keyAttemptPending = 'capability.stt.attemptPending';
  static const String _keyFailedAttempts = 'capability.stt.failedAttempts';

  /// Bump this by hand whenever sherpa_onnx or the model changes.
  ///
  /// Everything learned under an older generation is discarded on the next
  /// load, so a device is never permanently condemned by a version of the app
  /// that no longer exists. This is also the only automatic way back for a
  /// device wrongly marked unsupported, since the UI hides the feature and
  /// offers no manual reset.
  static const int probeGeneration = 1;

  Future<LearnedCapability> load() async {
    final prefs = await SharedPreferences.getInstance();

    // A generation change invalidates every learned verdict.
    if (prefs.getInt(_keyGeneration) != probeGeneration) {
      await _clear(prefs);
      return const LearnedCapability();
    }

    final failedAttempts = prefs.getInt(_keyFailedAttempts) ?? 0;
    return LearnedCapability(
      nativeProbeFailed: prefs.getBool(_keyNativeProbe) ?? false,
      attemptPending: prefs.getBool(_keyAttemptPending) ?? false,
      failedAttempts: failedAttempts < 0 ? 0 : failedAttempts,
    );
  }

  Future<void> save(LearnedCapability learned) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_keyGeneration, probeGeneration);
    await prefs.setBool(_keyNativeProbe, learned.nativeProbeFailed);
    await prefs.setBool(_keyAttemptPending, learned.attemptPending);
    await prefs.setInt(_keyFailedAttempts, learned.failedAttempts);
  }

  /// Forget every learned failure, so the device is offered the feature again.
  Future<void> reset() async {
    final prefs = await SharedPreferences.getInstance();
    await _clear(prefs);
    await prefs.setInt(_keyGeneration, probeGeneration);
  }

  Future<void> _clear(SharedPreferences prefs) async {
    await prefs.remove(_keyNativeProbe);
    await prefs.remove(_keyAttemptPending);
    await prefs.remove(_keyFailedAttempts);
  }
}
