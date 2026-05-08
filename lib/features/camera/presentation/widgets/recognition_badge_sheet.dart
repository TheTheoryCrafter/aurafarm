import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aurafarm/core/theme/app_colors.dart';
import 'package:aurafarm/core/theme/app_text_styles.dart';
import 'package:aurafarm/shared/models/person_model.dart';

class RecognitionBadgeSheet extends StatelessWidget {
  final Person person;
  const RecognitionBadgeSheet({super.key, required this.person});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.orange, width: 1.5),
        boxShadow: [
          BoxShadow(color: AppColors.orangeGlow, blurRadius: 24, spreadRadius: 4),
        ],
      ),
      child: Row(
        children: [
          // Face avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.orange, width: 2),
            ),
            child: ClipOval(
              child: person.faceImagePath != null && File(person.faceImagePath!).existsSync()
                  ? Image.file(File(person.faceImagePath!), fit: BoxFit.cover)
                  : Container(
                      color: AppColors.bgSecondary,
                      child: const Icon(Icons.person, color: AppColors.grayLight, size: 28),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(person.name, style: AppTextStyles.titleMedium),
                const SizedBox(height: 4),
                Row(
                  children: [
                    _AudioBars(),
                    const SizedBox(width: 8),
                    Text('Playing aura…', style: AppTextStyles.bodySmall.copyWith(color: AppColors.orange)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    )
    .animate()
    .slideY(begin: 0.3, end: 0, duration: 300.ms, curve: Curves.easeOut)
    .fadeIn(duration: 250.ms);
  }
}

class _AudioBars extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(4, (i) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 1.5),
        width: 3,
        height: 12,
        decoration: BoxDecoration(
          color: AppColors.orange,
          borderRadius: BorderRadius.circular(2),
        ),
      )
      .animate(onPlay: (c) => c.repeat(reverse: true))
      .scaleY(
        begin: 0.3,
        end: 1.0,
        duration: Duration(milliseconds: 300 + i * 80),
        curve: Curves.easeInOut,
        alignment: Alignment.bottomCenter,
      )),
    );
  }
}
