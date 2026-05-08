import 'package:go_router/go_router.dart';
import 'package:aurafarm/features/camera/presentation/screens/camera_screen.dart';
import 'package:aurafarm/features/people/presentation/screens/people_screen.dart';
import 'package:aurafarm/features/people/presentation/screens/person_detail_screen.dart';
import 'package:aurafarm/features/add_person/presentation/screens/add_person_screen.dart';
import 'package:aurafarm/features/audio_trim/presentation/screens/audio_trim_screen.dart';
import 'package:aurafarm/shared/widgets/aura_bottom_nav.dart';

final appRouter = GoRouter(
  initialLocation: '/people',
  routes: [
    ShellRoute(
      builder: (context, state, child) => AuraBottomNav(child: child),
      routes: [
        GoRoute(
          path: '/camera',
          pageBuilder: (context, state) => const NoTransitionPage(child: CameraScreen()),
        ),
        GoRoute(
          path: '/people',
          pageBuilder: (context, state) => const NoTransitionPage(child: PeopleScreen()),
        ),
      ],
    ),
    GoRoute(
      path: '/people/:id',
      builder: (context, state) => PersonDetailScreen(personId: state.pathParameters['id']!),
    ),
    GoRoute(
      path: '/add-person',
      builder: (context, state) => const AddPersonScreen(),
    ),
    GoRoute(
      path: '/audio-trim',
      builder: (context, state) {
        final extra = state.extra as Map<String, dynamic>;
        return AudioTrimScreen(
          filePath: extra['filePath'] as String,
          startMs: extra['startMs'] as int? ?? 0,
          endMs: extra['endMs'] as int?,
        );
      },
    ),
  ],
);
