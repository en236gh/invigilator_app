import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/exam_repository.dart';
import '../domain/exam_assignment.dart';

final examRepositoryProvider = Provider<ExamRepository>((ref) {
  return ExamRepository();
});

final examAssignmentsProvider =
    AsyncNotifierProvider<ExamAssignmentsNotifier, List<ExamAssignment>>(
  ExamAssignmentsNotifier.new,
);

class ExamAssignmentsNotifier extends AsyncNotifier<List<ExamAssignment>> {
  @override
  Future<List<ExamAssignment>> build() {
    return ref.read(examRepositoryProvider).fetchAssignments();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(examRepositoryProvider).fetchAssignments(),
    );
  }
}

/// Global selected exam for the invigilator session.
///
/// Dashboard selects it; Verification, Attendance, and Incidents consume it.
final selectedExamProvider =
    NotifierProvider<SelectedExamNotifier, ExamAssignment?>(
  SelectedExamNotifier.new,
);

class SelectedExamNotifier extends Notifier<ExamAssignment?> {
  @override
  ExamAssignment? build() {
    ref.listen<AsyncValue<List<ExamAssignment>>>(
      examAssignmentsProvider,
      (previous, next) {
        next.whenData(_syncWithAssignments);
      },
    );
    return null;
  }

  void select(ExamAssignment assignment) {
    state = assignment;
  }

  void clear() {
    state = null;
  }

  void _syncWithAssignments(List<ExamAssignment> assignments) {
    final current = state;
    if (current == null) return;

    for (final assignment in assignments) {
      if (!assignment.sameAs(current)) continue;
      final changed = assignment.examStatus != current.examStatus ||
          assignment.courseCode != current.courseCode ||
          assignment.venueName != current.venueName ||
          assignment.startTime != current.startTime ||
          assignment.endTime != current.endTime ||
          assignment.building != current.building;
      if (changed) {
        state = assignment;
      }
      return;
    }

    state = null;
  }
}
