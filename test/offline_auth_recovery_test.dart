import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/offline/application/offline_controller.dart';
import 'package:invigilator_app/features/offline/data/offline_repository.dart';
import 'package:invigilator_app/features/sync/presentation/sync_status_screen.dart';

class _Repository extends OfflineRepository {
  _Repository() : super(dio: Dio());
  List<Map<String, Object?>> rows = [];
  @override
  Future<Map<String, Object?>?> cached(String owner) async => null;
  @override
  Future<List<Map<String, Object?>>> history(String owner) async => rows;
  @override
  Future<void> sync(String owner, bool Function() stillOwner) async {
    rows = [];
  }
}

DioException failure(int? status) {
  final request = RequestOptions(path: '/api/attendance/sync');
  return DioException(
    requestOptions: request,
    response: status == null
        ? null
        : Response(requestOptions: request, statusCode: status),
  );
}

void main() {
  testWidgets(
    'healthy sessions and forbidden requests hide recovery; 401 displays it',
    (tester) async {
      final repository = _Repository();
      final controller = OfflineController('1', repository, () => true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [offlineProvider.overrideWith((ref) => controller)],
          child: const MaterialApp(home: Scaffold(body: SyncStatusScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsNothing);
      controller.failed(failure(403));
      controller.changed();
      await tester.pumpAndSettle();
      expect(controller.requiresSignIn, isFalse);
      expect(find.text('Sign in'), findsNothing);
      controller.failed(failure(401));
      controller.changed();
      await tester.pumpAndSettle();
      expect(
        find.text('Sign in with the same account to sync attendance.'),
        findsOneWidget,
      );
      expect(find.text('Sign in'), findsOneWidget);
      expect(
        find.textContaining('Sign in with the same account'),
        findsOneWidget,
      );
      controller.failed(failure(null));
      controller.changed();
      await tester.pumpAndSettle();
      expect(find.text('Sign in'), findsOneWidget);
      repository.rows = [
        {
          'outcome': null,
          'student': 'Student',
          'assignment': 'CSC',
          'payload': '{"computerNumber":"2022004264"}',
        },
      ];
      await controller.load();
      await controller.sync();
      await tester.pumpAndSettle();
      expect(controller.requiresSignIn, isFalse);
      expect(find.text('Sign in'), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets('signed-out users get a separate sign-in recovery action', (
    tester,
  ) async {
    final controller = OfflineController(
      null,
      _Repository(),
      () => false,
      authenticated: false,
    );
    await tester.pumpWidget(
      ProviderScope(
        overrides: [offlineProvider.overrideWith((ref) => controller)],
        child: const MaterialApp(home: Scaffold(body: SyncStatusScreen())),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('Sign in with the same account to sync attendance.'),
      findsOneWidget,
    );
    expect(find.text('Sign in'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
