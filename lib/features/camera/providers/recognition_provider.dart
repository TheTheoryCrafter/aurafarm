import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurafarm/shared/models/person_model.dart';
import 'package:aurafarm/shared/services/audio_service.dart';

class RecognitionState {
  final Person? person;
  final bool isActive;

  const RecognitionState({this.person, this.isActive = false});
}

class RecognitionNotifier extends StateNotifier<RecognitionState> {
  RecognitionNotifier() : super(const RecognitionState()) {
    _completeSub = AudioService.instance.onComplete.listen((_) {
      if (mounted) state = const RecognitionState();
    });
  }

  late final StreamSubscription<void> _completeSub;

  void onPersonRecognized(Person person) {
    // Different person — switch immediately
    if (state.person?.id != person.id) {
      state = RecognitionState(person: person, isActive: true);
      if (person.hasSong) {
        AudioService.instance.playSnippet(
          person.songPath!, person.snippetStartMs, person.snippetEndMs,
        );
      }
    }
    // Same person already playing — do nothing, let snippet finish
  }

  void stop() {
    AudioService.instance.stop();
    state = const RecognitionState();
  }

  @override
  void dispose() {
    _completeSub.cancel();
    super.dispose();
  }
}

final recognitionProvider = StateNotifierProvider.autoDispose<RecognitionNotifier, RecognitionState>(
  (_) => RecognitionNotifier(),
);
