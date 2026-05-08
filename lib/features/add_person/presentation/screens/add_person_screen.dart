import 'dart:io';
import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:aurafarm/core/theme/app_colors.dart';
import 'package:aurafarm/core/theme/app_text_styles.dart';
import 'package:aurafarm/core/constants/app_constants.dart';
import 'package:aurafarm/features/add_person/providers/add_person_provider.dart';
import 'package:aurafarm/features/add_person/presentation/screens/face_capture_screen.dart';
import 'package:aurafarm/features/audio_trim/providers/audio_trim_provider.dart';
import 'package:aurafarm/features/audio_trim/presentation/screens/audio_trim_screen.dart';
import 'package:aurafarm/features/people/providers/people_provider.dart';
import 'package:aurafarm/shared/models/person_model.dart';
import 'package:aurafarm/shared/services/audio_service.dart';
import 'package:aurafarm/shared/services/storage_service.dart';
import 'package:aurafarm/shared/widgets/aura_button.dart';

class AddPersonScreen extends ConsumerWidget {
  const AddPersonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(addPersonProvider);
    final notifier = ref.read(addPersonProvider.notifier);

    return PopScope(
      onPopInvokedWithResult: (didPop, result) => notifier.reset(),
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          title: Text('Add Person', style: AppTextStyles.titleLarge),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              notifier.reset();
              context.pop();
            },
          ),
        ),
        body: Column(
          children: [
            _StepIndicator(currentStep: state.step),
            Expanded(
              child: SafeArea(
                top: false,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: KeyedSubtree(
                    key: ValueKey(state.step),
                    child: switch (state.step) {
                      0 => _NameStep(state: state, notifier: notifier),
                      1 => _FaceStep(state: state, notifier: notifier),
                      2 => _SongStep(state: state, notifier: notifier),
                      3 => _TrimStep(state: state, notifier: notifier),
                      _ => _ConfirmStep(state: state, notifier: notifier),
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  const _StepIndicator({required this.currentStep});

  static const _labels = ['Name', 'Face', 'Song', 'Trim', 'Save'];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppConstants.pagePadding, vertical: 16),
      child: Row(
        children: List.generate(_labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            return Expanded(
              child: Container(
                height: 1,
                color: i ~/ 2 < currentStep ? AppColors.orange : AppColors.grayMid,
              ),
            );
          }
          final step = i ~/ 2;
          final done = step < currentStep;
          final active = step == currentStep;
          return Column(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || active ? AppColors.orange : AppColors.bgCard,
                  border: Border.all(color: done || active ? AppColors.orange : AppColors.grayMid),
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, size: 14, color: AppColors.white)
                      : Text('${step + 1}', style: AppTextStyles.labelSmall.copyWith(
                          color: active ? AppColors.white : AppColors.grayLight,
                        )),
                ),
              ),
              const SizedBox(height: 4),
              Text(_labels[step], style: AppTextStyles.labelSmall.copyWith(
                color: active ? AppColors.orange : AppColors.grayLight,
              )),
            ],
          );
        }),
      ),
    );
  }
}

// ── Step 0: Name ──────────────────────────────────────────────────────────────

class _NameStep extends StatefulWidget {
  final AddPersonState state;
  final AddPersonNotifier notifier;
  const _NameStep({required this.state, required this.notifier});

  @override
  State<_NameStep> createState() => _NameStepState();
}

class _NameStepState extends State<_NameStep> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.state.name);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('What\'s their name?', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text('This will appear when their face is recognized.', style: AppTextStyles.bodySmall),
          const SizedBox(height: 32),
          TextField(
            controller: _ctrl,
            autofocus: true,
            style: AppTextStyles.bodyLarge,
            decoration: const InputDecoration(hintText: 'Enter name…'),
            textCapitalization: TextCapitalization.words,
            onChanged: widget.notifier.setName,
            onSubmitted: (_) => _next(),
          ),
          const Spacer(),
          AuraButton(
            label: 'Next',
            icon: Icons.arrow_forward,
            width: double.infinity,
            onPressed: widget.state.canProceedFromStep0 ? _next : null,
          ),
        ],
      ),
    );
  }

  void _next() {
    if (widget.state.canProceedFromStep0) widget.notifier.nextStep();
  }
}

// ── Step 1: Face ──────────────────────────────────────────────────────────────

