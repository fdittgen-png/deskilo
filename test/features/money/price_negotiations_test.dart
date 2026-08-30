// SPDX-License-Identifier: 0BSD
//
// #739 — price negotiations. The tariff is the default; a member may
// have their own deal. The member reads it beside the tariff on the
// Statement face and sees who can look; an owner (or finance admin)
// proposes it from the member's sheet; it goes through validation;
// the feed narrates it. The server side (0137) has its own harness.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/money/domain/price_negotiation.dart';
import 'package:deskilo/features/money/domain/statement.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_floor_plan_repository.dart';
import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/navigation.dart';
import '../members/members_screen_test.dart' show openSheet, pumpMembers;
import 'money_faces_test.dart' show pumpFaces;

final _deal = PriceNegotiation(
  defaultFeeCents: 25000,
  defaultOverageFeeCents: 1200,
  active: NegotiationDeal(
    feeCents: 15000,
    discountPercent: 10,
    validFrom: DateTime(2026, 5, 1),
    status: 'active',
  ),
);

void main() {
  test('Statement.fromRpc reads the negotiated block and the discount', () {
    final s = Statement.fromRpc({
      'period': '2026-05',
      'subscription_pct': 100,
      'fee_cents': 15000,
      'included_half_days': 42,
      'open_days': 21,
      'used_half_days': 3,
      'extra_half_days': 0,
      'overage_cents': 0,
      'credits_cents': 0,
      'balance_cents': -15000,
      'discount_percent': 10,
      'negotiated': {
        'default_fee_cents': 25000,
        'default_overage_fee_cents': 1200,
        'fee_cents': 15000,
        'overage_fee_cents': null,
        'discount_percent': 10,
        'valid_from': '2026-05-01',
        'active': true,
      },
    });
    expect(s.discountPercent, 10);
    expect(s.negotiated?.active, isTrue);
    expect(s.negotiated?.defaultFeeCents, 25000);
    expect(s.negotiated?.feeCents, 15000);
    expect(s.negotiated?.overageFeeCents, isNull);
    // An older server without the block still parses.
    expect(Statement.fromRpc({
      'period': '2026-05', 'subscription_pct': 100, 'fee_cents': 1,
      'included_half_days': 0, 'open_days': 0, 'used_half_days': 0,
      'extra_half_days': 0, 'overage_cents': 0, 'credits_cents': 0,
      'balance_cents': 0,
    }).negotiated, isNull);
  });

  testWidgets('the Statement face shows my deal beside the tariff, and who '
      'can see it', (tester) async {
    final money = FakeMoneyRepository()..negotiations['member-1'] = _deal;
    await pumpFaces(tester, money: money);
    final card = find.byKey(const ValueKey('negotiation-card'));
    await tester.scrollUntilVisible(card, 200,
        scrollable: find.byType(Scrollable).first);
    expect(card, findsOneWidget);
    // Fee: tariff struck through, mine in bold; overage untouched.
    expect(find.descendant(of: find.byKey(const ValueKey('negotiation-row-fee')),
        matching: find.text('€150.00')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const ValueKey('negotiation-row-fee')),
        matching: find.text('€250.00')), findsOneWidget);
    expect(find.descendant(
        of: find.byKey(const ValueKey('negotiation-row-overage')),
        matching: find.text('—')), findsOneWidget);
    expect(find.descendant(
        of: find.byKey(const ValueKey('negotiation-row-discount')),
        matching: find.text('10 %')), findsOneWidget);
    expect(find.textContaining('applies since May 2026'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('negotiation-who-can-see')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('access-sheet')), findsOneWidget);
    expect(find.byKey(const ValueKey('access-rule-negotiations')), findsOneWidget);
  });

  testWidgets('on the tariff the card says so; the feature off hides it',
      (tester) async {
    await pumpFaces(tester);
    expect(find.text('You are on the workspace tariff.'), findsOneWidget);
  });

  testWidgets('the feature off hides the card', (tester) async {
    await pumpFaces(tester, flags: const {'priceNegotiations': false});
    expect(find.byKey(const ValueKey('negotiation-card')), findsNothing);
  });

  testWidgets('the owner proposes a deal from the member sheet; it is '
      'recorded pending', (tester) async {
    final money = FakeMoneyRepository();
    await pumpMembers(tester, money: money);
    await openSheet(tester, 'Ana');
    final tile = find.byKey(const ValueKey('member-negotiation-member-2'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('negotiation-fee')), '150');
    await tester.enterText(
        find.byKey(const ValueKey('negotiation-discount')), '10');
    await tester.enterText(
        find.byKey(const ValueKey('negotiation-note')), 'founder rate');
    await tester.tap(find.byKey(const ValueKey('negotiation-submit')));
    await tester.pumpAndSettle();

    final p = money.proposedNegotiations.single;
    expect(p.memberId, 'member-2');
    expect(p.feeCents, 15000);
    expect(p.overageFeeCents, isNull);
    expect(p.discountPercent, 10);
    expect(p.note, 'founder rate');
    expect(find.text('Deal proposed — waiting for validation.'), findsOneWidget);
    expect(money.negotiations['member-2']?.pending?.status, 'pending');
  });

  testWidgets('a plain member never sees the proposal entry', (tester) async {
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
    workspace.myMember =
        workspace.myMember.copyWith(isAdmin: false, isOwner: false);
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(workspace: workspace),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    // No Members & plans for a plain member at all; the tile widget
    // itself gates on owner / finance permission — covered by the
    // owner path above and the server rule (0137).
    expect(find.byKey(const ValueKey('member-negotiation-member-2')),
        findsNothing);
  });

  testWidgets('the feed narrates a proposal with its terms', (tester) async {
    final events = FakeEventRepository()
      ..events.add(WorkspaceEvent(
        id: 'evt-neg',
        workspaceId: 'ws-1',
        type: EventType.priceNegotiation,
        action: EventAction.submitted,
        actorMemberId: 'member-1',
        subjectMemberId: 'member-2',
        payload: const {
          'fee_cents': 15000,
          'overage_fee_cents': null,
          'discount_percent': 10,
          'note': 'founder rate',
          'valid_from': '2026-05-01',
        },
        status: EventStatus.pending,
        createdAt: kTestNow,
      ));
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(
        events: events,
        workspace: workspace,
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      ),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await openAlertsTab(tester);
    expect(find.textContaining('Flo proposes a deal for Ana'), findsOneWidget);
    expect(find.textContaining('€150.00 · −10 %'), findsOneWidget);
  });

  // ---- #744 — services, packages and the occupation
  testWidgets('the card shows the occupation and the negotiated items '
      'against the catalogue', (tester) async {
    final money = FakeMoneyRepository();
    money.negotiations['member-1'] = PriceNegotiation(
      defaultFeeCents: 25000,
      defaultOverageFeeCents: 1200,
      active: NegotiationDeal(
        subscriptionPct: 60,
        previousSubscriptionPct: 50,
        items: {'services': {'service-coffee': 100}},
        validFrom: DateTime(2026, 5, 1),
        status: 'active',
      ),
    );
    await pumpFaces(tester, money: money);
    final card = find.byKey(const ValueKey('negotiation-card'));
    await tester.scrollUntilVisible(card, 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.descendant(
        of: find.byKey(const ValueKey('negotiation-row-occupation')),
        matching: find.text('60 %')), findsOneWidget);
    expect(find.descendant(
        of: find.byKey(const ValueKey('negotiation-row-occupation')),
        matching: find.text('50 %')), findsOneWidget);
    final coffee = find.byKey(const ValueKey('negotiation-item-service-coffee'));
    expect(coffee, findsOneWidget);
    expect(find.descendant(of: coffee, matching: find.text('€1.00')),
        findsOneWidget);
    expect(find.descendant(of: coffee, matching: find.text('€1.50')),
        findsOneWidget);
  });

  testWidgets('a proposal carries the occupation and an item price',
      (tester) async {
    final money = FakeMoneyRepository();
    await pumpMembers(tester, money: money);
    await openSheet(tester, 'Ana');
    final tile = find.byKey(const ValueKey('member-negotiation-member-2'));
    await tester.ensureVisible(tile);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('negotiation-occupation')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('75 %').last);
    await tester.pumpAndSettle();
    final coffee =
        find.byKey(const ValueKey('negotiation-item-services-service-coffee'));
    await tester.ensureVisible(coffee);
    await tester.enterText(coffee, '1');
    await tester.ensureVisible(find.byKey(const ValueKey('negotiation-submit')));
    await tester.tap(find.byKey(const ValueKey('negotiation-submit')));
    await tester.pumpAndSettle();
    final p = money.proposedNegotiations.single;
    expect(p.subscriptionPct, 75);
    expect(p.items, {'services': {'service-coffee': 100}});
    expect(p.feeCents, isNull);
  });

  testWidgets('the consumption sheet prices a service at my deal',
      (tester) async {
    final money = FakeMoneyRepository();
    money.negotiations['member-1'] = PriceNegotiation(
      defaultFeeCents: 25000,
      defaultOverageFeeCents: 1200,
      active: NegotiationDeal(
        items: {'services': {'service-coffee': 100}},
        validFrom: DateTime(2026, 5, 1),
        status: 'active',
      ),
    );
    await pumpFaces(tester, money: money);
    await tester.tap(find.byKey(const ValueKey('money-face-payments')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Add consumption'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Add consumption'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Coffee — €1.00'), findsOneWidget);
  });

  testWidgets('the feed line carries the occupation and the item count',
      (tester) async {
    final events = FakeEventRepository()
      ..events.add(WorkspaceEvent(
        id: 'evt-neg2',
        workspaceId: 'ws-1',
        type: EventType.priceNegotiation,
        action: EventAction.submitted,
        actorMemberId: 'member-1',
        subjectMemberId: 'member-2',
        payload: const {
          'subscription_pct': 60,
          'items': {'services': {'a': 100}, 'packages': {'b': 2000}},
          'item_count': 2,
        },
        status: EventStatus.pending,
        createdAt: kTestNow,
      ));
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(
        events: events,
        workspace: workspace,
        floorPlan: FakeFloorPlanRepository()..seedSmallPlan(),
      ),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await openAlertsTab(tester);
    expect(find.textContaining('60 % · 2 items'), findsOneWidget);
  });

  // ---- #749 — the two permissions
  Future<FakeMoneyRepository> pumpAsAdmin(WidgetTester tester,
      List<String> adminPerms) async {
    final money = FakeMoneyRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace()
      ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'};
    workspace.myMember =
        workspace.myMember.copyWith(isOwner: false, isAdmin: true);
    workspace.workspaces[0] = workspace.workspaces[0]
        .copyWith(rolePermissions: {'admin': adminPerms});
    workspace.otherMembers.add(const Member(
      id: 'member-2',
      workspaceId: 'ws-1',
      userId: 'user-2',
      isAdmin: false,
      isOwner: false,
      status: MemberStatus.active,
    ));
    tester.view.physicalSize = const Size(800, 2200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: standardTestOverrides(workspace: workspace, money: money),
      child: const DeskiloApp(),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Members & plans'));
    await tester.pumpAndSettle();
    await openSheet(tester, 'Ana');
    return money;
  }

  testWidgets('an admin with only "view" opens the deal read-only',
      (tester) async {
    final money = await pumpAsAdmin(tester, ['manageMembers', 'viewNegotiations']);
    final tile = find.byKey(const ValueKey('member-negotiation-member-2'));
    await tester.ensureVisible(tile);
    expect(find.descendant(of: tile, matching: find.text('Read only')),
        findsOneWidget);
    await tester.tap(tile);
    await tester.pumpAndSettle();
    final submit = tester.widget<FilledButton>(
        find.byKey(const ValueKey('negotiation-submit')));
    expect(submit.onPressed, isNull);
    expect(money.proposedNegotiations, isEmpty);
  });

  testWidgets('an admin with "manage" proposes; one with neither sees nothing',
      (tester) async {
    await pumpAsAdmin(tester, ['manageMembers', 'manageNegotiations']);
    final tile = find.byKey(const ValueKey('member-negotiation-member-2'));
    await tester.ensureVisible(tile);
    expect(find.descendant(of: tile, matching: find.text('Read only')),
        findsNothing);
  });

  testWidgets('an admin with neither permission has no entry', (tester) async {
    await pumpAsAdmin(tester, ['manageMembers', 'viewFinances']);
    expect(find.byKey(const ValueKey('member-negotiation-member-2')),
        findsNothing);
  });
}
