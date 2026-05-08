import 'package:audio_waveforms/audio_waveforms.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurafarm/core/theme/app_colors.dart';
import 'package:aurafarm/core/theme/app_text_styles.dart';
import 'package:aurafarm/core/constants/app_constants.dart';
import 'package:aurafarm/features/audio_trim/providers/audio_trim_provider.dart';
import 'package:aurafarm/shared/services/audio_service.dart';
import 'package:aurafarm/shared/widgets/aura_button.dart';

class AudioTrimScreen extends ConsumerStatefulWidget {
  final String filePath;
  final int startMs;
  final int? endMs;

  const AudioTrimScreen({
    super.key,
    required this.filePath,
    this.startMs = 0,
    this.endMs,
  });

  @override
  ConsumerState<AudioTrimScreen> createState() => _AudioTrimScreenState();
}

class _AudioTrimScreenState extends ConsumerState<AudioTrimScreen> {
  late final PlayerController _waveController;
  bool _waveReady = false;

  (int, int) get _providerKey => (widget.startMs, widget.endMs ?? AppConstants.defaultSnippetMs);

  @override
  void initState() {
    super.initState();
    _waveController = PlayerController();
    _loadWaveform();
  }

  Future<void> _loadWaveform() async {
    await _waveController.preparePlayer(
      path: widget.filePath,
      shouldExtractWaveform: true,
      noOfSamples: 200,
    );
    final totalMs = _waveController.maxDuration;
    if (mounted) {
      ref.read(audioTrimProvider(_providerKey).notifier).setTotalMs(totalMs);
      setState(() => _waveReady = true);
    }
  }

  @override
  void dispose() {
    _waveController.dispose();
    AudioService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final trimState = ref.watch(audioTrimProvider(_providerKey));
    final notifier = ref.read(audioTrimProvider(_providerKey).notifier);
    final fileName = widget.filePath.split('/').last.split('\\').last;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text(fileName, style: AppTextStyles.titleMedium, overflow: TextOverflow.ellipsis),
      ),
      body: _waveReady
          ? _buildBody(context, trimState, notifier)
          : const Center(child: CircularProgressIndicator(color: AppColors.orange)),
    );
  }

  Widget _buildBody(BuildContext context, AudioTrimState trimState, AudioTrimNotifier notifier) {
    return Padding(
      padding: const EdgeInsets.all(AppConstants.pagePadding),
      child: Column(
        children: [
          const SizedBox(height: 16),
          // Duration label
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
          // Waveform + handles
          WaveformTrimmer(
            waveController: _waveController,
            trimState: trimState,
            notifier: notifier,
          ),
          const SizedBox(height: 32),
          // Preview button
          AuraButton(
            label: trimState.isPlaying ? 'Stop' : 'Preview',
            icon: trimState.isPlaying ? Icons.stop : Icons.play_arrow,
            outlined: true,
            width: double.infinity,
            onPressed: () async {
              if (trimState.isPlaying) {
                await AudioService.instance.stop();
                notifier.setPlaying(false);
              } else {
                notifier.setPlaying(true);
                await AudioService.instance.previewClip(
                  widget.filePath, trimState.startMs, trimState.endMs,
                );
                notifier.setPlaying(false);
              }
            },
          ),
          const SizedBox(height: 12),
          AuraButton(
            label: 'Set Snippet',
            icon: Icons.check,
            width: double.infinity,
            onPressed: () {
              AudioService.instance.stop();
              context.pop({'startMs': trimState.startMs, 'endMs': trimState.endMs});
            },
          ),
        ],
      ),
    );
  }

  String _fmt(int ms) {
    final d = Duration(milliseconds: ms);
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class WaveformTrimmer extends StatefulWidget {
  final PlayerController waveController;
  final AudioTrimState trimState;
  final AudioTrimNotifier notifier;

  const WaveformTrimmer({
    super.key,
    required this.waveController,
    required this.trimState,
    required this.notifier,
  });

  @override
  State<WaveformTrimmer> createState() => _WaveformTrimmerState();
}

class _WaveformTrimmerState extends State<WaveformTrimmer> {
  static const double _waveHeight = 90;
  static const double _handleWidth = 8;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        final total = widget.trimState.totalMs;
        final startX = (widget.trimState.startMs / total) * w;
        final endX = (widget.trimState.endMs / total) * w;

        return SizedBox(
          width: w,
          height: _waveHeight + 40,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Waveform — padding: zero so bars start exactly at x=0
              Positioned(
                top: 0, left: 0, right: 0,
                child: AudioFileWaveforms(
                  size: Size(w, _waveHeight),
                  playerController: widget.waveController,
                  waveformType: WaveformType.fitWidth,
                  enableSeekGesture: false,
                  padding: EdgeInsets.zero,
                  playerWaveStyle: const PlayerWaveStyle(
                    fixedWaveColor: AppColors.grayMid,
                    liveWaveColor: AppColors.orange,
                    waveCap: StrokeCap.round,
                    spacing: 4,
                    showSeekLine: false,
                    waveThickness: 2,
                    seekLineColor: AppColors.orange,
                    seekLineThickness: 2,
                  ),
                ),
              ),
              // Selected range highlight
              Positioned(
                left: startX,
                top: 0,
                width: endX - startX,
                height: _waveHeight,
                child: Container(color: AppColors.orangeGlow2),
              ),
              // Start handle
              Positioned(
                left: startX - _handleWidth / 2,
                top: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    final newX = (startX + d.delta.dx).clamp(0.0, w);
                    widget.notifier.setStart(((newX / w) * total).toInt());
                  },
                  child: TrimHandle(label: _fmtMs(widget.trimState.startMs)),
                ),
              ),
              // End handle
              Positioned(
                left: endX - _handleWidth / 2,
                top: 0,
                child: GestureDetector(
                  onHorizontalDragUpdate: (d) {
                    final newX = (endX + d.delta.dx).clamp(0.0, w);
                    widget.notifier.setEnd(((newX / w) * total).toInt());
                  },
                  child: TrimHandle(label: _fmtMs(widget.trimState.endMs), isEnd: true),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _fmtMs(int ms) {
    final s = ms ~/ 1000;
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }
}

class TrimHandle extends StatelessWidget {
  final String label;
  final bool isEnd;
  const TrimHandle({super.key, required this.label, this.isEnd = false});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 8,
          height: 90,
          decoration: BoxDecoration(
            color: AppColors.orange,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 4),
        Text(label, style: AppTextStyles.labelSmall.copyWith(color: AppColors.orange)),
      ],
    );
  }
}