class _FaceStep extends StatelessWidget {
  final AddPersonState state;
  final AddPersonNotifier notifier;
  const _FaceStep({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Capture face', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text('We\'ll take 3 photos to build ${state.name}\'s face profile.', style: AppTextStyles.bodySmall),
          const SizedBox(height: 32),
          if (state.faceImagePath != null)
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.orange, width: 2),
                ),
                child: ClipOval(child: Image.file(File(state.faceImagePath!), fit: BoxFit.cover)),
              ),
            )
          else
            Center(
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.bgCard,
                  border: Border.all(color: AppColors.grayMid),
                ),
                child: const Icon(Icons.face, color: AppColors.grayMid, size: 64),
              ),
            ),
          const Spacer(),
          if (state.faceImagePath != null) ...[
            AuraButton(
              label: 'Re-capture',
              icon: Icons.camera_alt,
              width: double.infinity,
              outlined: true,
              onPressed: () => _openCapture(context),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: AuraButton(
                  label: 'Back',
                  icon: Icons.arrow_back,
                  outlined: true,
                  onPressed: notifier.prevStep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AuraButton(
                  label: state.faceImagePath != null ? 'Next' : 'Open Camera',
                  icon: state.faceImagePath != null ? Icons.arrow_forward : Icons.camera_alt,
                  onPressed: state.faceImagePath != null
                      ? notifier.nextStep
                      : () => _openCapture(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _openCapture(BuildContext context) async {
    final result = await Navigator.push<FaceCaptureResult>(
      context,
      MaterialPageRoute(builder: (_) => const FaceCaptureScreen()),
    );
    if (result != null) {
      notifier.setFaceResult(imagePath: result.imagePath, embeddings: result.embeddings);
    }
  }
}

// ── Step 2: Song ──────────────────────────────────────────────────────────────

class _SongStep extends StatelessWidget {
  final AddPersonState state;
  final AddPersonNotifier notifier;
  const _SongStep({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Pick a song', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text('Choose an MP3 from your device for ${state.name}.', style: AppTextStyles.bodySmall),
          const SizedBox(height: 32),
          if (state.songPath != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppConstants.cardRadius),
                border: Border.all(color: AppColors.orange, width: 1),
              ),
              child: Row(
                children: [
                  const Icon(Icons.music_note, color: AppColors.orange),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      state.songPath!.split('/').last.split('\\').last,
                      style: AppTextStyles.bodyMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          const Spacer(),
          if (state.songPath != null) ...[
            AuraButton(
              label: 'Change Song',
              icon: Icons.folder_open,
              width: double.infinity,
              outlined: true,
              onPressed: () => _pickSong(context),
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: AuraButton(
                  label: 'Back',
                  icon: Icons.arrow_back,
                  outlined: true,
                  onPressed: notifier.prevStep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AuraButton(
                  label: state.songPath != null ? 'Next' : 'Browse Files',
                  icon: state.songPath != null ? Icons.arrow_forward : Icons.folder_open,
                  onPressed: state.songPath != null
                      ? notifier.nextStep
                      : () => _pickSong(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickSong(BuildContext context) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.audio,
      allowMultiple: false,
    );
    if (result != null && result.files.isNotEmpty) {
      final path = result.files.first.path;
      if (path != null) {
        final savedPath = await StorageService.instance.saveSongFile(File(path));
        notifier.setSong(savedPath);
      }
    }
  }
}

// ── Step 3: Trim ──────────────────────────────────────────────────────────────

class _TrimStep extends ConsumerStatefulWidget {
  final AddPersonState state;
  final AddPersonNotifier notifier;
  const _TrimStep({required this.state, required this.notifier});

  @override
  ConsumerState<_TrimStep> createState() => _TrimStepState();
}

class _TrimStepState extends ConsumerState<_TrimStep> {
  late final PlayerController _waveController;
  bool _waveReady = false;

  (int, int) get _key => (widget.state.snippetStartMs, widget.state.snippetEndMs);

  @override
  void initState() {
    super.initState();
    _waveController = PlayerController();
    _loadWaveform();
  }

  @override
  void dispose() {
    _waveController.dispose();
    AudioService.instance.stop();
    super.dispose();
  }

  Future<void> _loadWaveform() async {
    if (widget.state.songPath == null) return;
    await _waveController.preparePlayer(
      path: widget.state.songPath!,
      shouldExtractWaveform: true,
      noOfSamples: 200,
    );
    final totalMs = _waveController.maxDuration;
    if (mounted) {
      ref.read(audioTrimProvider(_key).notifier).setTotalMs(totalMs);
      setState(() => _waveReady = true);
    }
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final trimState = ref.watch(audioTrimProvider(_key));
    final trimNotifier = ref.read(audioTrimProvider(_key).notifier);

    return Padding(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Trim snippet', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text(
            'Select the portion that plays when ${widget.state.name}\'s face is recognized.',
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 16),
          if (!_waveReady)
            const Center(child: CircularProgressIndicator(color: AppColors.orange))
          else ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_fmt(trimState.startMs), style: AppTextStyles.orangeLabel),
                Text(
                  '${(trimState.durationMs / 1000).toStringAsFixed(1)}s selected',
                  style: AppTextStyles.bodySmall,
                ),
                Text(_fmt(trimState.endMs), style: AppTextStyles.orangeLabel),
              ],
            ),
            const SizedBox(height: 12),
            WaveformTrimmer(
              waveController: _waveController,
              trimState: trimState,
              notifier: trimNotifier,
            ),
          ],
          const Spacer(),
          if (_waveReady) ...[
            AuraButton(
              label: trimState.isPlaying ? 'Stop' : 'Preview',
              icon: trimState.isPlaying ? Icons.stop : Icons.play_arrow,
              outlined: true,
              width: double.infinity,
              onPressed: () async {
                if (trimState.isPlaying) {
                  await AudioService.instance.stop();
                  trimNotifier.setPlaying(false);
                } else {
                  trimNotifier.setPlaying(true);
                  await AudioService.instance.previewClip(
                    widget.state.songPath!, trimState.startMs, trimState.endMs,
                  );
                  trimNotifier.setPlaying(false);
                }
              },
            ),
            const SizedBox(height: 12),
          ],
          Row(
            children: [
              Expanded(
                child: AuraButton(
                  label: 'Back',
                  icon: Icons.arrow_back,
                  outlined: true,
                  onPressed: widget.notifier.prevStep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AuraButton(
                  label: 'Next',
                  icon: Icons.arrow_forward,
                  onPressed: () {
                    widget.notifier.setSnippet(trimState.startMs, trimState.endMs);
                    widget.notifier.nextStep();
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Step 4: Confirm & Save ────────────────────────────────────────────────────

class _ConfirmStep extends ConsumerWidget {
  final AddPersonState state;
  final AddPersonNotifier notifier;
  const _ConfirmStep({required this.state, required this.notifier});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('All set!', style: AppTextStyles.displayMedium),
          const SizedBox(height: 8),
          Text('Review and save ${state.name}\'s aura profile.', style: AppTextStyles.bodySmall),
          const SizedBox(height: 32),
          if (state.faceImagePath != null)
            Center(
              child: Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.orange, width: 3),
                  boxShadow: [BoxShadow(color: AppColors.orangeGlow, blurRadius: 20, spreadRadius: 4)],
                ),
                child: ClipOval(child: Image.file(File(state.faceImagePath!), fit: BoxFit.cover)),
              ),
            ),
          const SizedBox(height: 20),
          Center(child: Text(state.name, style: AppTextStyles.displayMedium)),
          const SizedBox(height: 8),
          Center(
            child: Text(
              '${(state.snippetEndMs - state.snippetStartMs) ~/ 1000}s snippet ready',
              style: AppTextStyles.orangeLabel,
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: AuraButton(
                  label: 'Back',
                  icon: Icons.arrow_back,
                  outlined: true,
                  onPressed: notifier.prevStep,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AuraButton(
                  label: 'Save Aura',
                  icon: Icons.auto_awesome,
                  isLoading: state.isSaving,
                  onPressed: () => _save(context, ref),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    notifier.setSaving(true);
    const uuid = Uuid();
    final person = Person(
      id: uuid.v4(),
      name: state.name.trim(),
      faceImagePath: state.faceImagePath,
      faceEmbeddings: state.faceEmbeddings,
      songPath: state.songPath,
      snippetStartMs: state.snippetStartMs,
      snippetEndMs: state.snippetEndMs,
      createdAt: DateTime.now(),
    );
    await ref.read(peopleProvider.notifier).upsert(person);
    notifier.reset();
    if (context.mounted) {
      context.go('/people');
    }
  }
}
