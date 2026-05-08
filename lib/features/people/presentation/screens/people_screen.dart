import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:aurafarm/core/theme/app_colors.dart';
import 'package:aurafarm/core/theme/app_text_styles.dart';
import 'package:aurafarm/core/constants/app_constants.dart';
import 'package:aurafarm/features/people/providers/people_provider.dart';
import 'package:aurafarm/features/people/presentation/widgets/person_card.dart';

class PeopleScreen extends ConsumerWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final peopleAsync = ref.watch(peopleProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        title: Text('Aura Farm', style: AppTextStyles.titleLarge),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text('PEOPLE', style: AppTextStyles.orangeLabel),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/add-person'),
        child: const Icon(Icons.add, size: 28),
      ),
      body: peopleAsync.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.orange),
        ),
        error: (e, _) => Center(
          child: Text('Error loading people', style: AppTextStyles.bodyMedium),
        ),
        data: (people) {
          if (people.isEmpty) return _EmptyState();
          return GridView.builder(
            padding: const EdgeInsets.all(AppConstants.pagePadding),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 0.85,
            ),
            itemCount: people.length,
            itemBuilder: (context, i) => PersonCard(person: people[i])
                .animate()
                .fadeIn(delay: (50 * i).ms, duration: 300.ms)
                .slideY(begin: 0.1, end: 0),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.bgCard,
              border: Border.all(color: AppColors.grayMid),
            ),
            child: const Icon(Icons.person_add_outlined, color: AppColors.orange, size: 36),
          ),
          const SizedBox(height: 20),
          Text('No auras yet', style: AppTextStyles.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tap + to register someone\nand assign their song',
            style: AppTextStyles.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.05, end: 0),
    );
  }
}
