import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:synchronized/synchronized.dart';
import '../../auth/application/auth_providers.dart';
import '../../attendance/data/attendance_repository.dart';
import '../data/exam_repository.dart';
import '../domain/exam_assignment.dart';
import 'exam_providers.dart';

enum SessionStep { starting, running, scripts, ending, thanks }

class SessionFlow {
  const SessionFlow({
    required this.assignment,
    required this.startedAt,
    required this.step,
    this.draft = '',
  });
  final ExamAssignment assignment;
  final DateTime startedAt;
  final SessionStep step;
  final String draft;

  SessionFlow copyWith({SessionStep? step, String? draft}) => SessionFlow(
    assignment: assignment,
    startedAt: startedAt,
    step: step ?? this.step,
    draft: draft ?? this.draft,
  );

  Map<String, dynamic> toJson() => {
    'assignment': {
      'examSessionId': assignment.examSessionId,
      'venueId': assignment.venueId,
      'courseCode': assignment.courseCode,
      'examDate': assignment.examDate,
      'startTime': assignment.startTime,
      'endTime': assignment.endTime,
      'examStatus': assignment.examStatus,
      'venueName': assignment.venueName,
      'building': assignment.building,
      'capacity': assignment.capacity,
      'studentCount': assignment.studentCount,
      'campus': assignment.campus,
      'lecturers': assignment.lecturers,
    },
    'startedAt': startedAt.toUtc().toIso8601String(),
    'step': step.name,
    'draft': draft,
  };

  factory SessionFlow.fromJson(Map<String, dynamic> json) => SessionFlow(
    assignment: ExamAssignment.fromMap(
      Map<String, dynamic>.from(json['assignment'] as Map),
    ),
    startedAt: DateTime.parse(json['startedAt'] as String),
    step: SessionStep.values.byName(json['step'] as String),
    draft: json['draft'] as String,
  );
}

class SessionFlowStore {
  const SessionFlowStore();
  static const _storage = FlutterSecureStorage();
  String _key(String owner) => 'exam_flow_v1_${Uri.encodeComponent(owner)}';
  Future<SessionFlow?> read(String owner) async {
    final value = await _storage.read(key: _key(owner));
    return value == null
        ? null
        : SessionFlow.fromJson(jsonDecode(value) as Map<String, dynamic>);
  }

  Future<void> write(String owner, SessionFlow? flow) => flow == null
      ? _storage.delete(key: _key(owner))
      : _storage.write(key: _key(owner), value: jsonEncode(flow.toJson()));
}

final sessionFlowProvider = ChangeNotifierProvider<SessionFlowController>((
  ref,
) {
  final user = ref.watch(currentUserProvider);
  final owner = user?.email?.toLowerCase() ?? user?.id ?? user?.offlineStaffId;
  return SessionFlowController(
    owner: owner,
    store: const SessionFlowStore(),
    exams: ref.read(examRepositoryProvider),
    attendance: AttendanceRepository(),
  );
});

/// Durable steps keep API mutations ordered and isolate the flow per account.
class SessionFlowController extends ChangeNotifier {
  SessionFlowController({
    required this.owner,
    required this.store,
    required this.exams,
    required this.attendance,
  }) {
    ready = _restore();
  }
  final String? owner;
  final SessionFlowStore store;
  final ExamRepository exams;
  final AttendanceRepository attendance;
  final Lock _writes = Lock();
  late final Future<void> ready;
  SessionFlow? flow;
  bool loading = true, busy = false, _disposed = false;
  bool _restoreFailed = false;
  String? error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> _restore() async {
    try {
      if (owner != null) flow = await store.read(owner!);
    } catch (_) {
      _restoreFailed = true;
      error = 'Could not restore your exam session. Tap Retry.';
    }
    loading = false;
    _notify();
  }

  Future<void> restore() async {
    loading = true;
    _restoreFailed = false;
    error = null;
    _notify();
    await _restore();
  }

  Future<void> _commit(SessionFlow? next) => _writes.synchronized(() async {
    if (_disposed) throw StateError('Account changed');
    if (owner == null) {
      throw StateError('Sign in again to save your exam session.');
    }
    await store.write(owner!, next);
    if (_disposed) throw StateError('Account changed');
    flow = next;
    _notify();
  });

