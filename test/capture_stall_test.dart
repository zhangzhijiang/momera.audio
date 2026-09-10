import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:momera_recording/core/services/audio_recording_service.dart';
import 'package:momera_recording/core/services/recording_session_channel.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';
import 'package:record/record.dart';

/// A microphone that can be told to go quiet.
///
/// The whole point of the watchdog is that a real one does this *without saying
/// so* — no error, no end of stream, just no more buffers, which is what
/// happens when another app takes the microphone or a ROM freezes the process
/// in the background. [goQuiet] reproduces exactly that, and it is what used to
/// leave a recording frozen at whatever second it stalled on until the user
/// pressed stop.
class _FakeCapture implements CaptureSource {
  /// One controller per `start()`, so a rebuild is observable.
  final List<StreamController<Uint8List>> controllers = [];

  int startCount = 0;
  int stopCount = 0;

  /// When false, `start()` still succeeds but no audio ever arrives — a
  /// microphone still held by whoever took it. Claiming recovery in that state
  /// was the second half of the bug.
  bool delivering = true;

  StreamController<Uint8List> get _current => controllers.last;

  @override
  Future<bool> hasPermission() async => true;

  @override
  Future<Stream<Uint8List>> start(RecordConfig config) async {
    startCount++;
    final controller = StreamController<Uint8List>();
    controllers.add(controller);
    return controller.stream;
  }

  /// Push one buffer, as the platform would.
  void emit([int bytes = 3200]) {
    if (delivering && !_current.isClosed) _current.add(Uint8List(bytes));
  }

  void goQuiet() => delivering = false;

  void resumeDelivering() => delivering = true;

  @override
  Future<void> stop() async => stopCount++;

  @override
  void dispose() {
    for (final controller in controllers) {
      if (!controller.isClosed) controller.close();
    }
  }
}

/// The session channel talks to a platform that does not exist in a unit test.
class _NoSession implements RecordingSessionChannel {
  @override
  Future<void> start(RecordingNotificationText? notification) async {}

  @override
  Future<void> updateElapsed(Duration elapsed) async {}

  @override
  Future<void> stop() async {}
}

class _FakePathProvider extends PathProviderPlatform
    with MockPlatformInterfaceMixin {
  _FakePathProvider(this.root);

  final String root;

  @override
  Future<String?> getApplicationDocumentsPath() async => root;
}

/// Watchdog timings scaled down so a stall happens in milliseconds. The
/// production defaults are 6 s / 2 s; the behaviour under test is the ratio,
/// not the absolute numbers.
const _stall = Duration(milliseconds: 300);
const _tick = Duration(milliseconds: 60);

