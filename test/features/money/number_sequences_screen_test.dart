// SPDX-License-Identifier: 0BSD
//
// #925 — the one screen for every number series: reached from Settings
// by the owner, live preview while typing, save through the repository.
import 'package:deskilo/app/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Future<FakeMoneyRepository> pumpSettings(
  WidgetTester tester, {
  Map<String, dynamic> featureFlags = const {},
}) async {
  final money = FakeMoneyRepository();
  final workspace = FakeWorkspaceRepository.withWorkspace(
    featureFlags: featureFlags,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money, workspace: workspace),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
  return money;
}

const _on = {'invoicing': true, 'numberSequences': true};
final _tile = find.byKey(const ValueKey('settings-number-sequences'));

void main() {
  testWidgets('the tile is absent while the feature is off', (tester) async {
    await pumpSettings(tester, featureFlags: {'invoicing': true});
    expect(_tile, findsNothing);
  });

  testWidgets('every series on one screen, previewed on the workspace clock',
      (tester) async {
    await pumpSettings(tester, featureFlags: _on);
    await tester.scrollUntilVisible(
      _tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_tile);
    await tester.pumpAndSettle();

    // The fake's invoice series is untouched: INV-, year, 4 digits, next 1.
    expect(find.byKey(const ValueKey('number-sequence-invoice')), findsOneWidget);
    expect(find.textContaining('INV-2026-0001'), findsOneWidget);

    // The credit-note series exists beside it even though nothing has
    // ever configured it — that is the point of ONE screen.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('number-sequence-credit_note')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('2026-0001'), findsNWidgets(2));
  });

  testWidgets('typing reformats the preview live; save goes through the '
      'repository and never takes a number', (tester) async {
    final money = await pumpSettings(tester, featureFlags: _on);
    await tester.scrollUntilVisible(
      _tile,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(_tile);
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('number-sequence-prefix-invoice')),
      'F-',
    );
    await tester.pump();
    expect(find.textContaining('F-2026-0001'), findsOneWidget);
    expect(find.textContaining('INV-2026-0001'), findsNothing);

    final save = find.byKey(const ValueKey('number-sequence-save-invoice'));
    await tester.ensureVisible(save);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(money.lastNumberSequence?.journal, 'invoice');
    expect(money.lastNumberSequence?.prefix, 'F-');
    expect(money.lastNumberSequence?.nextValue, 1,
        reason: 'saving a format takes no number');
  });
}
