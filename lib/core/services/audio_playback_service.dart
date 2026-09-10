import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();
  final Map<String, Duration?> _durationCache = {};

  bool _isPlaying = false;
  String? _currentlyPlaying;
  StreamSubscription? _playerSubscription;

  bool get isPlaying => _isPlaying;
  String? get currentlyPlaying => _currentlyPlaying;

  Stream<bool> get playingState => _player.playingStream;
  Stream<PlayerState> get playerState => _player.playerStateStream;
  Stream<Duration?> get position => _player.positionStream;
  Stream<Duration?> get duration => _player.durationStream;

  Future<void> play(String audioPath) async {
    try {
      // Stop any currently playing audio
      await stop();

      final audioFile = File(audioPath);
      if (!await audioFile.exists()) {
        throw StateError('AudioPlaybackService.play: audio file not found');
      }

      _currentlyPlaying = audioPath;
      await _player.setFilePath(audioPath);
      await _player.play();

      _isPlaying = true;

      // Listen for playback completion
      await _playerSubscription?.cancel();
      _playerSubscription = _player.playerStateStream.listen((state) {
        if (state.processingState == ProcessingState.completed) {
          _isPlaying = false;
          _currentlyPlaying = null;
          // just_audio keeps playing=true on completion; stop resets it so
          // playingStream emits false and the UI button reverts to play.
          _player.stop();
          return;
        }

        _isPlaying = state.playing;
        if (!state.playing && state.processingState == ProcessingState.idle) {
          _currentlyPlaying = null;
        }
      });
    } catch (e, st) {
      debugPrint('AudioPlaybackService.play failed: $e\n$st');
      _isPlaying = false;
      _currentlyPlaying = null;
      rethrow;
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _isPlaying = false;
  }

  Future<void> resume() async {
    await _player.play();
    _isPlaying = true;
  }

  Future<void> stop() async {
    await _playerSubscription?.cancel();
    _playerSubscription = null;
    await _player.stop();
    _isPlaying = false;
    _currentlyPlaying = null;
  }

  Future<Duration?> getDuration(String audioPath) async {
    if (_durationCache.containsKey(audioPath)) {
      return _durationCache[audioPath];
    }

    final probe = AudioPlayer();
    try {
      await probe.setFilePath(audioPath);
      final duration = probe.duration;
      _durationCache[audioPath] = duration;
      return duration;
    } catch (_) {
      _durationCache[audioPath] = null;
      return null;
    } finally {
      await probe.dispose();
    }
  }

  Future<void> seek(Duration position) async {
    await _player.seek(position);
  }

  void dispose() {
    _playerSubscription?.cancel();
    _player.dispose();
  }
}
