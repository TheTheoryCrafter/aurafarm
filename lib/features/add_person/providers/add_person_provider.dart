import 'package:flutter_riverpod/flutter_riverpod.dart';

class AddPersonState {
  final int step;
  final String name;
  final String? faceImagePath;
  final List<List<double>> faceEmbeddings;
  final String? songPath;
  final int snippetStartMs;
  final int snippetEndMs;
  final bool isSaving;

  const AddPersonState({
    this.step = 0,
    this.name = '',
    this.faceImagePath,
    this.faceEmbeddings = const [],
    this.songPath,
    this.snippetStartMs = 0,
    this.snippetEndMs = 10000,
    this.isSaving = false,
  });

  AddPersonState copyWith({
    int? step,
    String? name,
    String? faceImagePath,
    List<List<double>>? faceEmbeddings,
    String? songPath,
    int? snippetStartMs,
    int? snippetEndMs,
    bool? isSaving,
  }) {
    return AddPersonState(
      step: step ?? this.step,
      name: name ?? this.name,
      faceImagePath: faceImagePath ?? this.faceImagePath,
      faceEmbeddings: faceEmbeddings ?? this.faceEmbeddings,
      songPath: songPath ?? this.songPath,
      snippetStartMs: snippetStartMs ?? this.snippetStartMs,
      snippetEndMs: snippetEndMs ?? this.snippetEndMs,
      isSaving: isSaving ?? this.isSaving,
    );
  }

  bool get canProceedFromStep0 => name.trim().isNotEmpty;
  bool get canProceedFromStep1 => faceImagePath != null;
  bool get canProceedFromStep2 => songPath != null;
}

class AddPersonNotifier extends StateNotifier<AddPersonState> {
  AddPersonNotifier() : super(const AddPersonState());

  void setName(String name) => state = state.copyWith(name: name);
  void nextStep() => state = state.copyWith(step: state.step + 1);
  void prevStep() => state = state.copyWith(step: state.step - 1);

  void setFaceResult({required String imagePath, required List<List<double>> embeddings}) {
    state = state.copyWith(faceImagePath: imagePath, faceEmbeddings: embeddings);
  }

  void setSong(String path) => state = state.copyWith(songPath: path);

  void setSnippet(int startMs, int endMs) =>
      state = state.copyWith(snippetStartMs: startMs, snippetEndMs: endMs);

  void setSaving(bool val) => state = state.copyWith(isSaving: val);

  void reset() => state = const AddPersonState();
}

final addPersonProvider = StateNotifierProvider.autoDispose<AddPersonNotifier, AddPersonState>(
  (_) => AddPersonNotifier(),
);
