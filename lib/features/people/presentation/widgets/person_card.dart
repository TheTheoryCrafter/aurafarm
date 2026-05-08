import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurafarm/core/theme/app_colors.dart';
import 'package:aurafarm/core/theme/app_text_styles.dart';
import 'package:aurafarm/core/constants/app_constants.dart';
import 'package:aurafarm/features/people/providers/people_provider.dart';
import 'package:aurafarm/shared/models/person_model.dart';

class PersonCard extends ConsumerWidget {
  final Person person;
  const PersonCard({super.key, required this.person});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () => context.push('/people/${person.id}'),
      onLongPress: () => _confirmDelete(context, ref),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppConstants.cardRadius),
          border: Border.all(color: AppColors.grayMid, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _FacePhoto(path: person.faceImagePath)),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(person.name, style: AppTextStyles.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        person.isComplete ? Icons.music_note : Icons.music_off_outlined,
                        size: 12,
                        color: person.isComplete ? AppColors.orange : AppColors.grayLight,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        person.isComplete
                            ? '${(person.snippetDuration.inSeconds)}s snippet'
                            : 'No song',
                        style: AppTextStyles.bodySmall,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.bgCard,
        title: Text('Remove ${person.name}?', style: AppTextStyles.titleMedium),
        content: Text('This will delete their face profile and song snippet.', style: AppTextStyles.bodySmall),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: AppTextStyles.bodyMedium)),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              ref.read(peopleProvider.notifier).delete(person.id);
            },
            child: Text('Remove', style: AppTextStyles.bodyMedium.copyWith(color: AppColors.error)),
          ),
        ],
      ),
    );
  }
}

class _FacePhoto extends StatelessWidget {
  final String? path;
  const _FacePhoto({this.path});

  @override
  Widget build(BuildContext context) {
    if (path != null && File(path!).existsSync()) {
      return ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(AppConstants.cardRadius)),
        child: Image.file(File(path!), fit: BoxFit.cover, width: double.infinity),
      );
    }
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.bgSecondary,
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppConstants.cardRadius)),
      ),
      child: const Center(child: Icon(Icons.person, color: AppColors.grayMid, size: 48)),
    );
  }
}
