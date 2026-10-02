import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:go_router/go_router.dart';
import 'package:invigilator_app/features/auth/application/auth_providers.dart';
import 'package:invigilator_app/features/auth/domain/user.dart';
import 'package:invigilator_app/features/examinations/presentation/dashboard_screen.dart';
import 'package:invigilator_app/features/examinations/application/exam_providers.dart';
import 'package:invigilator_app/features/examinations/data/exam_repository.dart';
import 'package:invigilator_app/features/examinations/domain/exam_assignment.dart';
import 'package:invigilator_app/features/verification/presentation/verification_screen.dart';

class _ExamRepository extends ExamRepository {
  ExamAssignment assignment = ExamAssignment(
    examSessionId: 1,
    venueId: 2,
    courseCode: 'CSC101',
    examDate: '2026-10-02',
    startTime: '09:00',
    endTime: '12:00',
    examStatus: 'SCHEDULED',
    venueName: 'Main Hall',
    building: 'Science',
    capacity: 100,
    lecturers: [],
  );
  int starts = 0;
  @override
  Future<List<ExamAssignment>> fetchAssignments() async => [assignment];
  @override
  Future<String> startSession({
    required int examSessionId,
    required int venueId,
  }) async {
    expect(examSessionId, assignment.examSessionId);
    expect(venueId, assignment.venueId);
    starts++;
    assignment = assignment.copyWith(examStatus: 'IN_PROGRESS');
    return 'IN_PROGRESS';
  }
}

void main() {
  testWidgets('selecting an assigned exam opens verification', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    final repository = _ExamRepository();
    final container = ProviderContainer(
      overrides: [examRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container
        .read(currentUserProvider.notifier)
        .setUser(User(email: 'staff@example.com'));
    await container.read(examAssignmentsProvider.future);
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/verification',
          builder: (_, _) => const Scaffold(body: VerificationScreen()),
        ),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: DashboardScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('CSC101'));
    await tester.pumpAndSettle();

    expect(container.read(selectedExamProvider), repository.assignment);
    expect(find.text('Student verification'), findsOneWidget);
    expect(find.text(repository.assignment.shortLabel), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });

  testWidgets('session starts only after attendance confirmation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    FlutterSecureStorage.setMockInitialValues({});
    final repository = _ExamRepository();
    final container = ProviderContainer(
      overrides: [examRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);
    container
        .read(currentUserProvider.notifier)
        .setUser(User(email: 'staff@example.com'));
    final router = GoRouter(
      initialLocation: '/verification',
      routes: [
        GoRoute(
          path: '/verification',
          builder: (_, _) => const Scaffold(body: VerificationScreen()),
        ),
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(body: DashboardScreen()),
        ),
      ],
    );
    addTearDown(router.dispose);
    await container.read(examAssignmentsProvider.future);
    container.read(selectedExamProvider.notifier).select(repository.assignment);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(routerConfig: router),
      ),
    );
    await tester.pumpAndSettle();
    // Recording attendance remains available before the exam has started.
    final lookup = find.widgetWithText(ElevatedButton, 'Lookup student');
    expect(lookup, findsOneWidget);
    expect(tester.widget<ElevatedButton>(lookup).onPressed, isNotNull);
    await tester.tap(find.text('Start exam session'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Have you finished recording attendance'),
      findsOneWidget,
    );
    expect(repository.starts, 0);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(repository.starts, 0);
    expect(container.read(selectedExamProvider)!.isScheduled, isTrue);
    expect(
      find.text('Record all students before clicking Start exam session.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Start exam session'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Yes, start session'));
    await tester.pumpAndSettle();
    expect(repository.starts, 1);
    expect(container.read(selectedExamProvider)!.isInProgress, isTrue);
    expect(find.text('Start exam session'), findsNothing);
    expect(find.text('End session'), findsOneWidget);
    expect(find.text('Exam in progress'), findsOneWidget);
    expect(find.text('Assigned exams'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
