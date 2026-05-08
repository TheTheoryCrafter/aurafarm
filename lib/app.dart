import 'package:flutter/material.dart';
import 'package:aurafarm/core/theme/app_theme.dart';
import 'package:aurafarm/core/router/app_router.dart';

class AuraFarmApp extends StatelessWidget {
  const AuraFarmApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Aura Farm',
      theme: AppTheme.dark,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
