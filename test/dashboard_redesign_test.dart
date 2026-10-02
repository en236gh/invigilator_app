import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:invigilator_app/features/examinations/application/exam_providers.dart';
import 'package:invigilator_app/features/examinations/data/exam_repository.dart';
import 'package:invigilator_app/features/examinations/domain/exam_assignment.dart';
import 'package:invigilator_app/features/examinations/presentation/dashboard_screen.dart';
import 'package:invigilator_app/features/examinations/presentation/widgets/dashboard_exam_card.dart';

class _Repository extends ExamRepository {
  _Repository(this.exams);
  final List<ExamAssignment> exams;
  @override
  Future<List<ExamAssignment>> fetchAssignments() async => exams;
}

ExamAssignment _exam(int id, {String status = 'SCHEDULED', int days = 0}) =>
    ExamAssignment(
      examSessionId: id,
      venueId: id,
      courseCode: 'CEE210$id',
      examDate: DateTime.now()
          .add(Duration(days: days))
          .toIso8601String()
          .split('T')
          .first,
      startTime: '09:00',
      endTime: '23:59:59',
      examStatus: status,
      venueName: 'UNZA Main Library Auditorium',
      building: 'Main Library',
      campus: 'Great East Road Campus',
      capacity: 100,
      studentCount: 64,
      lecturers: [],
    );

Future<ProviderContainer> _pump(
  WidgetTester tester,
  List<ExamAssignment> exams, {
  double scale = 1,
}) async {
  FlutterSecureStorage.setMockInitialValues({});
  tester.view.physicalSize = const Size(320, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final container = ProviderContainer(
    overrides: [examRepositoryProvider.overrideWithValue(_Repository(exams))],
  );
  addTearDown(container.dispose);
  await container.read(examAssignmentsProvider.future);
  final router = GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: DashboardScreen()),
      ),
      GoRoute(
        path: '/verification',
        builder: (_, _) => const Scaffold(body: Text('Verification opened')),
      ),
      GoRoute(
        path: '/incidents',
        builder: (_, _) => const Scaffold(body: Text('Incidents opened')),
      ),
      GoRoute(
        path: '/attendance',
        builder: (_, _) => const Scaffold(body: Text('Attendance opened')),
      ),
    ],
  );
  addTearDown(router.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('active exam is first and Continue Exam opens its verification', (
    tester,
  ) async {
    final active = _exam(2, status: 'IN_PROGRESS');
    final container = await _pump(tester, [
      _exam(1, days: 1),
      active,
      _exam(3, status: 'COMPLETED'),
    ]);
    final cards = tester
        .widgetList<DashboardExamCard>(find.byType(DashboardExamCard))
        .toList();
    expect(cards.first.exam, active);
    expect(find.text('CURRENT EXAM'), findsOneWidget);
    expect(find.text('Students expected to attend: 64'), findsNWidgets(3));
    expect(find.text('Tap to select'), findsNothing);
    await tester.ensureVisible(find.text('Continue Exam'));
    await tester.tap(find.text('Continue Exam'));
    await tester.pumpAndSettle();
    expect(container.read(selectedExamProvider), active);
    expect(find.text('Verification opened'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'future exam cannot start and Incidents scopes to the next exam',
    (tester) async {
      final upcoming = _exam(1, days: 1);
      final container = await _pump(tester, [upcoming]);
      expect(find.text('No exams scheduled for today.'), findsOneWidget);
      await tester.ensureVisible(find.text('Start Exam Session'));
      await tester.tap(find.text('Start Exam Session'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsNothing);
      await tester.ensureVisible(find.text('Incidents'));
      await tester.tap(find.text('Incidents'));
      await tester.pumpAndSettle();
      expect(container.read(selectedExamProvider), upcoming);
      expect(find.text('Incidents opened'), findsOneWidget);
    },
  );

  testWidgets('today start confirms attendance and No opens verification', (
    tester,
  ) async {
    final today = _exam(1);
    final container = await _pump(tester, [today]);
    await tester.ensureVisible(find.text('Start Exam Session'));
    await tester.tap(find.text('Start Exam Session'));
    await tester.pumpAndSettle();
    expect(find.text('Start exam session?'), findsOneWidget);
    await tester.tap(find.text('No'));
    await tester.pumpAndSettle();
    expect(container.read(selectedExamProvider), today);
    expect(find.text('Verification opened'), findsOneWidget);
  });

  testWidgets('empty schedule and large text remain usable on narrow phones', (
    tester,
  ) async {
    await _pump(tester, [], scale: 2);
    expect(find.text('No exams assigned'), findsOneWidget);
    await tester.ensureVisible(find.text('Start Exam Session'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('long exam details wrap with large text', (tester) async {
    await _pump(tester, [_exam(1)], scale: 2);
    await tester.ensureVisible(find.text('Open Exam'));
    expect(tester.takeException(), isNull);
    expect(find.text('Great East Road Campus'), findsOneWidget);
  });

  testWidgets(
    'upcoming exam precedes overdue assignments requiring attention',
    (tester) async {
      final overdue = _exam(1, days: -1);
      final upcoming = _exam(2, days: 1);
      await _pump(tester, [overdue, upcoming]);
      final cards = tester
          .widgetList<DashboardExamCard>(find.byType(DashboardExamCard))
          .toList();
      expect(cards.first.exam, upcoming);
      expect(find.text('REQUIRES ATTENTION'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('schedule uses readable date and time', () {
    expect(
      examScheduleLabel(
        _exam(1).copyWith(examDate: '2026-10-05', endTime: '11:00'),
      ),
      'Monday, 5 October • 09:00–11:00',
    );
  });
}
