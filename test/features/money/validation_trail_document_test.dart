// SPDX-License-Identifier: 0BSD
//
// #841 — the trail is not only in the alerts feed. The document that
// raised the event carries it too, so a member looking at an invoice can
// see who released it, in what order, and how many validations it still
// owes — without hunting through the feed for a matching alert.
import 'package:deskilo/features/events/domain/event_decision.dart';
import 'package:deskilo/features/events/domain/validation_policy.dart';
import 'package:deskilo/features/events/presentation/widgets/validation_trail.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_event_repository.dart';
import '../../helpers/fake_money_repository.dart';
import '../../helpers/mock_providers.dart';
import 'invoices_test.dart' show pumpInvoices, seededMoney;

ValidationPolicy _twoValidators() => const ValidationPolicy(
      id: 'p1',
      workspaceId: 'ws-1',
      eventType: 'invoice_payment',
      requiredCount: 2,
      adminsMayValidate: true,
      eligibleAdminIds: [],
      ownerRequired: false,
    );

/// An invoice matched under a rule, so the match carries the event that
/// has to be validated before it stands.
Future<({FakeMoneyRepository money, FakeEventRepository events, String id})>
    _governedMatch(WidgetTester tester) async {
  final events = FakeEventRepository()..policies.add(_twoValidators());
  final money = await seededMoney(matched: false, events: events)
    ..matchPolicyConfigured = true;
  await pumpInvoices(tester, money: money, events: events);
  final invoice = money.invoices.single;
  final payId = money.seedPayment('member-1', invoice.totalCents);
  await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('invoice-match-${invoice.id}')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(ValueKey('invoice-match-payment-$payId')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('invoice-match-confirm')));
  await tester.pumpAndSettle();
  return (money: money, events: events, id: invoice.id);
}

void main() {
  testWidgets('the match carries the event that governs it', (tester) async {
    final r = await _governedMatch(tester);
    final match = r.money.invoiceMatchesStore[r.id]!;
    expect(match.pending, isTrue);
    expect(match.eventId, isNotNull,
        reason: 'without it the document can never say who released it');
    expect(r.events.events.any((e) => e.id == match.eventId), isTrue);
  });

  testWidgets('the invoice document shows the ordered trail and what is '
      'still owed', (tester) async {
    final r = await _governedMatch(tester);
    final eventId = r.money.invoiceMatchesStore[r.id]!.eventId!;
    r.events.decisions.add(EventDecision(
      id: 'dec-1',
      eventId: eventId,
      memberId: 'member-2',
      accept: true,
      decidedBySystem: false,
      decidedAt: kTestNow,
    ));

    await tester.tap(find.byKey(const ValueKey('invoice-tab-open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('invoice-open-${r.id}')));
    await tester.pumpAndSettle();

    expect(find.byType(ValidationTrail), findsOneWidget);
    expect(find.text('Validation trail'), findsOneWidget);
    expect(find.text('1.'), findsOneWidget);
    // Two are required and one has decided, so one is still owed.
    expect(
      find.byKey(const Key('validation-trail-awaiting')),
      findsOneWidget,
    );
  });

  testWidgets('a document nothing had to release shows no trail at all',
      (tester) async {
    final money = await seededMoney(matched: true);
    await pumpInvoices(tester, money: money, events: FakeEventRepository());
    await tester.tap(find.byKey(const ValueKey('invoice-tab-archive')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('invoice-${money.invoices.single.id}')));
    await tester.pumpAndSettle();
    expect(find.byType(ValidationTrail), findsNothing);
  });
}
