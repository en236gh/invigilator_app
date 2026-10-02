import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/core/widgets/app_canvas.dart';

void main() {
  testWidgets('pull down refreshes a page with short content', (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: AppPageBody(
            onRefresh: () async => refreshes++,
            child: const Text('Short page'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.drag(find.byType(SingleChildScrollView), const Offset(0, 300));
    await tester.pumpAndSettle();
    expect(refreshes, 1);
  });
}
