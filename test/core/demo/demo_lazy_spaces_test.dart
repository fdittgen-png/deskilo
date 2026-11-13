// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3846 — the Demo builds a space when it is first read, not all of them at
// the start. Counted, not timed: how many spaces exist at the first frame,
// that opening another builds exactly that one, and that what a space holds
// does not depend on when it was built.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/demo_spaces.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/features/money/providers/guest_pass_providers.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/money/providers/purchase_providers.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// What a space holds, as figures that do not move with the order of a build.
Future<List<Object>> _figures(DemoFixture f, DemoSpaceKey key) async {
  final space = f.space(key);
  final invoices = space.money.invoices;
  return [
    space.reservations.reservations.length,
    space.floorPlan.seats.length,
    invoices.length,
    invoices.fold<int>(0, (sum, i) => sum + i.totalCents),
    space.money.ledger.length,
    space.workspaces.otherMembers.length + 1,
    (await f.stores.at(key).buying.purchases.fetchPurchases(key.id)).length,
    (await f.stores.at(key).bank.fetchStatements(key.id)).length,
  ];
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  testWidgets('the first frame of the Demo has built one space, the main one', (
    tester,
  ) async {
    final root = ProviderContainer();
    addTearDown(root.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: root,
        child: const DemoWorkspace(
          child: MaterialApp(home: Scaffold(body: Text('first frame'))),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final fixture = root.read(demoSessionControllerProvider).fixture;
    expect(find.text('first frame'), findsOneWidget);
    // The measure of #3846: before, every space was built here (seven); now
    // one is.
    expect(fixture.builtSpaces, {DemoSpaceKey.home});
    expect(fixture.stores.made.difference({DemoSpaceKey.home}), isEmpty);
    // The switcher still lists them all, from their rows alone.
    expect(
      fixture.workspaces.workspaces.map((w) => w.id).toSet(),
      DemoSpaceKey.values.map((k) => k.id).toSet(),
    );
  });

  test('the main space\'s providers build no other space; opening a space '
      'builds exactly that one', () async {
    final f = DemoFixture.build();
    final home = f.workspaces.workspaces.first;
    final london = f.workspaces.workspaces.firstWhere(
      (w) => w.id == DemoSpaceKey.london.id,
    );
    var open = home;
    final container = ProviderContainer(
      overrides: [
        ...demoOverrides(f),
        currentWorkspaceProvider.overrideWith((ref) async => open),
      ],
    );
    addTearDown(container.dispose);
    await container.read(currentWorkspaceProvider.future);
    // What the first screens of the main space read.
    container
      ..read(workspaceRepositoryProvider)
      ..read(floorPlanRepositoryProvider)
      ..read(moneyRepositoryProvider)
      ..read(purchaseRepositoryProvider)
      ..read(guestPassRepositoryProvider);
    expect(f.builtSpaces, {DemoSpaceKey.home});

    open = london;
    container.invalidate(currentWorkspaceProvider);
    await container.read(currentWorkspaceProvider.future);
    container
      ..read(floorPlanRepositoryProvider)
      ..read(moneyRepositoryProvider)
      ..read(purchaseRepositoryProvider)
      ..read(guestPassRepositoryProvider);
    expect(f.builtSpaces, {DemoSpaceKey.home, DemoSpaceKey.london});
    expect(f.stores.made, {DemoSpaceKey.home, DemoSpaceKey.london});
  });

  test('a space holds the same whether it is built first or last, and '
      'whichever persona is looked through when it is', () async {
    final forward = DemoFixture.build();
    final backward = DemoFixture.build();
    final viewedAsMember = DemoFixture.build()
      ..becomePersona(DemoPersona.member);
    const keys = DemoSpaceKey.values;
    final inOrder = <DemoSpaceKey, List<Object>>{};
    for (final key in keys) {
      inOrder[key] = await _figures(forward, key);
    }
    for (final key in keys.reversed) {
      expect(
        await _figures(backward, key),
        inOrder[key],
        reason: '${key.label} built in the other order',
      );
    }
    for (final key in [keys[3], keys[0], keys[6], keys[1]]) {
      expect(
        await _figures(viewedAsMember, key),
        inOrder[key],
        reason: '${key.label} built while looking as a member',
      );
    }
    // Each space is coherent: the fail-closed check of the start, at its build.
    expect(forward.validateAllSpaces(), isEmpty);
    expect(forward.builtSpaces, keys.toSet());
  });
}
