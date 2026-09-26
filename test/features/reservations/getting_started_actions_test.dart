// SPDX-License-Identifier: AGPL-3.0-or-later
// #1654: real hub actions navigate without booking; dismissal can be reopened.
import 'package:deskilo/core/help/help_hint_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'reserve_hub_test.dart' show pumpHub;

void main() {
  testWidgets('guidance opens the existing date picker without a write', (tester) async {
    final repo = await pumpHub(tester);
    final action = find.byKey(const ValueKey('getting-started-primary'));
    await tester.ensureVisible(action);
    await tester.tap(action);
    await tester.pumpAndSettle();
    expect(find.byType(DatePickerDialog), findsOneWidget);
    expect(repo.createCalls, 0);
  });
  testWidgets('Not now persists only this scope and View reopens it', (tester) async {
    final repo = await pumpHub(tester);
    final dismiss = find.byKey(const ValueKey('getting-started-dismiss'));
    final container = ProviderScope.containerOf(tester.element(dismiss));
    await tester.ensureVisible(dismiss);
    await tester.tap(dismiss);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('getting-started-card')), findsNothing);
    final keys = await container.read(dismissedHelpHintsProvider.future);
    expect(keys.where((key) => key.startsWith('getting-started:')), hasLength(1));
    await tester.tap(find.byKey(const ValueKey('reserve-view-switch')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('reserve-view-get-started')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('getting-started-card')), findsOneWidget);
    expect(repo.createCalls, 0);
  });
}
