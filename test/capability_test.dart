import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/capabilities/capability.dart';
import 'package:momera_recording/core/capabilities/device_capability_service.dart';
import 'package:momera_recording/core/capabilities/device_info_channel.dart';
import 'package:momera_recording/data/repositories/capability_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Builds a service with every device-dependent seam stubbed, so the resolution
/// logic can be tested on a machine that is none of the devices in question.
DeviceCapabilityService _service({
  int pointerWidth = 8,
  bool nativeOk = true,
  bool modelPresent = true,
  List<int>? probeCounter,
  DeviceMemoryInfo memory = const DeviceMemoryInfo.unknown(),
  int freeDisk = -1,
}) {
  return DeviceCapabilityService(
    store: CapabilityRepository(),
    pointerWidth: () => pointerWidth,
    probeNative: () async {
      if (probeCounter != null) probeCounter[0]++;
      return nativeOk;
    },
    isModelPresent: () async => modelPresent,
    memoryInfo: () async => memory,
    freeDiskBytes: () async => freeDisk,
  );
}

const _lowRam = DeviceMemoryInfo(
  totalMemoryBytes: 1536 * 1024 * 1024,
  isLowRamDevice: false,
);
const _declaredLowRam = DeviceMemoryInfo(
  totalMemoryBytes: 4 * 1024 * 1024 * 1024,
  isLowRamDevice: true,
);
const _roomy = DeviceMemoryInfo(
  totalMemoryBytes: 8 * 1024 * 1024 * 1024,
  isLowRamDevice: false,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('transcription capability', () {
    test('a 64-bit device with the model present is available', () async {
      final capability = await _service().transcription();

      expect(capability.state, CapabilityState.available);
      expect(capability.isUsable, isTrue);
      expect(capability.isVisible, isTrue);
    });

    test('a 32-bit process is unsupported', () async {
      // The armeabi-v7a case: a 228 MB model does not fit reliably in a ~3 GB
      // address space, and no amount of user action changes that.
      final capability = await _service(pointerWidth: 4).transcription();

      expect(capability.state, CapabilityState.unsupported);
      expect(capability.blocker, CapabilityBlocker.processIs32Bit);
      expect(capability.isVisible, isFalse);
    });

    test('word width is checked before anything more expensive', () async {
      final probes = [0];
      await _service(pointerWidth: 4, probeCounter: probes).transcription();

      // A 32-bit verdict must not pay for a 29 MB dlopen to reach it.
      expect(probes[0], 0);
    });

    test('a native library that will not load is unsupported', () async {
      final capability = await _service(nativeOk: false).transcription();

      expect(capability.state, CapabilityState.unsupported);
      expect(capability.blocker, CapabilityBlocker.nativeLibraryMissing);
    });

    test('a failed native probe is remembered across launches', () async {
      await _service(nativeOk: false).transcription();

      // A second service, as if the app had been restarted: the verdict is
      // reached from storage without probing again.
      final probes = [0];
      final capability =
          await _service(nativeOk: true, probeCounter: probes).transcription();

      expect(capability.blocker, CapabilityBlocker.nativeLibraryMissing);
      expect(probes[0], 0);
    });

    test('a missing model blocks but stays visible', () async {
      // The whole point of the blocked/unsupported split: the user can fix
      // this, so hiding it would leave them no way back.
      final capability = await _service(modelPresent: false).transcription();

      expect(capability.state, CapabilityState.blocked);
      expect(capability.blocker, CapabilityBlocker.modelNotDownloaded);
      expect(capability.isVisible, isTrue);
      expect(capability.isUsable, isFalse);
    });

    test('the native probe runs at most once per service', () async {
      final probes = [0];
      final service = _service(probeCounter: probes);

      await service.transcription();
      service.invalidate();
      await service.transcription();

      // sherpa's lazy dylib re-throws on every access if it failed once, so
      // the answer has to be cached here rather than re-derived.
      expect(probes[0], 1);
    });
  });

  group('learned model-load failures', () {
    test('one death still leaves the feature available', () async {
      // A single process death could be an unrelated background kill.
      await _service().recordModelLoadStarted();

      final capability = await _service().transcription();
      expect(capability.state, CapabilityState.available);
    });

    test('two deaths mark the device unsupported', () async {
      // Each "started" that never reports an outcome is how an OOM is
      // observed at all — it aborts the process rather than throwing.
      await _service().recordModelLoadStarted();
      await _service().transcription(); // reconciles the pending attempt
      await _service().recordModelLoadStarted();

      final capability = await _service().transcription();
      expect(capability.state, CapabilityState.unsupported);
      expect(capability.blocker, CapabilityBlocker.modelLoadFailedBefore);
    });

    test('a successful load clears the count', () async {
      final service = _service();
      await service.recordModelLoadStarted();
      await service.recordModelLoadStarted();
      await service.recordModelLoadSucceeded();

      final capability = await _service().transcription();
      expect(capability.state, CapabilityState.available);
    });

    test('a caught failure does not count twice', () async {
      final service = _service();
      await service.recordModelLoadStarted();
      await service.recordModelLoadFailed(StateError('bad model'));

      // One attempt, one failure — the pending flag must not add a second.
      final capability = await _service().transcription();
      expect(capability.state, CapabilityState.available);
    });

    test('resetLearnedFailures brings a condemned device back', () async {
      await _service().recordModelLoadStarted();
      await _service().transcription();
      await _service().recordModelLoadStarted();
      expect(
        (await _service().transcription()).state,
        CapabilityState.unsupported,
      );

      await _service().resetLearnedFailures();

      expect((await _service().transcription()).state,
          CapabilityState.available);
    });

    test('a stale probe generation discards what was learned', () async {
      // The automatic way back for a device wrongly condemned by an app
      // version that no longer exists.
      SharedPreferences.setMockInitialValues({
        'capability.probeGeneration': CapabilityRepository.probeGeneration - 1,
        'capability.stt.failedAttempts': 9,
        'capability.stt.nativeProbeFailed': true,
      });

      final capability = await _service().transcription();
      expect(capability.state, CapabilityState.available);
    });
  });

  group('CapabilityRepository', () {
    test('a corrupt store degrades to offering the feature', () async {
      // Erring towards offering matters: a wrong "unsupported" is invisible to
      // the user and has no in-app remedy.
      SharedPreferences.setMockInitialValues({
        'capability.probeGeneration': CapabilityRepository.probeGeneration,
        'capability.stt.failedAttempts': -5,
      });

      final learned = await CapabilityRepository().load();
      expect(learned.failedAttempts, 0);
      expect(learned.nativeProbeFailed, isFalse);
    });

    test('round-trips what it saved', () async {
      final repository = CapabilityRepository();
      await repository.save(const LearnedCapability(
        nativeProbeFailed: true,
        attemptPending: true,
        failedAttempts: 3,
      ));

      final learned = await repository.load();
      expect(learned.nativeProbeFailed, isTrue);
      expect(learned.attemptPending, isTrue);
      expect(learned.failedAttempts, 3);
    });
  });

  group('memory-adjusted failure threshold', () {
    test('a roomy device tolerates one death', () async {
      await _service(memory: _roomy).recordModelLoadStarted();

      expect((await _service(memory: _roomy).transcription()).state,
          CapabilityState.available);
    });

    test('a small-RAM device is written off after one death', () async {
      await _service(memory: _lowRam).recordModelLoadStarted();

      final capability = await _service(memory: _lowRam).transcription();
      expect(capability.state, CapabilityState.unsupported);
      expect(capability.blocker, CapabilityBlocker.modelLoadFailedBefore);
    });

    test("a device the OEM declares low-RAM is too, regardless of its size",
        () async {
      await _service(memory: _declaredLowRam).recordModelLoadStarted();

      expect((await _service(memory: _declaredLowRam).transcription()).state,
          CapabilityState.unsupported);
    });

    test('an unknown memory probe keeps the forgiving threshold', () async {
      // The one that matters most. DeviceMemoryInfo.unknown() reports -1, and
      // without the `isKnown` guard that reads as the smallest possible device
      // — condemning every phone whose channel failed after a single strike.
      await _service().recordModelLoadStarted();

      expect((await _service().transcription()).state,
          CapabilityState.available);
    });
  });

  group('free disk', () {
    test('too little space blocks but stays visible', () async {
      final capability =
          await _service(modelPresent: false, freeDisk: 100 * 1024 * 1024)
              .transcription();

      expect(capability.state, CapabilityState.blocked);
      expect(capability.blocker, CapabilityBlocker.notEnoughFreeDisk);
      expect(capability.isVisible, isTrue);
      expect(capability.bytesNeeded, greaterThan(0));
    });

    test('unknown free space never blocks', () async {
      // A channel that failed knows nothing; it must not invent a shortage.
      final capability =
          await _service(modelPresent: false, freeDisk: -1).transcription();

      expect(capability.blocker, CapabilityBlocker.modelNotDownloaded);
      expect(capability.isVisible, isTrue);
    });

    test('ample space reports only the missing download', () async {
      final capability =
          await _service(modelPresent: false, freeDisk: 4 * 1024 * 1024 * 1024)
              .transcription();

      expect(capability.blocker, CapabilityBlocker.modelNotDownloaded);
    });

    test('disk is not consulted once the model is present', () async {
      final capability =
          await _service(modelPresent: true, freeDisk: 1).transcription();

      expect(capability.state, CapabilityState.available);
    });
  });

}
