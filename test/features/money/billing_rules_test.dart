// SPDX-License-Identifier: 0BSD
//
// #802 — a subscription is paid IN ADVANCE, so its invoice has to exist
// before the month it covers; what the month actually cost cannot be
// known until it ends. One document could never be both, so there are
// two, and when each goes out is the owner's decision.
//
// The server half (migration 0142) was verified live against the hosted
// project in a rolled-back transaction: the line split partitions
// exactly, the two kinds coexist for one month, duplicates of a kind are
// refused, a zero usage invoice needs the allowance, and the sweep runs
// end to end. These pin the client's half of the same contract.
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the wire contract', () {
    test('an empty config is the documented default', () {
      const rules = BillingRules.defaults;
      expect(rules, BillingRules.fromJson(const {}));
      expect(rules.subscriptionAuto, isTrue);
      expect(rules.subscriptionAdvanceDays, 3);
      expect(rules.usageAuto, isTrue);
      // A zero invoice is opt-IN: most workspaces do not want to send a
      // document that asks for nothing.
      expect(rules.usageWhenZero, isFalse);
    });

    test('it round-trips', () {
      const rules = BillingRules(
        subscriptionAuto: false,
        subscriptionAdvanceDays: 10,
        usageAuto: false,
        usageWhenZero: true,
      );
      expect(BillingRules.fromJson(rules.toJson()), rules);
    });

    test('the advance is clamped to the same bounds the server uses', () {
      // `least(greatest(…, 0), 28)` in sweep_billing_invoices. A client
      // that let 400 through would write a config the server silently
      // reinterprets, and the settings screen would then lie.
      expect(
        BillingRules.fromJson(const {'subscription_advance_days': 400})
            .subscriptionAdvanceDays,
        BillingRules.maxAdvanceDays,
      );
      expect(
        BillingRules.fromJson(const {'subscription_advance_days': -5})
            .subscriptionAdvanceDays,
        BillingRules.minAdvanceDays,
      );
    });

    test('a config written by an older build keeps its stored choices', () {
      // Only the keys present are read; the rest fall back to defaults,
      // so a new field never rewrites an owner's existing decision.
      final rules = BillingRules.fromJson(const {'usage_auto': false});
      expect(rules.usageAuto, isFalse);
      expect(rules.subscriptionAuto, isTrue);
    });
  });

  group('the issue day is a DATE, not a number of days', () {
    test('three days before September is 29 August', () {
      expect(
        subscriptionIssueDay(DateTime(2026, 9, 17), BillingRules.defaults),
        DateTime(2026, 8, 29),
      );
    });

    test('zero days means the first of the month itself', () {
      expect(
        subscriptionIssueDay(
          DateTime(2026, 9),
          const BillingRules(subscriptionAdvanceDays: 0),
        ),
        DateTime(2026, 9),
      );
    });

    test('it crosses a year boundary without arithmetic of its own', () {
      expect(
        subscriptionIssueDay(
          DateTime(2027),
          const BillingRules(subscriptionAdvanceDays: 5),
        ),
        DateTime(2026, 12, 27),
      );
    });

    test('the longest lead still lands in the previous month', () {
      final day = subscriptionIssueDay(
        DateTime(2026, 3),
        const BillingRules(subscriptionAdvanceDays: 28),
      );
      // February 2026 has 28 days, so 28 days before 1 March is 1 Feb —
      // the earliest the cap allows, and still "just before the month".
      expect(day, DateTime(2026, 2));
    });
  });

  group('the invoice kind', () {
    test('every pre-0142 row reads as the whole-month document it is', () {
      expect(InvoiceKind.fromWire(null), InvoiceKind.full);
      expect(InvoiceKind.fromWire(''), InvoiceKind.full);
      // And an unknown kind from a NEWER server degrades to full rather
      // than throwing in a list the member is trying to read.
      expect(InvoiceKind.fromWire('something_new'), InvoiceKind.full);
    });

    test('each wire value maps to itself', () {
      for (final kind in InvoiceKind.values) {
        expect(InvoiceKind.fromWire(kind.name), kind);
      }
    });

    test('only the subscription charges a month still to come', () {
      expect(InvoiceKind.subscription.isInAdvance, isTrue);
      expect(InvoiceKind.usage.isInAdvance, isFalse);
      expect(InvoiceKind.full.isInAdvance, isFalse);
      expect(InvoiceKind.settlement.isInAdvance, isFalse);
    });

    test('a row carries its kind, and an old row still parses', () {
      Map<String, dynamic> row(Map<String, dynamic> extra) => {
            'id': 'i1',
            'workspace_id': 'ws-1',
            'member_id': 'm1',
            'number': 'INV-2026-0001',
            'issued_at': '2026-08-29T10:00:00Z',
            'period': '2026-09',
            'title': '2026-09',
            'lines': const [],
            'total_cents': 12000,
            'currency': 'EUR',
            'member_name': 'Flo',
            'member_address': '',
            'workspace_name': 'Space',
            'workspace_address': '',
            'issuer_name': 'Owner',
            'signature': 'abc',
            ...extra,
          };
      expect(Invoice.fromRow(row({'kind': 'subscription'})).kind,
          InvoiceKind.subscription);
      expect(Invoice.fromRow(row(const {})).kind, InvoiceKind.full);
    });
  });
}
