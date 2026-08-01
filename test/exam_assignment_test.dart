import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/examinations/domain/exam_assignment.dart';

void main() {
  group('ExamAssignment attendance eligibility', () {
    test('scheduled sessions remain open for check-in until completed', () {
      final assignment = ExamAssignment(
        examSessionId: 1,
        venueId: 2,
        courseCode: 'CS101',
        examDate: '2026-08-01',
        startTime: '',
        endTime: '',
        examStatus: 'SCHEDULED',
        venueName: 'Main Hall',
        building: 'Science',
        capacity: 120,
        lecturers: ['Dr. Smith'],
      );

      expect(assignment.canCheckIn, isTrue);
    });

    test('completed sessions block check-in', () {
      final assignment = ExamAssignment(
        examSessionId: 1,
        venueId: 2,
        courseCode: 'CS101',
        examDate: '2026-08-01',
        startTime: '',
        endTime: '',
        examStatus: 'COMPLETED',
        venueName: 'Main Hall',
        building: 'Science',
        capacity: 120,
        lecturers: ['Dr. Smith'],
      );

      expect(assignment.canCheckIn, isFalse);
    });
  });
}
