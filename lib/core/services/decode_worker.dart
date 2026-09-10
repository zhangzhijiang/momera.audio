import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa_onnx;

/// Raw recogniser output for one utterance, before it is given a timeline.
@immutable
class DecodedUtterance {
  const DecodedUtterance({required this.text, required this.lang});

  /// Recognised text, already trimmed. Never empty — a decode that produced
  /// nothing comes back as null instead.
  final String text;

  /// Language tag SenseVoice identified for this utterance, e.g. `<|zh|>`.
  final String lang;
}

/// Runs SenseVoice decodes on a background isolate.
///
/// **Why this exists.** `OfflineRecognizer.decode` is a native call with no
/// yield point inside it. Run on the main isolate it stalls everything for the
/// length of the inference — an estimated 90 ms for a short phrase on a current
/// iPhone, but well over a second on a mid-range Android, once per utterance.
/// That shows up as dropped frames while recording, and it also delays the
/// audio writer, because the live tap runs inside the recorder's chunk handler.
///
/// **How the native object crosses the isolate boundary.** The recogniser is
/// ~228 MB, so a second one is out of the question. Instead the *same* native
/// object is addressed from the worker: every sherpa class exposes a public
/// `ptr` and a `fromPtr` constructor, and `Pointer.address` is a plain int that
/// travels over a `SendPort`. The worker calls `initBindings()` itself because
/// `SherpaOnnxBindings` is static, and therefore per-isolate.
///
/// **Ownership.** The native object is not documented as thread-safe, so
/// exactly one isolate may touch it at a time. Once a worker is spawned it is
/// the *only* place decoding happens — both the file path and the live path go
/// through it — and the main isolate keeps only creation and `free()` of the
/// recogniser. [shutdown] therefore waits for the worker to actually stop
/// before the caller is allowed to free the recogniser.
///
/// Messages are plain tagged `List`s rather than model classes: lists and typed
/// data are sendable on every Dart version, whereas sending arbitrary class
/// instances depends on isolate-group support, and a failure there would only
/// ever show up on a real device.
class DecodeWorker {
  DecodeWorker._(this._fromWorker);

  final ReceivePort _fromWorker;
  final Map<int, Completer<DecodedUtterance?>> _pending = {};
  final Completer<void> _stopped = Completer<void>();

  Isolate? _isolate;
  SendPort? _toWorker;
  int _nextId = 0;
  bool _closed = false;

  /// Whether decodes can still be submitted.
  bool get isRunning => !_closed && _toWorker != null;

  /// Spawn a worker bound to the recogniser at [recognizerAddress].
  ///
  /// The caller must keep that recogniser alive until [shutdown] completes.
  static Future<DecodeWorker> spawn({required int recognizerAddress}) async {
    final worker = DecodeWorker._(ReceivePort());
    final handshake = Completer<SendPort>();

    worker._fromWorker.listen((message) {
      if (message is SendPort) {
        if (!handshake.isCompleted) handshake.complete(message);
        return;
      }
      if (message is List && message.length == 4 && message[0] == _tagReply) {
        worker._onReply(
          message[1] as int,
          message[2] as String?,
          message[3] as String,
        );
        return;
      }
      if (message == _tagStopped) {
        worker._onWorkerGone(null);
        return;
      }
      // `onExit` sends null; `onError` sends [error, stackTrace]. Either way
      // the worker is gone and every decode in flight is lost with it.
      final reason = message is List && message.isNotEmpty
          ? '${message.first}'
          : 'decode isolate exited unexpectedly';
      worker._onWorkerGone(reason);
      if (!handshake.isCompleted) handshake.completeError(StateError(reason));
    });

    try {
      worker._isolate = await Isolate.spawn(
        _entry,
        [worker._fromWorker.sendPort, recognizerAddress],
        debugName: 'momera-decode',
        onExit: worker._fromWorker.sendPort,
        onError: worker._fromWorker.sendPort,
      );
      worker._toWorker = await handshake.future;
    } catch (e) {
      worker._isolate?.kill(priority: Isolate.immediate);
      worker._fromWorker.close();
      rethrow;
    }
    return worker;
  }

  /// Decode one utterance. Resolves to null when the recogniser produced no
  /// text, and completes with an error if the worker died mid-flight.
  ///
  /// Requests are answered in submission order: a `ReceivePort` delivers
  /// messages in order and the worker's handler is synchronous, so utterances
  /// cannot overtake each other.
  Future<DecodedUtterance?> decode(
    Float32List samples, {
    required int sampleRate,
  }) {
    final port = _toWorker;
    if (_closed || port == null) {
      return Future.error(StateError('decode worker is not running'));
    }
    final id = _nextId++;
    final completer = Completer<DecodedUtterance?>();
    _pending[id] = completer;
    port.send([_tagDecode, id, samples, sampleRate]);
    return completer.future;
  }

