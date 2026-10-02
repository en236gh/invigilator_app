import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:invigilator_app/core/layout/app_sidebar.dart';

void main() {
  testWidgets('system back retraces sidebar navigation', (tester) async {
    final router = GoRouter(
      routes: [
        ShellRoute(
          builder: (context, state, child) => PopScope(
            canPop: false,
            child: Scaffold(
              body: Row(
                children: [
                  AppSidebar(currentPath: state.uri.path),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Text('Home screen'),
              routes: [
                GoRoute(
                  path: 'attendance',
                  builder: (_, _) => const Text('Attendance screen'),
                ),
                GoRoute(
                  path: 'incidents',
                  builder: (_, _) => const Text('Incidents screen'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(child: MaterialApp.router(routerConfig: router)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('attendance'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('incidents'));
    await tester.pumpAndSettle();
    expect(find.text('Incidents screen'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Attendance screen'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home screen'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.text('Home screen'), findsOneWidget);
  });
}
