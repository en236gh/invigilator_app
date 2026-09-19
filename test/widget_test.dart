// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:invigilator_app/app/app.dart';
import 'package:invigilator_app/core/widgets/app_badge.dart';
import 'package:invigilator_app/core/widgets/app_page_header.dart';
import 'package:invigilator_app/features/auth/data/auth_repository.dart';
import 'package:invigilator_app/features/examinations/application/exam_providers.dart';
import 'package:invigilator_app/features/examinations/data/exam_repository.dart';
import 'package:invigilator_app/features/examinations/domain/exam_assignment.dart';

class _FakeExamRepository extends ExamRepository {
  _FakeExamRepository(this.assignments);

  List<ExamAssignment> assignments;

  @override
  Future<List<ExamAssignment>> fetchAssignments() async => assignments;
}

void main() {
  testWidgets('app boots with the login route', (WidgetTester tester) async {
    await tester.pumpWidget(const InvigilatorApp());

    expect(find.text('Sign in'), findsOneWidget);
  });

  testWidgets('dashboard typography uses a stronger enterprise hierarchy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppPageHeader(
            title: 'Dashboard',
            subtitle: 'Select your assigned exam.',
          ),
        ),
      ),
    );

    final title = tester.widget<Text>(find.text('Dashboard'));
    expect(title.style!.fontSize, 36);
    expect(title.style!.fontWeight, FontWeight.w700);

    expect(find.text('Select your assigned exam.'), findsOneWidget);
  });

  testWidgets('status badges use a lighter supporting treatment', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: AppBadge(label: 'COMPLETED')),
      ),
    );

    final badgeText = tester.widget<Text>(find.text('COMPLETED'));
    expect(badgeText.style!.fontSize, 10);
    expect(badgeText.style!.fontWeight, FontWeight.w500);
  });

  test(
    'auth payload parser accepts both direct and nested refresh responses',
    () {
      const direct = {'accessToken': 'a', 'refreshToken': 'r'};
      final nested = {
        'success': true,
        'data': {'accessToken': 'a', 'refreshToken': 'r'},
      };

      expect(AuthRepository.extractAuthPayload(direct), direct);
      expect(AuthRepository.extractAuthPayload(nested), {
        'accessToken': 'a',
        'refreshToken': 'r',
      });
    },
  );

  test('clears a selected assignment when it is no longer assigned', () async {
    final oldAssignment = ExamAssignment(
      examSessionId: 1,
      venueId: 1,
      courseCode: 'OLD101',
      examDate: '2026-09-19',
      startTime: '09:00',
      endTime: '11:00',
      examStatus: 'SCHEDULED',
      venueName: 'Old Venue',
      building: 'Old Building',
      capacity: 50,
      lecturers: const [],
    );
    final newAssignment = oldAssignment.copyWith(
      examSessionId: 2,
      venueId: 2,
      courseCode: 'NEW202',
      venueName: 'New Venue',
    );
    final repository = _FakeExamRepository([oldAssignment]);
    final container = ProviderContainer(
      overrides: [examRepositoryProvider.overrideWithValue(repository)],
    );
    addTearDown(container.dispose);

    await container.read(examAssignmentsProvider.future);
    container.read(selectedExamProvider.notifier).select(oldAssignment);
    expect(container.read(selectedExamProvider), same(oldAssignment));

    repository.assignments = [newAssignment];
    await container.read(examAssignmentsProvider.notifier).refresh();

    expect(container.read(selectedExamProvider), isNull);
  });
}
