import 'package:flutter/material.dart';
import 'package:invigilator_app/app/router/app_router.dart';
import 'package:invigilator_app/app/constants/app_theme.dart';

class InvigilatorApp extends StatelessWidget {
  const InvigilatorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Invigilator App',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme(),
      routerConfig: AppRouter.router,
    );
  }
}
