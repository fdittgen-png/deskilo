// SPDX-License-Identifier: MIT
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/workspace/domain/closure_day.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

/// Seed the fake BEFORE pumping — the providers cache their first read.
Future<FakeWorkspaceRepository> pumpAvailability(
  WidgetTester tester, {
  FakeWorkspaceRepository? workspace,
}) async {
  workspace ??= FakeWorkspaceRepository.withWorkspace();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  final context = tester.element(find.byType(Scaffold).first);
  GoRouter.of(context).push('/availability');
  await tester.pumpAndSettle();
  return workspace;
}

void main() {
  testWidgets('renders seven weekday chips reflecting the open weekdays',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..openWeekdays['ws-1'] = [1, 2, 3];
    await pumpAvailability(tester, workspace: workspace);

    expect(find.byType(FilterChip), findsNWidgets(7));

    bool selectedOf(String label) => tester
        .widget<FilterChip>(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(FilterChip),
          ),
        )
        .selected;
    expect(selectedOf('Mon'), isTrue);
    expect(selectedOf('Tue'), isTrue);
    expect(selectedOf('Wed'), isTrue);
    expect(selectedOf('Thu'), isFalse);
    expect(selectedOf('Fri'), isFalse);
    expect(selectedOf('Sat'), isFalse);
    expect(selectedOf('Sun'), isFalse);
  });

  testWidgets('toggling a chip persists the new open-weekday set',
      (tester) async {
    final workspace = await pumpAvailability(tester);

    await tester.tap(find.text('Sat'));
    await tester.pumpAndSettle();
    expect(workspace.openWeekdays['ws-1'], [1, 2, 3, 4, 5, 6]);

    await tester.tap(find.text('Mon'));
    await tester.pumpAndSettle();
    expect(workspace.openWeekdays['ws-1'], [2, 3, 4, 5, 6]);
  });

  testWidgets('the last open weekday cannot be unchecked', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..openWeekdays['ws-1'] = [3];
    await pumpAvailability(tester, workspace: workspace);

    await tester.tap(find.text('Wed'));
    await tester.pump();

    expect(
      find.text('At least one weekday must stay open.'),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
    expect(workspace.openWeekdays['ws-1'], [3]);
  });

  testWidgets('closure days render with localized date and reason',
      (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..closureDays.addAll([
        ClosureDay(
          id: 'closure-a',
          workspaceId: 'ws-1',
          day: DateTime(2026, 12, 24),
          reason: 'Christmas Eve',
        ),
        ClosureDay(
          id: 'closure-b',
          workspaceId: 'ws-1',
          day: DateTime(2026, 8, 15),
          reason: '',
        ),
      ]);
    await pumpAvailability(tester, workspace: workspace);

    expect(find.text('December 24, 2026'), findsOneWidget);
    expect(find.text('Christmas Eve'), findsOneWidget);
    expect(find.text('August 15, 2026'), findsOneWidget);
    expect(find.text('No closure days.'), findsNothing);
  });

  testWidgets('deleting a closure day removes it', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..closureDays.add(
        ClosureDay(
          id: 'closure-a',
          workspaceId: 'ws-1',
          day: DateTime(2026, 12, 24),
          reason: 'Christmas Eve',
        ),
      );
    await pumpAvailability(tester, workspace: workspace);

    await tester.tap(find.byIcon(Icons.delete_outline));
    await tester.pumpAndSettle();

    expect(workspace.closureDays, isEmpty);
    expect(find.text('December 24, 2026'), findsNothing);
    expect(find.text('No closure days.'), findsOneWidget);
  });

  testWidgets('adding a closure day via picker and reason dialog persists it',
      (tester) async {
    final workspace = await pumpAvailability(tester);

    await tester.tap(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK')); // accept today in the date picker
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Deep clean');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    final today = DateTime.now();
    final created = workspace.closureDays.single;
    expect(created.workspaceId, 'ws-1');
    expect(created.day, DateTime(today.year, today.month, today.day));
    expect(created.reason, 'Deep clean');
    expect(find.text('Deep clean'), findsOneWidget);
  });
}
