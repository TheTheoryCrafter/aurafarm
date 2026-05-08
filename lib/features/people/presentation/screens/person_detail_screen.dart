import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurafarm/core/theme/app_colors.dart';
import 'package:aurafarm/core/theme/app_text_styles.dart';
import 'package:aurafarm/core/constants/app_constants.dart';
import 'package:aurafarm/features/people/providers/people_provider.dart';
import 'package:aurafarm/shared/services/audio_service.dart';
import 'package:aurafarm/shared/widgets/aura_button.dart';

class PersonDetailScreen extends ConsumerStatefulWidget {
  final String personId;
  const PersonDetailScreen({super.key, required this.personId});

  @override
  ConsumerState<PersonDetailScreen> createState() => _PersonDetailScreenState();
}

class _PersonDetailScreenState extends ConsumerState<PersonDetailScreen> {
  bool _isPlaying = false;

  @override
  void dispose() {
    AudioService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleProvider);

    return peopleAsync.when(
      loading: () => const Scaffold(backgroundColor: AppColors.bgPrimary, body: Center(child: CircularProgressIndicator(color: AppColors.orange))),
      error: (e, _) => Scaffold(backgroundColor: AppColors.bgPrimary, body: Center(child: Text('Error', style: AppTextStyles.bodyMedium))),
      data: (people) {
        final person = people.where((p) => p.id == widget.personId).firstOrNull;
        if (person == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => context.pop());
          return const SizedBox.shrink();
        }

        return Scaffold(
          backgroundColor: AppColors.bgPrimary,
          appBar: AppBar(
            title: Text(person.name, style: AppTextStyles.titleLarge),
            actions: [
              IconButton(
                icon: const Icon(Icons.delete_outline, color: AppColors.error),
                onPressed: () => _confirmDelete(context, ref, person.id),
              ),
            ],
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Face photo
                Center(
                  child: Container(
                    width: 160,
                    height: 160,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.orange, width: 2),
                    ),
                    child: ClipOval(
                      child: person.faceImagePath != null && File(person.faceImagePath!).existsSync()
                          ? Image.file(File(person.faceImagePath!), fit: BoxFit.cover)
                          : Container(color: AppColors.bgCard, child: const Icon(Icons.person, color: AppColors.grayMid, size: 72)),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                // Face status
                _StatusRow(
                  icon: Icons.face,
                  label: 'Face Profile',
                  value: person.hasFace ? 'Registered (${person.faceEmbeddings.length} captures)' : 'Not registered',
                  ok: person.hasFace,
                ),
                const SizedBox(height: 16),
                // Song status
                _StatusRow(
                  icon: Icons.music_note,
                  label: 'Song Snippet',
                  value: person.hasSong
                      ? '${person.snippetDuration.inSeconds}s  (${_fmt(person.snippetStart)} – ${_fmt(person.snippetEnd)})'
                      : 'No song assigned',
                  ok: person.hasSong,
                ),
                const SizedBox(height: 32),
                // Preview snippet button
                if (person.hasSong)
                  AuraButton(
                    label: _isPlaying ? 'Stop Preview' : 'Preview Snippet',
                    icon: _isPlaying ? Icons.stop : Icons.play_arrow,
                    width: double.infinity,
                    onPressed: () async {
                      if (_isPlaying) {
                        await AudioService.instance.stop();
                        setState(() => _isPlaying = false);
                      } else {
                        setState(() => _isPlaying = true);
                        await AudioService.instance.playSnippet(person.songPath!, person.snippetStartMs, person.snippetEndMs);
                        setState(() => _isPlaying = false);
                      }
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  void _confirmDelete(BuildContext context, WidgetRef ref, String id) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Remove person?', style: AppTextStyles.titleMedium),
        content: Text('Face profile and song snippet will be deleted.', style: AppTextStyles.bodySmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: AppTextStyles.bodyMedium)),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(peopleProvider.notifier).delete(id);
              context.pop();
            },
            child: Text('Remove', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool ok;
  const _StatusRow({required this.icon, required this.label, required this.value, required this.ok});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppConstants.cardRadius),
        border: Border.all(color: ok ? AppColors.orangeGlow : AppColors.grayMid, width: ok ? 1 : 0.5),
      ),
      child: Row(
        children: [
          Icon(icon, color: ok ? AppColors.orange : AppColors.grayLight, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: AppTextStyles.labelSmall),
                const SizedBox(height: 2),
                Text(value, style: AppTextStyles.bodySmall.copyWith(color: ok ? AppColors.textPrimary : AppColors.grayLight)),
              ],
            ),
          ),
          Icon(ok ? Icons.check_circle : Icons.radio_button_unchecked, color: ok ? AppColors.orange : AppColors.grayMid, size: 18),
        ],
      ),
    );
  }
}