  /// Stop the worker and wait for it to actually exit.
  ///
  /// The stop message is queued behind any decodes already submitted, so this
  /// drains rather than truncating. Only once it returns is the caller free to
  /// `free()` the recogniser: killing the isolate first could tear the Dart
  /// side out from under a native inference still reading model memory.
  Future<void> shutdown() async {
    if (_closed) {
      await _stopped.future;
      return;
    }
    final port = _toWorker;
    _closed = true;
    _toWorker = null;

    if (port == null) {
      _onWorkerGone(null);
      return;
    }

    port.send(_tagStop);
    try {
      // Generous: the queue may hold a full-length utterance, and a slow device
      // can spend seconds inside a single decode.
      await _stopped.future.timeout(const Duration(seconds: 30));
    } on TimeoutException {
      debugPrint('DecodeWorker: worker did not stop in time; killing it');
      _isolate?.kill(priority: Isolate.immediate);
      _onWorkerGone('decode isolate was killed after failing to stop');
    }
  }

  void _onReply(int id, String? text, String lang) {
    final completer = _pending.remove(id);
    if (completer == null || completer.isCompleted) return;
    completer.complete(
      text == null ? null : DecodedUtterance(text: text, lang: lang),
    );
  }

  /// The worker is no longer running — cleanly when [reason] is null.
  ///
  /// Decodes still in flight are failed rather than resolved to null: for the
  /// live path a lost phrase is tolerable and the caller swallows it, but for
  /// file transcription a silently missing segment would be presented to the
  /// user as a complete transcript, which is worse than a visible failure.
  void _onWorkerGone(String? reason) {
    _closed = true;
    _toWorker = null;
    _isolate = null;

    final pending = List.of(_pending.values);
    _pending.clear();
    final error = StateError(reason ?? 'decode worker stopped');
    for (final completer in pending) {
      if (!completer.isCompleted) completer.completeError(error);
    }

    if (!_stopped.isCompleted) _stopped.complete();
    _fromWorker.close();
  }

  // --- Wire protocol --------------------------------------------------------

  /// Main → worker: `[_tagDecode, id, samples, sampleRate]`.
  static const String _tagDecode = 'decode';

  /// Worker → main: `[_tagReply, id, text?, lang]`.
  static const String _tagReply = 'reply';

  /// Main → worker: stop after draining the queue.
  static const String _tagStop = 'stop';

  /// Worker → main: the queue is drained and the port is closed.
  static const String _tagStopped = 'stopped';

  // --- Worker side ----------------------------------------------------------

  static void _entry(List<Object?> args) {
    final toMain = args[0] as SendPort;
    final recognizerAddress = args[1] as int;

    // Static, and therefore per-isolate: the bindings this isolate uses have to
    // be loaded here even though the main isolate already did it.
    sherpa_onnx.initBindings();

    // Rebuild a handle to the recogniser the main isolate created. The
    // pointer's type argument is inferred from `fromPtr`, which keeps this off
    // sherpa's private bindings library. `config` is stored but never read by
    // createStream/decode/getResult, so a placeholder is honest here — the real
    // configuration is already baked into the native object.
    final recognizer = sherpa_onnx.OfflineRecognizer.fromPtr(
      ptr: Pointer.fromAddress(recognizerAddress),
      config: const sherpa_onnx.OfflineRecognizerConfig(
        model: sherpa_onnx.OfflineModelConfig(tokens: ''),
      ),
    );

    final fromMain = ReceivePort();
    toMain.send(fromMain.sendPort);

    fromMain.listen((message) {
      if (message == _tagStop) {
        // Deliberately does NOT free the recogniser: the main isolate owns it.
        fromMain.close();
        toMain.send(_tagStopped);
        return;
      }

      final request = message as List<Object?>;
      final id = request[1] as int;
      final samples = request[2] as Float32List;
      final sampleRate = request[3] as int;

      String? text;
      var lang = '';
      try {
        final stream = recognizer.createStream();
        try {
          stream.acceptWaveform(samples: samples, sampleRate: sampleRate);
          recognizer.decode(stream);
          final result = recognizer.getResult(stream);
          final trimmed = result.text.trim();
          if (trimmed.isNotEmpty) {
            text = trimmed;
            lang = result.lang;
          }
        } finally {
          stream.free();
        }
      } catch (e) {
        // One bad utterance must not take the worker down with it; the caller
        // sees it as "produced nothing" and the pass continues.
        debugPrint('DecodeWorker: decode failed: $e');
        text = null;
      }
      toMain.send([_tagReply, id, text, lang]);
    });
  }
}
