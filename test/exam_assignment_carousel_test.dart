import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/examinations/domain/exam_assignment.dart';
import 'package:invigilator_app/features/examinations/presentation/widgets/exam_assignment_carousel.dart';

ExamAssignment exam(int id) => ExamAssignment(
  examSessionId: id,
  venueId: id,
  courseCode: 'CSC $id',
  examDate: '2026-10-02',
  startTime: '09:00',
  endTime: '12:00',
  examStatus: 'SCHEDULED',
  venueName: 'Main examination hall with a long venue name $id',
  building: 'School of Natural Sciences building',
  capacity: 100,
  studentCount: id == 1 ? 0 : 64,
  lecturers: [],
);

void main() {
  testWidgets(
    'phone pages support swipe, pill indicators and explicit selection',
    (tester) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final exams = [exam(1), exam(2), exam(3)];
      ExamAssignment? selected;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ExamAssignmentCarousel(
                    assignments: exams,
                    selected: selected,
                    onSelect: (value) => setState(() => selected = value),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CSC 1').hitTestable(), findsOneWidget);
      expect(find.text('Expected attendance: 0').hitTestable(), findsOneWidget);
      expect(find.text('CSC 2').hitTestable(), findsNothing);
      expect(find.byTooltip('Next exam'), findsNothing);
      expect(find.text('Exam 1 of 3'), findsNothing);
      expect(find.bySemanticsLabel('Exam 1 of 3'), findsOneWidget);
      await tester.drag(find.text('CSC 1'), const Offset(-280, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Exam 2 of 3'), findsOneWidget);
      expect(find.text('CSC 2').hitTestable(), findsOneWidget);
      expect(find.text('Expected attendance: 64').hitTestable(), findsOneWidget);
      expect(selected, isNull);
      await tester.tap(find.text('CSC 2'));
      await tester.pumpAndSettle();
      expect(selected, exams[1]);
      expect(find.text('Tap to select').hitTestable(), findsOneWidget);
      expect(find.byIcon(Icons.check_circle), findsOneWidget);
      await tester.drag(find.text('CSC 2'), const Offset(-280, 0));
      await tester.pumpAndSettle();
      expect(find.bySemanticsLabel('Exam 3 of 3'), findsOneWidget);
      expect(selected, exams[1]);
      await tester.drag(find.text('CSC 3'), const Offset(280, 0));
      await tester.pumpAndSettle();
      await tester.drag(find.text('CSC 2'), const Offset(280, 0));
      await tester.pumpAndSettle();
      expect(find.text('CSC 1').hitTestable(), findsOneWidget);
      expect(find.text('Expected attendance: 0').hitTestable(), findsOneWidget);
      semantics.dispose();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'long details fit with large text and selected page opens first',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final exams = [exam(1), exam(2)];
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 1200),
              textScaler: TextScaler.linear(2),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: ExamAssignmentCarousel(
                    assignments: exams,
                    selected: exams[1],
                    onSelect: (_) {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('CSC 2').hitTestable(), findsOneWidget);
      expect(find.text('Expected attendance: 64').hitTestable(), findsOneWidget);
      final venue = tester.widget<Text>(find.text(exams[1].venueName));
      expect(venue.maxLines, isNull);
      expect(venue.overflow, isNull);
      expect(find.text(exams[1].timeRangeLabel).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
