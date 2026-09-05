// SPDX-License-Identifier: 0BSD
//
// #881 — payment conditions: the workspace's default, a member's own
// keys on top; printed as the effective ones; changed only by a
// validated request from an authorised admin, read-only for the member.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/features/money/domain/payment_terms.dart';
import 'package:deskilo/features/money/presentation/invoice_actions.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/mock_providers.dart';

void main() {
  group('the value', () {
    const workspace = PaymentTerms(
      paymentTerms: 'Payment on receipt.',
      latePenalty: 'Three times the statutory rate.',
      recoveryIndemnity: '€40.',
    );

    test('a member override replaces only the keys it carries', () {
      const own = PaymentTerms(paymentTerms: 'Payment at 45 days.');
      final effective = workspace.mergedWith(own);
      expect(effective.paymentTerms, 'Payment at 45 days.');
      expect(effective.latePenalty, workspace.latePenalty);
      expect(workspace.mergedWith(null), workspace);
    });

    test('JSON keeps only the non-empty keys; empty means inherit', () {
      expect(const PaymentTerms(escompte: ' none ').toJson(),
          {'escompte': 'none'});
      expect(PaymentTerms.empty.isEmpty, isTrue);
      expect(PaymentTerms.fromJson({'payment_terms': 'x'}).paymentTerms, 'x');
    });
  });

  test('the document data prints the effective conditions and says whose',
      () {
    const ws = Workspace(
      id: 'ws-1',
      name: 'Demo',
      inviteCode: 'CODE',
      countryCode: 'FR',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      invoiceLegal: {'payment_terms': 'Payment on receipt.', 'escompte': 'None.'},
    );
    final inherited = legalMentionData(null, ws);
    expect(inherited['payment_terms'], 'Payment on receipt.');
    expect(inherited['payment_terms_source'], 'workspace');
    final own = legalMentionData(null, ws,
        memberTerms: const PaymentTerms(paymentTerms: 'Payment at 45 days.'));
    expect(own['payment_terms'], 'Payment at 45 days.');
    expect(own['escompte'], 'None.', reason: 'untouched keys stay the workspace\'s');
    expect(own['payment_terms_source'], 'member');
  });

  group('the card', () {
    Member member(int n,
            {bool isOwner = false, bool isAdmin = false, PaymentTerms? terms}) =>
        Member(
          id: 'member-$n',
          workspaceId: 'ws-1',
          userId: 'user-$n',
          isAdmin: isAdmin,
          isOwner: isOwner,
          status: MemberStatus.active,
          paymentTerms: terms,
        );

    Future<FakeEventRepository> pumpMemberPage(WidgetTester tester,
        {required bool viewerOwner, PaymentTerms? terms}) async {
      final workspace = FakeWorkspaceRepository.withWorkspace()
        ..myMember = member(1, isOwner: viewerOwner, isAdmin: viewerOwner)
        ..otherMembers.add(member(2, terms: terms))
        ..memberNames = {'member-1': 'Flo', 'member-2': 'Anna'};
      final events = FakeEventRepository();
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(ProviderScope(
        overrides: standardTestOverrides(workspace: workspace, events: events),
        child: const DeskiloApp(),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.settings_outlined));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Members & plans'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Anna'));
      await tester.pumpAndSettle();
      return events;
    }

    testWidgets('the owner sees the inherited conditions and requests a change',
        (tester) async {
      final events = await pumpMemberPage(tester, viewerOwner: true);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('payment-terms-card')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('payment-terms-workspace')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('payment-terms-edit')));
      await tester.pumpAndSettle();
      await tester.enterText(
          find.byKey(const ValueKey('payment-terms-terms')), 'Payment at 45 days.');
      await tester.enterText(
          find.byKey(const ValueKey('payment-terms-reason')), 'key account');
      await tester.tap(find.byKey(const ValueKey('payment-terms-submit')));
      await tester.pumpAndSettle();
      final request = events.paymentTermsRequests.single;
      expect(request.memberId, 'member-2');
      expect(request.terms.toJson(), {'payment_terms': 'Payment at 45 days.'});
      expect(request.reason, 'key account');
      expect(find.text('Change requested — pending validation'), findsOneWidget);
    });

    testWidgets('an override shows as the member\'s own and can be dropped',
        (tester) async {
      final events = await pumpMemberPage(tester,
          viewerOwner: true,
          terms: const PaymentTerms(paymentTerms: 'Payment at 45 days.'));
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('payment-terms-card')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('payment-terms-member')), findsOneWidget);
      expect(find.text('Payment at 45 days.'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('payment-terms-edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('payment-terms-inherit')));
      await tester.pumpAndSettle();
      expect(events.paymentTermsRequests.single.terms.isEmpty, isTrue);
    });
  });
}
