import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/sync/presentation/attendance_status_summary.dart';

void main() {
  testWidgets(
    'counts explain actions and shortcuts invoke the correct callbacks on mobile',
    (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final actions = <String>[];
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: AttendanceStatusSummary(
                connection: 'Online',
                pending: 2,
                completed: 1,
                review: 1,
                onPending: () => actions.add('pending'),
                onCompleted: () => actions.add('completed'),
                onReview: () => actions.add('review'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Connection: Online'), findsOneWidget);
      expect(find.text('1 Needs review'), findsOneWidget);
      expect(find.text('2 Pending'), findsOneWidget);
      expect(find.text('1 Completed'), findsOneWidget);
      expect(find.text('Rejected scans need your attention.'), findsOneWidget);
      for (final label in [
        'Review rejected scans',
        'View pending scans',
        'View completed scans',
      ]) {
        await tester.ensureVisible(find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
      }
      expect(actions, ['review', 'pending', 'completed']);
      expect(tester.takeException(), isNull);
    },
  );
}
