import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/examinations/application/session_flow_controller.dart';
import 'package:invigilator_app/features/examinations/application/exam_providers.dart';
import 'package:invigilator_app/features/examinations/presentation/dashboard_screen.dart';
import 'helpers/session_flow_fakes.dart';

void main() {
  setUp(() => FlutterSecureStorage.setMockInitialValues({}));
  testWidgets(
    'focused timer then scripts then thanks returns to normal dashboard',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final calls = <String>[];
      final exams = FlowExamRepository(calls);
      final flow = SessionFlowController(
        owner: 'staff-a',
        store: const SessionFlowStore(),
        exams: exams,
        attendance: FlowAttendanceRepository(calls),
      );
      await flow.start(exams.assignment);
      final container = ProviderContainer(
        overrides: [
          sessionFlowProvider.overrideWith((_) => flow),
          examRepositoryProvider.overrideWithValue(exams),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Exam in progress'), findsOneWidget);
      expect(find.text('Assigned exams'), findsNothing);
      expect(find.text('Scripts collected'), findsNothing);
      expect(
        find.textContaining(RegExp(r'^\d{2}:\d{2}:\d{2}$')),
        findsOneWidget,
      );
      await tester.tap(find.text('End session'));
      await tester.pumpAndSettle();
      expect(calls, ['start']);
      expect(find.text('Scripts collected'), findsOneWidget);
      expect(find.text('Exam in progress'), findsNothing);
      await tester.tap(find.text('Save scripts and end session'));
      await tester.pumpAndSettle();
      expect(calls, ['start']);
      expect(
        find.text('Enter a whole number of scripts, zero or more.'),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextField), '42');
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save scripts and end session'));
      await tester.pumpAndSettle();
      expect(calls, ['start', 'scripts:42', 'end']);
      expect(find.text('Thank you!'), findsOneWidget);
      expect(find.text('Assigned exams'), findsNothing);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(
        find.text("Here's your examination schedule for today."),
        findsOneWidget,
      );
      expect(find.text("Today's Exams"), findsOneWidget);
      expect(find.text('Thank you!'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'restored timer includes elapsed hours and restored form keeps draft',
    (tester) async {
      final calls = <String>[];
      final exams = FlowExamRepository(calls);
      const store = SessionFlowStore();
      await store.write(
        'staff-a',
        SessionFlow(
          assignment: exams.assignment,
          startedAt: DateTime.now().toUtc().subtract(
            const Duration(hours: 1, minutes: 2, seconds: 3),
          ),
          step: SessionStep.running,
        ),
      );
      final flow = SessionFlowController(
        owner: 'staff-a',
        store: store,
        exams: exams,
        attendance: FlowAttendanceRepository(calls),
      );
      await flow.ready;
      final container = ProviderContainer(
        overrides: [sessionFlowProvider.overrideWith((_) => flow)],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining(RegExp(r'^01:02:0[3-9]$')), findsOneWidget);
      expect(calls, isEmpty);
      await flow.requestScripts();
      await flow.saveDraft('37');
      await tester.pumpWidget(const SizedBox());
      final restored = SessionFlowController(
        owner: 'staff-a',
        store: store,
        exams: exams,
        attendance: FlowAttendanceRepository(calls),
      );
      await restored.ready;
      final restoredContainer = ProviderContainer(
        overrides: [sessionFlowProvider.overrideWith((_) => restored)],
      );
      addTearDown(restoredContainer.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: restoredContainer,
          child: const MaterialApp(home: Scaffold(body: DashboardScreen())),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '37',
      );
      expect(calls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
