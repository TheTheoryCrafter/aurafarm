import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurafarm/core/theme/app_colors.dart';

class AuraBottomNav extends StatelessWidget {
  final Widget child;
  const AuraBottomNav({super.key, required this.child});

  int _locationToIndex(String location) {
    if (location.startsWith('/camera')) return 1;
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.toString();
    final currentIndex = _locationToIndex(location);

    return Scaffold(
      body: child,
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppColors.bgSecondary,
          border: Border(top: BorderSide(color: AppColors.grayMid, width: 0.5)),
        ),
        child: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (i) {
            if (i == 0) context.go('/people');
            if (i == 1) context.go('/camera');
          },
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people),
              label: 'People',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.camera_alt_outlined),
              activeIcon: Icon(Icons.camera_alt),
              label: 'Camera',
            ),
          ],
        ),
      ),
    );
  }
}
