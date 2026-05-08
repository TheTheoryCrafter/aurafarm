import 'package:flutter_riverpod/flutter_riverpod.dart';

class AudioTrimState {
  final int startMs;
  final int endMs;
  final int totalMs;
  final bool isPlaying;

  const AudioTrimState({
    this.startMs = 0,
    this.endMs = 10000,
    this.totalMs = 60000,
    this.isPlaying = false,
  });

  AudioTrimState copyWith({int? startMs, int? endMs, int? totalMs, bool? isPlaying}) =>
      AudioTrimState(
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        totalMs: totalMs ?? this.totalMs,
        isPlaying: isPlaying ?? this.isPlaying,
      );

  int get durationMs => endMs - startMs;
}

class AudioTrimNotifier extends StateNotifier<AudioTrimState> {
  AudioTrimNotifier({required int startMs, required int endMs})
      : super(AudioTrimState(startMs: startMs, endMs: endMs));

  void setTotalMs(int ms) {
    final clampedEnd = state.endMs.clamp(0, ms);
    state = state.copyWith(totalMs: ms, endMs: clampedEnd);
  }

  void setStart(int ms) {
    final clamped = ms.clamp(0, state.endMs - 1000);
    state = state.copyWith(startMs: clamped);
  }

  void setEnd(int ms) {
    final clamped = ms.clamp(state.startMs + 1000, state.totalMs);
    state = state.copyWith(endMs: clamped);
  }

  void setPlaying(bool val) => state = state.copyWith(isPlaying: val);
}

final audioTrimProvider = StateNotifierProvider.autoDispose
    .family<AudioTrimNotifier, AudioTrimState, (int, int)>(
  (_, args) => AudioTrimNotifier(startMs: args.$1, endMs: args.$2),
);
