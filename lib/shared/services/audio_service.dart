import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

class AudioService {
  static final instance = AudioService._();
  AudioService._() {
    _player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _completeController.add(null);
      }
    });
  }

  final _player = AudioPlayer();
  final _completeController = StreamController<void>.broadcast();

  Stream<void> get onComplete => _completeController.stream;
  bool get isPlaying => _player.playing;

  Future<void> playSnippet(String path, int startMs, int endMs) async {
    try {
      await _player.setAudioSource(
        ClippingAudioSource(
          start: Duration(milliseconds: startMs),
          end: Duration(milliseconds: endMs),
          child: AudioSource.file(path),
        ),
      );
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (e) {
      debugPrint('AudioService.playSnippet error: $e');
    }
  }

  Future<void> previewClip(String path, int startMs, int endMs) async {
    try {
      await _player.setAudioSource(
        ClippingAudioSource(
          start: Duration(milliseconds: startMs),
          end: Duration(milliseconds: endMs),
          child: AudioSource.file(path),
        ),
      );
      await _player.seek(Duration.zero);
      await _player.play();
    } catch (e) {
      debugPrint('AudioService.previewClip error: $e');
    }
  }

  Future<void> stop() async {
    await _player.stop();
  }

  Future<void> dispose() async {
    await _player.dispose();
  }
}
