import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:invigilator_app/features/offline/presentation/offline_download_popup.dart';

void main() {
  testWidgets('compact popup blocks dismissal and reflects real progress', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: OfflineDownloadPopup(progress: 0.45)),
      ),
    );
    expect(find.text('Downloading offline data'), findsOneWidget);
    expect(
      tester
          .widget<ModalBarrier>(
            find.descendant(
              of: find.byType(OfflineDownloadPopup),
              matching: find.byType(ModalBarrier),
            ),
          )
          .dismissible,
      isFalse,
    );
    expect(tester.widget<PopScope>(find.byType(PopScope)).canPop, isFalse);
    expect(find.text('45%'), findsNothing);
    expect(
      tester.getSize(find.byType(OfflineDownloadPopup)).width,
      greaterThan(300),
    );
    final panel = find
        .ancestor(
          of: find.text('Downloading offline data'),
          matching: find.byType(Container),
        )
        .first;
    expect(tester.getSize(panel).height, lessThan(200));
    await tester.pump(const Duration(milliseconds: 500));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    expect(tester.takeException(), isNull);
  });
  testWidgets('failure stops progress and exposes Retry and Close', (
    tester,
  ) async {
    var retried = false;
    var closed = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: OfflineDownloadPopup(
            progress: 0.45,
            failed: true,
            onRetry: () => retried = true,
            onClose: () => closed = true,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Download failed'), findsOneWidget);
    expect(
      find
          .byType(CustomPaint)
          .evaluate()
          .where(
            (element) =>
                (element.widget as CustomPaint).painter.runtimeType
                    .toString() ==
                '_MovingBarsPainter',
          ),
      isEmpty,
    );
    await tester.tap(find.text('Retry'));
    expect(retried, isTrue);
    await tester.tap(find.text('Close'));
    expect(closed, isTrue);
    expect(tester.takeException(), isNull);
  });
}
