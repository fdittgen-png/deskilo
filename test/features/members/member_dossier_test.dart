// SPDX-License-Identifier: 0BSD
//
// THE MEMBER DOSSIER (#704): a profile that answers the questions asked
// about a person where the person is — including the money ones, which
// used to live a hub and a search away.
//
// What is worth testing is the AUDIENCE. The same sheet shows three
// different things to three viewers, and the interesting cases are the
// ones where it must show LESS: a plain member looking at a colleague
// must not learn what that colleague owes.
import 'dart:io';

import 'package:deskilo/features/members/presentation/widgets/member_contact_card.dart';
import 'package:deskilo/features/members/presentation/widgets/member_money_card.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';

Member _member({
  String id = 'member-2',
  String userId = 'user-2',
  bool isAdmin = false,
}) =>
    Member(
      id: id,
      workspaceId: 'ws-1',
      userId: userId,
      isAdmin: isAdmin,
      isOwner: false,
      status: MemberStatus.active,
      subscriptionPct: 50,
    );

Invoice _invoice({required String id, required String number}) => Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'member-2',
      number: number,
      issuedAt: DateTime.utc(2026, 7, 31),
      title: 'July',
      lines: const [],
      totalCents: 12000,
      currency: 'EUR',
      memberName: 'Ana',
      memberAddress: '',
      workspaceName: 'DesKilo',
      workspaceAddress: '',
      issuerName: 'Flo',
      signature: '',
    );

Future<void> _pump(
  WidgetTester tester, {
  required bool viewerIsAdmin,
  bool isSelf = false,
}) async {
  // Seeded through the fake's OWN stores, so the account is computed
  // the way member_account computes it rather than asserted into
  // existence.
  final money = FakeMoneyRepository()
    ..invoices.add(_invoice(id: 'inv-1', number: 'F-2026-07'))
    ..ledger.add(
      LedgerEntry(
        id: 'l-1',
        memberId: 'member-2',
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: -4000,
        description: 'Bank transfer',
        period: '2026-07',
        createdAt: DateTime.utc(2026, 7, 20),
      ),
    );
  final workspace = FakeWorkspaceRepository.withWorkspace()
    ..memberNames = {'member-1': 'Flo', 'member-2': 'Ana'}
    ..memberEmails = {'member-2': 'ana@example.com'};
  if (!viewerIsAdmin) {
    workspace.myMember =
        workspace.myMember.copyWith(isAdmin: false, isOwner: false);
  }
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(money: money, workspace: workspace),
      child: MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: Column(children: [
              MemberContactCard(member: _member(), isSelf: isSelf),
              MemberMoneyCard(memberId: 'member-2', isSelf: isSelf),
            ]),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('an admin sees where the member stands, in one place',
      (tester) async {
    await _pump(tester, viewerIsAdmin: true);

    // The position, the document behind it, and the money already in.
    expect(find.byKey(const ValueKey('member-money')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-invoice-inv-1')), findsOneWidget);
    expect(find.text('F-2026-07'), findsWidgets);
    expect(find.textContaining('Bank transfer'), findsOneWidget);
    // The e-mail, which is an admin surface everywhere else too.
    expect(find.text('ana@example.com'), findsOneWidget);
  });

  testWidgets('a plain member sees a colleague, not their finances',
      (tester) async {
    await _pump(tester, viewerIsAdmin: false);

    // Nothing about the money — not an empty card, not a zero: nothing.
    expect(find.byKey(const ValueKey('member-money')), findsNothing);
    expect(find.text('F-2026-07'), findsNothing);
    expect(find.textContaining('Bank transfer'), findsNothing);
    // And no e-mail: member-to-member contact stays the opt-in number.
    expect(find.text('ana@example.com'), findsNothing);
  });

  testWidgets('your own money is yours to see, admin or not', (tester) async {
    await _pump(tester, viewerIsAdmin: false, isSelf: true);

    expect(find.byKey(const ValueKey('member-money')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-invoice-inv-1')), findsOneWidget);
  });

  testWidgets('a failed read SAYS so — it does not pose as "nothing owed"',
      (tester) async {
    // A refused RPC or a dead network used to leave every value null,
    // and the card simply vanished: indistinguishable from a member
    // with no money history, which is the one conclusion an admin must
    // not draw from a network blip.
    final money = FakeMoneyRepository()
      ..accountFailure = StateError('not your account');
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(money: money, workspace: workspace),
        child: const MaterialApp(
          home: Scaffold(
            body: MemberMoneyCard(memberId: 'member-2', isSelf: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('member-money-error')), findsOneWidget);
    expect(find.byKey(const ValueKey('member-money-settled')), findsNothing);
  });

  group('the server applies the SAME rule (#709)', () {
    // The card's gate is a courtesy. What makes it safe to hide a
    // revoked permission's data is that the server refuses the read
    // too — with the same permission, not with a different rule.
    final sql = File('supabase/migrations/0131_finance_permission_gates.sql')
        .readAsStringSync();

    test('one helper, self or viewFinances or issueInvoices', () {
      expect(sql, contains('function public.may_view_member_finances'));
      expect(sql, contains("has_permission(m.workspace_id, 'viewFinances')"));
      expect(sql, contains("has_permission(m.workspace_id, 'issueInvoices')"));
      expect(sql, contains('m.user_id = auth.uid()'));
    });

    test('both RPCs and both row policies ask it', () {
      expect(sql, contains("'public.member_account(uuid)'::regprocedure"));
      expect(sql, contains("'public.member_statement(uuid, text)'::regprocedure"));
      expect(sql, contains('alter policy ledger_select on public.ledger_entries'));
      expect(sql, contains('alter policy invoices_select on public.invoices'));
      // A drifted body fails LOUDLY rather than keeping the old guard.
      expect(sql, contains('guard not found — body drifted'));
    });

    test('e-mail follows manageMembers, as the client already does', () {
      expect(sql, contains("has_permission(p_workspace_id, 'manageMembers')"));
    });

    test('the card gates on exactly the permissions the helper names', () {
      final card = File('lib/features/members/presentation/widgets/'
              'member_money_card.dart')
          .readAsStringSync();
      expect(card, contains('WorkspacePermission.viewFinances'));
      expect(card, contains('WorkspacePermission.issueInvoices'));
    });
  });

  testWidgets('a settled member gets a sentence, not three zeroes',
      (tester) async {
    // Nothing seeded at all: no invoice, no ledger movement.
    final money = FakeMoneyRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(money: money, workspace: workspace),
        child: const MaterialApp(
          home: Scaffold(
            body: MemberMoneyCard(memberId: 'member-2', isSelf: true),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('member-money-settled')), findsOneWidget);
  });
}