/// Long enough for the watchdog to notice, back off and rebuild.
Future<void> _settle([Duration d = const Duration(milliseconds: 700)]) =>
    Future<void>.delayed(d);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('momera_stall');
    PathProviderPlatform.instance = _FakePathProvider(tempDir.path);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  ({AudioRecordingService service, _FakeCapture capture}) build({
    int maxRestarts = 20,
  }) {
    final capture = _FakeCapture();
    return (
      service: AudioRecordingService(
        session: _NoSession(),
        detectorFactory: () async => null,
        capture: capture,
        stallTimeout: _stall,
        watchdogInterval: _tick,
        maxCaptureRestarts: maxRestarts,
      ),
      capture: capture,
    );
  }

  Future<void> start(AudioRecordingService service) => service.startRecording(
        availableBytes: 10 * 1024 * 1024,
        flushInterval: const Duration(seconds: 10),
      );

  test('capture that goes silently dead is rebuilt, not left frozen', () async {
    final h = build();
    addTearDown(h.service.dispose);
    final interruptions = <bool>[];
    h.service.onCaptureInterrupted = interruptions.add;

    await start(h.service);
    h.capture.emit();
    await _settle(const Duration(milliseconds: 50));

    expect(h.service.bytesWritten, greaterThan(0),
        reason: 'the first buffer should have been written');
    expect(h.capture.startCount, 1);

    // The microphone stops delivering without announcing it: no error, no
    // onDone. This is the failure that used to be undetectable.
    h.capture.goQuiet();
    await _settle();

    expect(h.capture.startCount, greaterThan(1),
        reason: 'a silently dead stream must trigger a rebuild');
    expect(interruptions.first, isTrue,
        reason: 'the user must be told capture was lost');

    await h.service.stopRecording();
  });

  test('healthy capture is never torn down', () async {
    final h = build();
    addTearDown(h.service.dispose);

    await start(h.service);
    // Buffers keep arriving. With skip-silence on they may all be silent and
    // write nothing for minutes, so the watchdog has to key on buffers
    // ARRIVING, not on bytes being written.
    for (var i = 0; i < 12; i++) {
      h.capture.emit();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    expect(h.capture.startCount, 1,
        reason: 'live capture must not be rebuilt');

    await h.service.stopRecording();
  });

  test('a paused recording is not mistaken for a stall', () async {
    final h = build();
    addTearDown(h.service.dispose);

    await start(h.service);
    h.capture.emit();
    await _settle(const Duration(milliseconds: 50));

    // While paused the stream is deliberately left running and its audio
    // discarded, so buffers still arrive and capture is still healthy.
    h.service.pause();
    for (var i = 0; i < 12; i++) {
      h.capture.emit();
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }

    expect(h.capture.startCount, 1,
        reason: 'pausing must not trigger a capture rebuild');

    await h.service.stopRecording();
  });

  test('recovery is announced only once audio actually returns', () async {
    final h = build();
    addTearDown(h.service.dispose);
    final interruptions = <bool>[];
    h.service.onCaptureInterrupted = interruptions.add;

    await start(h.service);
    h.capture.emit();
    await _settle(const Duration(milliseconds: 50));

    h.capture.goQuiet();
    await _settle();

    expect(h.capture.startCount, greaterThan(1), reason: 'capture was rebuilt');
    // `start()` succeeded, but the rebuilt stream is just as dead. Announcing
    // recovery here is what turned a blip into a permanent stall.
    expect(interruptions, isNot(contains(false)),
        reason: 'recovery must not be claimed before audio returns');

    // Audio finally comes back on the newest stream.
    h.capture.resumeDelivering();
    h.capture.emit();
    await _settle(const Duration(milliseconds: 100));

    expect(interruptions.last, isFalse,
        reason: 'the first real buffer is what proves recovery');

    await h.service.stopRecording();
  });

  test('a stall that never recovers ends the recording and keeps the audio',
      () async {
    // Three attempts rather than the production twenty: the backoff caps at
    // three seconds, so exhausting the real budget takes over a minute.
    final h = build(maxRestarts: 3);
    addTearDown(h.service.dispose);

    RecordingStopReason? reason;
    final path = await h.service.startRecording(
      availableBytes: 10 * 1024 * 1024,
      flushInterval: const Duration(milliseconds: 50),
      onStopped: (r, _) => reason = r,
    );
    expect(path, isNotNull);

    h.capture.emit();
    await _settle(const Duration(milliseconds: 80));
    final written = h.service.bytesWritten;
    expect(written, greaterThan(0));

    // Never comes back. The retry budget is bounded on purpose, so the
    // recording has to end by itself rather than retry a dead microphone for
    // the life of the battery.
    h.capture.goQuiet();
    await _settle(const Duration(seconds: 8));

    expect(reason, RecordingStopReason.interrupted,
        reason: 'an unrecoverable stall must end the recording, and say so');
    expect(h.service.isRecording, isFalse);
    expect(File(path!).existsSync(), isTrue,
        reason: 'the audio captured before the stall must be kept');
  }, timeout: const Timeout(Duration(seconds: 60)));
}
