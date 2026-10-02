import 'core/storage/secure_storage.dart';
import 'features/auth/application/auth_providers.dart';
import 'features/auth/domain/user.dart';
import 'app/router/app_router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:invigilator_app/app/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();
  try {
    final owner = await SecureStorage.read('offlineStaffId');
    if (owner != null) {
      container
          .read(currentUserProvider.notifier)
          .setUser(User(offlineStaffId: owner));
      AppRouter.router.go('/offline-attendance');
    }
  } catch (_) {
    // If secure storage is unavailable, require login; never guess an owner.
  }
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const InvigilatorApp(),
    ),
  );
}
