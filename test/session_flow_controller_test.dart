import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/examinations/application/session_flow_controller.dart';
import 'helpers/session_flow_fakes.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late List<String> calls;
  late FlowExamRepository exams;
  late FlowAttendanceRepository attendance;
  SessionFlowController controller([String owner = 'staff-a']) =>
      SessionFlowController(
        owner: owner,
        store: const SessionFlowStore(),
        exams: exams,
        attendance: attendance,
      );
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
    calls = [];
    exams = FlowExamRepository(calls);
    attendance = FlowAttendanceRepository(calls);
  });

  test(
    'End only opens scripts; valid saved count is required before ending',
    () async {
      final flow = controller();
      addTearDown(flow.dispose);
      await flow.start(exams.assignment);
      await flow.requestScripts();
      expect(calls, ['start']);
      for (final invalid in ['', '-1', 'abc', '1.5']) {
        await flow.finish(invalid);
        expect(calls, ['start']);
        expect(flow.flow!.step, SessionStep.scripts);
      }
      await flow.finish('0');
      expect(calls, ['start', 'scripts:0', 'end']);
      expect(flow.flow!.step, SessionStep.thanks);
      await flow.dismissThanks();
      expect(flow.flow, isNull);
      final restored = controller();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.flow, isNull);
    },
  );

  test(
    'restart restores the original timestamp and unfinished scripts draft',
    () async {
      final first = controller();
      await first.start(exams.assignment);
      final timestamp = first.flow!.startedAt;
      first.dispose();
      final running = controller();
      await running.ready;
      expect(running.flow!.startedAt, timestamp);
      expect(running.flow!.step, SessionStep.running);
      await running.requestScripts();
      await running.saveDraft('42');
      running.dispose();
      final restored = controller();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.flow!.step, SessionStep.scripts);
      expect(restored.flow!.draft, '42');
      expect(restored.flow!.startedAt, timestamp);
      expect(calls, ['start']);
      final other = controller('staff-b');
      addTearDown(other.dispose);
      await other.ready;
      expect(other.flow, isNull);
    },
  );

  test(
    'failed scripts save preserves the count and never ends the exam',
    () async {
      final first = controller();
      await first.start(exams.assignment);
      await first.requestScripts();
      attendance.failSave = true;
      await first.finish('42');
      expect(calls, ['start', 'scripts:42']);
      expect(first.error, isNotNull);
      first.dispose();
      final restored = controller();
      addTearDown(restored.dispose);
      await restored.ready;
      expect(restored.flow!.draft, '42');
      attendance.failSave = false;
      await restored.finish('42');
      expect(calls, ['start', 'scripts:42', 'scripts:42', 'end']);
      expect(restored.flow!.step, SessionStep.thanks);
    },
  );

  test(
    'failed end restores checkpoint and retries without saving scripts again',
    () async {
      final first = controller();
      await first.start(exams.assignment);
      await first.requestScripts();
      exams.failEnd = true;
      await first.finish('42');
      expect(first.flow!.step, SessionStep.ending);
      first.dispose();
      final restored = controller();
      addTearDown(restored.dispose);
      await restored.ready;
      exams.failEnd = false;
      await restored.retryEnd();
      expect(calls, ['start', 'scripts:42', 'end', 'end']);
      expect(restored.flow!.step, SessionStep.thanks);
    },
  );

  test(
    'lost end response is reconciled without a duplicate end request',
    () async {
      final flow = controller();
      addTearDown(flow.dispose);
      await flow.start(exams.assignment);
      await flow.requestScripts();
      exams.loseEndResponse = true;
      await flow.finish('10');
      expect(flow.flow!.step, SessionStep.ending);
      await flow.retryEnd();
      expect(calls, ['start', 'scripts:10', 'end']);
      expect(flow.flow!.step, SessionStep.thanks);
    },
  );

  test(
    'lost start response resumes persisted timer without starting twice',
    () async {
      final first = controller();
      exams.loseStartResponse = true;
      await first.start(exams.assignment);
      expect(first.flow!.step, SessionStep.starting);
      final timestamp = first.flow!.startedAt;
      first.dispose();
      final restored = controller();
      addTearDown(restored.dispose);
      await restored.ready;
      await restored.retryStart();
      expect(calls, ['start']);
      expect(restored.flow!.step, SessionStep.running);
      expect(restored.flow!.startedAt, timestamp);
    },
  );
}
