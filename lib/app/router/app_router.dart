import 'package:go_router/go_router.dart';
import 'package:invigilator_app/core/layout/app_shell.dart';
import 'package:invigilator_app/features/auth/presentation/login_screen.dart';
import 'package:invigilator_app/features/attendance/presentation/attendance_screen.dart';
import 'package:invigilator_app/features/examinations/presentation/dashboard_screen.dart';
import 'package:invigilator_app/features/incidents/presentation/incidents_screen.dart';
import 'package:invigilator_app/features/sync/presentation/sync_status_screen.dart';
import 'package:invigilator_app/features/verification/presentation/verification_screen.dart';

class AppRouter {
  static final router = GoRouter(
    initialLocation: '/login',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const DashboardScreen()),
          GoRoute(path: '/verification', builder: (context, state) => const VerificationScreen()),
          GoRoute(path: '/attendance', builder: (context, state) => const AttendanceScreen()),
          GoRoute(path: '/sync', builder: (context, state) => const SyncStatusScreen()),
          GoRoute(path: '/incidents', builder: (context, state) => const IncidentsScreen()),
        ],
      ),
    ],
  );
}
