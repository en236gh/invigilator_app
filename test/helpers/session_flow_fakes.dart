import 'package:invigilator_app/features/attendance/data/attendance_repository.dart';
import 'package:invigilator_app/features/examinations/data/exam_repository.dart';
import 'package:invigilator_app/features/examinations/domain/exam_assignment.dart';

class FlowExamRepository extends ExamRepository {
  FlowExamRepository(this.calls);
  final List<String> calls;
  bool failEnd = false, loseEndResponse = false, loseStartResponse = false;
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
  @override
  Future<List<ExamAssignment>> fetchAssignments() async => [assignment];
  @override
  Future<String> startSession({
    required int examSessionId,
    required int venueId,
  }) async {
    calls.add('start');
    assignment = assignment.copyWith(examStatus: 'IN_PROGRESS');
    if (loseStartResponse) throw StateError('Response lost');
    return 'IN_PROGRESS';
  }

  @override
  Future<String> endSession({
    required int examSessionId,
    required int venueId,
  }) async {
    calls.add('end');
    if (failEnd) throw StateError('Offline');
    assignment = assignment.copyWith(examStatus: 'COMPLETED');
    if (loseEndResponse) throw StateError('Response lost');
    return 'COMPLETED';
  }
}

class FlowAttendanceRepository extends AttendanceRepository {
  FlowAttendanceRepository(this.calls);
  final List<String> calls;
  bool failSave = false;
  @override
  Future<void> markScriptsCollected({
    required int examSessionId,
    required int count,
  }) async {
    calls.add('scripts:$count');
    if (failSave) throw StateError('Offline');
  }
}