  Future<void> _run(Future<void> Function() action) async {
    await ready;
    if (busy || _disposed || _restoreFailed) return;
    if (loading) return;
    busy = true;
    error = null;
    _notify();
    try {
      await action();
    } catch (_) {
      error =
          'Could not save or update the session. Your progress is kept. Check your connection and retry.';
    } finally {
      busy = false;
      _notify();
    }
  }

  Future<void> start(ExamAssignment assignment) => _run(() async {
    if (flow != null) throw StateError('Finish your current session first');
    await _commit(
      SessionFlow(
        assignment: assignment,
        startedAt: DateTime.now().toUtc(),
        step: SessionStep.starting,
      ),
    );
    await _startRequest();
  });

  Future<void> _startRequest() async {
    final current = flow!;
    if (_disposed) return;
    final status = await exams.startSession(
      examSessionId: current.assignment.examSessionId,
      venueId: current.assignment.venueId,
    );
    if (status != 'IN_PROGRESS') throw StateError('Session did not start');
    await _commit(current.copyWith(step: SessionStep.running));
  }

  Future<void> retryStart() => _run(() async {
    if (flow?.step != SessionStep.starting) return;
    final current = flow!;
    final assignments = await exams.fetchAssignments();
    final matching = assignments.where(
      (exam) => exam.sameAs(current.assignment),
    );
    if (matching.isEmpty) throw StateError('Exam is no longer assigned');
    if (matching.first.isInProgress) {
      await _commit(current.copyWith(step: SessionStep.running));
    } else if (matching.first.isScheduled) {
      await _startRequest();
    } else {
      throw StateError('Exam is already completed');
    }
  });

  Future<void> requestScripts() => _run(() async {
    if (flow?.step == SessionStep.running) {
      await _commit(flow!.copyWith(step: SessionStep.scripts));
    }
  });

  Future<void> returnToRunning() => _run(() async {
    if (flow?.step == SessionStep.scripts) {
      await _commit(flow!.copyWith(step: SessionStep.running));
    }
  });

  Future<void> saveDraft(String draft) async {
    if (busy || flow?.step != SessionStep.scripts) return;
    // Update immediately; serialize writes so rapid typing never restores an older value.
    final next = flow!.copyWith(draft: draft);
    flow = next;
    try {
      await _writes.synchronized(() async {
        if (!_disposed && owner != null) await store.write(owner!, next);
      });
    } catch (_) {
      error = 'Could not save your scripts count on this device. Please retry.';
      _notify();
    }
  }

  Future<void> finish(String draft) => _run(() async {
    final current = flow;
    if (current == null) return;
    if (current.step == SessionStep.scripts) {
      final count = int.tryParse(draft.trim());
      if (count == null ||
          count < 0 ||
          !RegExp(r'^\d+$').hasMatch(draft.trim())) {
        error = 'Enter a whole number of scripts, zero or more.';
        return;
      }
      await _commit(current.copyWith(draft: draft.trim()));
      await attendance.markScriptsCollected(
        examSessionId: current.assignment.examSessionId,
        count: count,
      );
      // This durable checkpoint means retries do not resubmit a saved count.
      await _commit(flow!.copyWith(step: SessionStep.ending));
    } else if (current.step != SessionStep.ending) {
      return;
    }
    await _endRequest();
  });

  Future<void> _endRequest() async {
    final current = flow!;
    if (_disposed) return;
    final status = await exams.endSession(
      examSessionId: current.assignment.examSessionId,
      venueId: current.assignment.venueId,
    );
    if (status != 'COMPLETED') throw StateError('Session did not end');
    await _commit(current.copyWith(step: SessionStep.thanks));
  }

  Future<void> retryEnd() => _run(() async {
    if (flow?.step != SessionStep.ending) return;
    final current = flow!;
    // Reconcile an interrupted response before submitting another end request.
    final assignments = await exams.fetchAssignments();
    final matching = assignments.where(
      (exam) => exam.sameAs(current.assignment),
    );
    if (matching.isNotEmpty && matching.first.isCompleted) {
      await _commit(current.copyWith(step: SessionStep.thanks));
    } else if (matching.isNotEmpty && matching.first.isInProgress) {
      await _endRequest();
    } else {
      throw StateError('Could not confirm the exam status');
    }
  });

  Future<void> dismissThanks() => _run(() async {
    if (flow?.step == SessionStep.thanks) await _commit(null);
  });

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
