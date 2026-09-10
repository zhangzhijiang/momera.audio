import 'dart:ffi';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

import '../../data/repositories/capability_repository.dart';
import '../services/model_download_service.dart';
import 'capability.dart';
import 'device_info_channel.dart';

/// Decides which features this device may be offered.
///
/// Recording is the baseline every device gets. Transcription needs a 228 MB
/// model running through sherpa-onnx's native library, which is not a given.
///
/// **The rule this class exists to enforce:** never hide a feature for a reason
/// the user could fix. Low free disk or a missing download keeps the feature
/// visible with an explanation; only a device that genuinely cannot run it ever
/// disappears the feature. See [CapabilityBlocker].
class DeviceCapabilityService {
  DeviceCapabilityService({
    CapabilityRepository? store,
    int Function()? pointerWidth,
    Future<bool> Function()? probeNative,
    Future<bool> Function()? isModelPresent,
    Future<DeviceMemoryInfo> Function()? memoryInfo,
    Future<int> Function()? freeDiskBytes,
  })  : _store = store ?? CapabilityRepository(),
        _pointerWidth = pointerWidth ?? _defaultPointerWidth,
        _probeNative = probeNative ?? _defaultProbeNative,
        _isModelPresent = isModelPresent ?? ModelDownloadService.isModelReady,
        _memoryInfo = memoryInfo ?? DeviceInfoChannel.describe,
        _freeDiskBytes = freeDiskBytes ?? DeviceInfoChannel.freeDiskBytes;

  final CapabilityRepository _store;
  final int Function() _pointerWidth;
  final Future<bool> Function() _probeNative;
  final Future<bool> Function() _isModelPresent;
  final Future<DeviceMemoryInfo> Function() _memoryInfo;
  final Future<int> Function() _freeDiskBytes;

  /// Memoized separately from the capability verdicts, and deliberately **not**
  /// cleared by [invalidate]: how much RAM the device has does not change, so
  /// re-probing on every invalidation is a wasted platform round trip.
  Future<DeviceMemoryInfo>? _memory;

  /// Memoized per process — resolving costs a preference read and, once, a
  /// 29 MB `dlopen`.
  Future<FeatureCapability>? _transcription;

  /// Result of the native probe, memoized separately.
  ///
  /// A lazy `final` in Dart that threw re-runs and re-throws on every access,
  /// so sherpa's `_dylib` would attempt the `dlopen` again each time this was
  /// called. Caching the answer here is what keeps it to one attempt.
  bool? _nativeProbeResult;

  /// Debug-only forced verdict, from
  /// `--dart-define=MOMERA_CAPABILITY_OVERRIDE=…`.
  ///
  /// The dev machine cannot produce a 32-bit or low-memory device, so the
  /// override is the only practical way to exercise these branches. Applied
  /// only in debug builds, so it cannot reach release.
  static const String _override =
      String.fromEnvironment('MOMERA_CAPABILITY_OVERRIDE');

  /// Whether this device may be offered transcription.
  Future<FeatureCapability> transcription() =>
      _transcription ??= _resolveTranscription();

  Future<FeatureCapability> _resolveTranscription() async {
    if (kDebugMode) {
      switch (_override) {
        case 'stt_32bit':
          return const FeatureCapability.unsupported(
              CapabilityBlocker.processIs32Bit);
        case 'stt_native_missing':
          return const FeatureCapability.unsupported(
              CapabilityBlocker.nativeLibraryMissing);
        case 'stt_oom_learned':
          return const FeatureCapability.unsupported(
              CapabilityBlocker.modelLoadFailedBefore);
        case 'stt_model_missing':
          return const FeatureCapability.blocked(
              CapabilityBlocker.modelNotDownloaded);
        case 'stt_no_disk':
          return const FeatureCapability.blocked(
              CapabilityBlocker.notEnoughFreeDisk,
              bytesNeeded: 300 * 1024 * 1024);
      }
    }

    // 1. Word width. Free, needs no platform channel, and cannot be wrong:
    //    `sizeOf<Pointer>()` reports the running process's pointer size, which
    //    is exactly the armeabi-v7a case.
    if (_pointerWidth() == 4) {
      return const FeatureCapability.unsupported(
          CapabilityBlocker.processIs32Bit);
    }

    // 2. What previous runs learned. Read before the native probe because it
    //    is far cheaper, and a device already known to fail need not dlopen.
    final learned = await _reconcileLearned();
    if (learned.nativeProbeFailed) {
      return const FeatureCapability.unsupported(
          CapabilityBlocker.nativeLibraryMissing);
    }
    if (learned.failedAttempts >= await _failureThreshold()) {
      return const FeatureCapability.unsupported(
          CapabilityBlocker.modelLoadFailedBefore);
    }

    // 3. Can the native library load at all? Loads ~29 MB of shared objects,
    //    not the 228 MB model, so this is cheap enough to decide a button.
    if (!await _nativeAvailable()) {
      await _store.save(learned.copyWith(nativeProbeFailed: true));
      return const FeatureCapability.unsupported(
          CapabilityBlocker.nativeLibraryMissing);
    }

    // 4. Is the model there? Temporary — the download sheet handles it, and the
    //    feature stays visible so the user can start that download.
    if (!await _isModelPresent()) {
      // Say *why* it cannot be downloaded when the answer is "no room". Still
      // blocked, never unsupported: freeing space is the user's to do, and a
      // hidden feature gives them no reason to.
      final free = await _freeDiskBytes();
      final needed = ModelDownloadService.requiredFreeBytes;
      if (free >= 0 && free < needed) {
        return FeatureCapability.blocked(
          CapabilityBlocker.notEnoughFreeDisk,
          bytesNeeded: needed - free,
        );
      }
      return const FeatureCapability.blocked(
          CapabilityBlocker.modelNotDownloaded);
    }

    return const FeatureCapability.available();
  }

