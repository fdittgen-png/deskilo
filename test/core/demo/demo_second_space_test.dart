// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The demo's second space: a basic German coworking beside the complete
// French one, where the visitor is a member too — so Me has two spaces to
// show, and each space answers with its own rows.
import 'package:deskilo/core/demo/demo_dataset.dart';
import 'package:deskilo/core/demo/demo_finances.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/money/providers/money_providers.dart';
import 'package:deskilo/features/plan/providers/floor_plan_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('Leipzig is a German space in euros, in production, alone', () {
    final ws = DemoFixture.build().workspaces.workspaces.singleWhere(
      (w) => w.id == demoSecondSpaceId,
    );
    expect(ws.name, demoSecondSpaceName);
    expect(ws.countryCode, 'DE');
    expect(ws.currencyCode, 'EUR');
    expect(ws.timezone, 'Europe/Berlin');
    expect(ws.environment, 'prod');
    expect(ws.pairId, isEmpty, reason: 'not part of the development pair');
  });

  test('Leipzig starts basic: what a new space has, no VAT and no '
      'accounting', () {
    final ws = DemoFixture.build().workspaces.workspaces.singleWhere(
      (w) => w.id == demoSecondSpaceId,
    );
    expect(ws.featureFlags, defaultFeatureFlagsForNewWorkspace());
    final on = effectiveFeatures(
      resolveEnabledFeatures(ws.featureFlags),
      country: 'DE',
    );
    const absent = [
      WorkspaceFeature.vatManagement,
      WorkspaceFeature.vatDeclarations,
      WorkspaceFeature.inputVat,
      WorkspaceFeature.salesTax,
      WorkspaceFeature.accountingBook,
      WorkspaceFeature.accountingPeriods,
      WorkspaceFeature.purchases,
      WorkspaceFeature.purchaseAnalytics,
      WorkspaceFeature.assetRegister,
      WorkspaceFeature.premisesLease,
    ];
    for (final f in absent) {
      expect(on, isNot(contains(f)), reason: f.name);
    }
    expect(
      on,
      contains(WorkspaceFeature.invoicing),
      reason: 'a basic space still bills its members',
    );
  });

  test(
    'Ada and Bruno are members of both spaces; Chiara only of hers',
    () async {
      final fixture = DemoFixture.build();
      Future<Set<String>> spaces() async => {
        for (final m in await fixture.workspaces.fetchMyMembers())
          m.workspaceId,
      };
      Future<Set<String>> listed() async => {
        for (final w in await fixture.workspaces.fetchMyWorkspaces()) w.id,
      };

      expect(await spaces(), containsAll(['ws-1', demoSecondSpaceId]));
      fixture.becomePersona(DemoPersona.member);
      expect(await spaces(), containsAll(['ws-1', demoSecondSpaceId]));
      expect(
        fixture.secondSpace.workspaces.myMember.id,
        DemoPersona.member.memberId,
      );

      fixture.becomePersona(DemoPersona.admin);
      expect(await spaces(), isNot(contains(demoSecondSpaceId)));
      expect(
        await listed(),
        isNot(contains(demoSecondSpaceId)),
        reason: 'a space she is not a member of is not hers to see',
      );

      fixture.becomePersona(DemoPersona.owner);
      expect(
        await listed(),
        contains(demoSecondSpaceId),
        reason: 'the space comes back with the persona who is a member',
      );
    },
  );

  test("Me › Finances spans both spaces: Ada's open bill is in Leipzig", () {
    final fixture = DemoFixture.build();
    final overview = demoFinanceOverview(fixture);
    expect(overview.invoices.map((i) => i.workspaceId).toSet(), {
      'ws-1',
      demoSecondSpaceId,
    });
    expect(
      overview.outstanding.map((i) => i.workspaceName),
      contains(demoSecondSpaceName),
    );
  });

  test('the Leipzig rows are coherent: people, seats, bookings and bills', () {
    final fixture = DemoFixture.build();
    final space = fixture.secondSpace;
    expect(
      validateDemoFixture(
        workspaces: space.workspaces,
        plan: space.floorPlan,
        reservations: space.reservations,
        money: space.money,
      ),
      isEmpty,
    );
    expect(space.floorPlan.seats.map((s) => s.workspaceId).toSet(), {
      demoSecondSpaceId,
    });
    expect(space.reservations.reservations.map((r) => r.workspaceId).toSet(), {
      demoSecondSpaceId,
    });
    expect(space.money.invoices.map((i) => i.workspaceId).toSet(), {
      demoSecondSpaceId,
    });
    expect(
      space.reservations.reservations.where(
        (r) => r.memberId == DemoPersona.owner.memberId,
      ),
      isNotEmpty,
      reason: 'Ada works from Leipzig too',
    );
    expect(space.money.vatRates, isEmpty, reason: 'no VAT in Leipzig');
  });

  test('the scope answers each space from its own repositories', () async {
    final fixture = DemoFixture.build();
    final container = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(container.dispose);
    container.listen(currentWorkspaceProvider, (_, _) {});
    expect((await container.read(currentWorkspaceProvider.future))?.id, 'ws-1');
    expect(container.read(moneyRepositoryProvider), same(fixture.money));

    container
        .read(activeWorkspaceIdProvider.notifier)
        .activate(demoSecondSpaceId);
    expect(
      (await container.read(currentWorkspaceProvider.future))?.id,
      demoSecondSpaceId,
    );
    expect(
      container.read(moneyRepositoryProvider),
      same(fixture.secondSpace.money),
    );
    expect(
      container.read(floorPlanRepositoryProvider),
      same(fixture.secondSpace.floorPlan),
    );
    final members = await container
        .read(workspaceRepositoryProvider)
        .fetchMembers(demoSecondSpaceId);
    expect(members.map((m) => m.workspaceId).toSet(), {demoSecondSpaceId});
  });
}