  /// How many failed model loads before the device is written off.
  ///
  /// Two, not one: a single death could be an unrelated background kill, and
  /// the verdict has no in-app remedy.
  static const int failureThresholdDefault = 2;

  /// One strike on a device the platform already calls memory-constrained.
  /// Waiting for a second death there mostly means failing the user twice.
  static const int failureThresholdLowRam = 1;

  /// Below this, the ~300 MB resident model is a large share of physical RAM.
  static const int lowRamBytes = 2 * 1024 * 1024 * 1024;

  /// How many failed model loads before the device is written off.
  ///
  /// RAM is **not** a gate — no amount of it produces `unsupported` on its own,
  /// because `totalMem` varies by hundreds of MB between devices with the same
  /// nominal RAM and iOS's real limit (jetsam) is not readable. It only decides
  /// how patient to be with a device that has actually failed.
  Future<int> _failureThreshold() async {
    final info = await (_memory ??= _memoryInfo());
    // `isKnown` is load-bearing: an unknown probe reports -1, and without the
    // guard that would read as the smallest possible device and condemn every
    // phone after a single strike.
    final lowRam = info.isLowRamDevice ||
        (info.isKnown && info.totalMemoryBytes < lowRamBytes);
    return lowRam ? failureThresholdLowRam : failureThresholdDefault;
  }

  /// Read the learned state, clearing a breadcrumb left by a dead process.
  ///
  /// The count is what does the work here, not the flag. [recordModelLoadStarted]
  /// increments *before* the load and only a success resets it, so an attempt
  /// that never came back has already been counted — which is the only way an
  /// out-of-memory kill can be observed at all: `std::bad_alloc` in onnxruntime
  /// aborts the process on Android and jetsam sends SIGKILL on iOS, so neither
  /// ever reaches a Dart `catch`.
  ///
  /// The flag is a diagnostic on top of that, and clearing it here is also why
  /// a query that lands while a load is genuinely in flight does no damage: the
  /// count is untouched, and the load's own outcome still resets or keeps it.
  Future<LearnedCapability> _reconcileLearned() async {
    var learned = await _store.load();
    if (learned.attemptPending) {
      debugPrint('DeviceCapabilityService: a model load did not report an '
          'outcome; it is already counted as an attempt');
      learned = learned.copyWith(attemptPending: false);
      await _store.save(learned);
    }
    return learned;
  }

  Future<bool> _nativeAvailable() async {
    final cached = _nativeProbeResult;
    if (cached != null) return cached;
    final ok = await _probeNative();
    _nativeProbeResult = ok;
    return ok;
  }

  // --- Learned-failure breadcrumb -------------------------------------------

  /// Record that a model load is about to start, counting it as failed up front.
  ///
  /// Must be awaited before the load begins. Counting optimistically and
  /// resetting on success is deliberate: if the process dies mid-load there is
  /// no code left to run, so the increment has to already be on disk. Only a
  /// completed load clears it.
  Future<void> recordModelLoadStarted() async {
    final learned = await _store.load();
    await _store.save(learned.copyWith(
      attemptPending: true,
      failedAttempts: learned.failedAttempts + 1,
    ));
  }

  /// Record that a model load completed, clearing the breadcrumb.
  Future<void> recordModelLoadSucceeded() async {
    final learned = await _store.load();
    await _store.save(learned.copyWith(
      attemptPending: false,
      failedAttempts: 0,
    ));
    invalidate();
  }

  /// Record that a model load threw. The attempt count stands.
  Future<void> recordModelLoadFailed(Object error) async {
    debugPrint('DeviceCapabilityService: model load failed: $error');
    final learned = await _store.load();
    await _store.save(learned.copyWith(attemptPending: false));
    invalidate();
  }

  /// Forget every learned failure and re-resolve.
  Future<void> resetLearnedFailures() async {
    await _store.reset();
    _nativeProbeResult = null;
    invalidate();
  }

  /// Drop the memoized verdicts, so the next query resolves afresh.
  void invalidate() {
    _transcription = null;
  }

  // --- Defaults -------------------------------------------------------------

  /// Pointer size of the running process: 8 on a 64-bit build, 4 on a 32-bit
  /// one. `Pointer` implements `SizedNativeType`, so this satisfies `sizeOf`'s
  /// compile-time-constant requirement.
  static int _defaultPointerWidth() => sizeOf<Pointer>();

  /// Load sherpa-onnx's native library, reporting whether it worked.
  ///
  /// `initBindings()` triggers the `DynamicLibrary.open` of the C API and
  /// onnxruntime — around 29 MB of shared objects, and *not* the 228 MB model,
  /// which is only read when a recogniser is constructed.
  static Future<bool> _defaultProbeNative() async {
    try {
      sherpa_onnx.initBindings();
      return true;
    } catch (e) {
      debugPrint('DeviceCapabilityService: sherpa-onnx native library '
          'unavailable: $e');
      return false;
    }
  }
}
