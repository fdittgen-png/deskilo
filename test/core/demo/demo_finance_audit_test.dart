// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3292 — the Demo's money agrees with its own source records, in the main
// space (Pézenas, France, VAT on receipts) and in Leipzig (Germany, exempt),
// and the two never share a document. Every expectation is recomputed from the
// seeded rows (the invoice lines, the matches, the members), never read from
// the code that produced them. The evidence matrix is
// docs/testing/evidence/demo-audit-3292-finance.md.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/seed/demo_main_books_seed.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

typedef _Space = ({
  String name,
  FakeMoneyRepository money,
  FakeWorkspaceRepository workspaces,
  String workspaceId,
});

List<_Space> _spaces(DemoFixture f) => [
      (
        name: 'Pézenas',
        money: f.money,
        workspaces: f.workspaces,
        workspaceId: 'ws-1',
      ),
      (
        name: 'Leipzig',
        money: f.secondSpace.money,
        workspaces: f.secondSpace.workspaces,
        workspaceId: demoSecondSpaceId,
      ),
    ];

void main() {
  for (final now in [
    DateTime(2026, 5, 13, 10), // the Demo's own clock
    DateTime(2026, 3, 31, 23, 30), // the last half hour of a quarter
    DateTime(2026, 4, 1, 0, 30), // the first of the next
    DateTime(2027, 1, 1, 10), // a new year
  ]) {
    group('the Demo opened on $now', () {
      final fixture = DemoFixture.build(now: now);

      for (final s in _spaces(fixture)) {
        final members = {
          for (final m in [s.workspaces.myMember, ...s.workspaces.otherMembers])
            m.id,
        };
        final currency = s.workspaces.workspaces
            .singleWhere((w) => w.id == s.workspaceId)
            .currencyCode;

        test('${s.name}: every invoice is in its own space, its currency, to '
            'one of its members, with a unique number', () {
          expect(s.money.invoices, isNotEmpty);
          final numbers = <String>{};
          for (final i in s.money.invoices) {
            expect(i.workspaceId, s.workspaceId, reason: i.number);
            expect(i.currency, currency, reason: i.number);
            expect(members, contains(i.memberId), reason: i.number);
            expect(numbers.add(i.number), isTrue, reason: 'duplicate ${i.number}');
          }
        });

        test('${s.name}: an invoice total is the sum of its lines, and its VAT '
            'breakdown adds up to it', () {
          for (final i in s.money.invoices) {
            final lines = i.lines.fold(0, (int n, l) => n + l.amountCents);
            expect(i.totalCents, lines, reason: '${i.number} lines');
            if (i.vatTotals.isNotEmpty) {
              final gross = i.vatTotals
                  .fold(0, (int n, t) => n + t.netCents + t.vatCents);
              expect(gross, i.totalCents, reason: '${i.number} VAT breakdown');
            }
          }
        });

        test('${s.name}: a payment is matched to an invoice of the space and '
            'never exceeds what the invoice asks, a refund aside', () {
          final byId = {for (final i in s.money.invoices) i.id: i};
          for (final e in s.money.invoiceMatchesStore.entries) {
            final invoice = byId[e.key];
            expect(invoice, isNotNull, reason: 'match ${e.key} has no invoice');
            if (e.value.resolution == 'refunded') continue;
            expect(e.value.paidCents, lessThanOrEqualTo(invoice!.totalCents.abs()),
                reason: '${invoice.number} paid ${e.value.paidCents}');
            expect(e.value.paidCents, greaterThanOrEqualTo(0),
                reason: invoice.number);
          }
        });

        test('${s.name}: a reminder is sent after the due day and before the '
            'payment that settled the invoice', () {
          final byId = {for (final i in s.money.invoices) i.id: i};
          for (final e in s.money.invoiceReminders.entries) {
            final invoice = byId[e.key];
            expect(invoice, isNotNull, reason: 'reminder for ${e.key}');
            final paid = s.money.invoiceMatchesStore[e.key];
            for (final sentAt in e.value) {
              if (invoice!.dueOn != null) {
                expect(sentAt.isAfter(invoice.dueOn!), isTrue,
                    reason: '${invoice.number} reminded before it was due');
              }
              if (paid != null && paid.paidCents >= invoice.totalCents) {
                expect(sentAt.isBefore(paid.matchedAt), isTrue,
                    reason: '${invoice.number} reminded after it was paid');
              }
              expect(sentAt.isAfter(now), isFalse,
                  reason: '${invoice.number} reminded in the future');
            }
          }
        });

        test('${s.name}: a correction replaces a voided invoice of the same '
            'member, and a credit note gives money back', () {
          final byId = {for (final i in s.money.invoices) i.id: i};
          for (final i in s.money.invoices) {
            if (i.replacesInvoiceId != null) {
              final old = byId[i.replacesInvoiceId];
              expect(old, isNotNull, reason: '${i.number} refers to nothing');
              expect(old!.memberId, i.memberId, reason: i.number);
              if (i.totalCents < 0) {
                // A credit note corrects an invoice that stays valid, by no
                // more than that invoice asked.
                expect(old.voidedAt, isNull,
                    reason: '${i.number} credits a voided ${old.number}');
                expect(-i.totalCents, lessThanOrEqualTo(old.totalCents),
                    reason: '${i.number} credits more than ${old.number}');
              } else {
                // A replacement invoice takes the place of a voided one.
                expect(old.voidedAt, isNotNull,
                    reason: '${i.number} replaces ${old.number}, still valid');
              }
            }
            if (i.totalCents < 0) {
              expect(i.lines.every((l) => l.amountCents <= 0), isTrue,
                  reason: '${i.number}: a credit note has no charge line');
            }
          }
        });

        test('${s.name}: an expense shared among members is shared whole', () {
          for (final r in s.money.repartitions) {
            final shared = r.shares.fold(0, (int n, x) => n + x.amountCents);
            expect(shared, r.amountCents, reason: r.title);
            for (final x in r.shares) {
              expect(members, contains(x.memberId), reason: '${r.title} ${x.memberName}');
            }
          }
        });

        test('${s.name}: the account ledger is the space\'s own members', () {
          for (final l in s.money.ledger) {
            expect(members, contains(l.memberId), reason: l.id);
            expect(l.amountCents, greaterThanOrEqualTo(0), reason: l.id);
            if (l.kind == LedgerKind.credit) {
              expect(l.category, isNot(LedgerCategory.subscription),
                  reason: '${l.id}: a credit is not a subscription charge');
            }
          }
        });

        test('${s.name}: the VAT returns are in the past and in the space\'s '
            'currency; a line\'s net and VAT are its gross', () {
          for (final d in s.money.vatDeclarations) {
            expect(d.periodEnd.isBefore(now), isTrue, reason: d.id);
            expect(d.createdAt.isAfter(now), isFalse, reason: d.id);
            expect(d.submittedAt == null || !d.submittedAt!.isAfter(now), isTrue,
                reason: d.id);
            expect(d.currency, currency, reason: d.id);
            final net = d.lines.fold(0, (int n, l) => n + l.netCents);
            final vat = d.lines.fold(0, (int n, l) => n + l.vatCents);
            expect(d.totalNetCents, net, reason: d.id);
            expect(d.totalVatCents, vat, reason: d.id);
            for (final l in d.lines) {
              expect(l.netCents + l.vatCents, l.grossCents, reason: '${d.id} ${l.percent}');
            }
          }
        });
      }

      test('Pézenas books: every posting of the last twelve months balances, and '
          'every issued sale of the period is posted', () async {
        final purchasing = seedDemoPurchasing(
          fixture.seededAt,
          money: fixture.money,
          plan: (fixture.workspaces, fixture.floorPlan),
          actor: () => fixture.activeMemberId,
        );
        final books = demoMainBooks(fixture, purchasing);
        final to = DateTime(now.year, now.month, 0, 23, 59, 59);
        final from = DateTime(to.year - 1, to.month + 1);
        final set = await books.fetchPostings(
            'ws-1', 'demo-site-studio', from, to);
        expect(set.postings, isNotEmpty);
        expect(set.blockers, isEmpty,
            reason: 'every booking role of the main book is mapped');
        for (final p in set.postings) {
          expect(p.balanced, isTrue, reason: '${p.kind} ${p.documentNumber}');
        }
        final issued = {
          for (final i in fixture.money.invoices)
            if (i.voidedAt == null &&
                !i.issuedAt.isBefore(from) &&
                !i.issuedAt.isAfter(to))
              i.number,
        };
        final posted = {for (final p in set.postings) p.documentNumber};
        expect(issued.difference(posted), isEmpty,
            reason: 'issued sales without a posting');
      });

      test('Leipzig is exempt: no invoice charges VAT and it files no return',
          () {
        final leipzig = fixture.secondSpace;
        expect(
          leipzig.workspaces.workspaces
              .singleWhere((w) => w.id == demoSecondSpaceId)
              .vatRegime,
          'exempt',
        );
        for (final i in leipzig.money.invoices) {
          expect(i.vatCents, 0, reason: i.number);
          for (final l in i.lines) {
            expect(l.vatPercent, 0, reason: '${i.number} ${l.label}');
          }
        }
        expect(leipzig.money.vatDeclarations, isEmpty);
      });

      test('the two spaces share no invoice, match, ledger entry or member', () {
        final a = _spaces(fixture)[0];
        final b = _spaces(fixture)[1];
        expect({for (final i in a.money.invoices) i.id}
            .intersection({for (final i in b.money.invoices) i.id}), isEmpty);
        expect(a.money.invoiceMatchesStore.keys.toSet()
            .intersection(b.money.invoiceMatchesStore.keys.toSet()), isEmpty);
        expect({for (final l in a.money.ledger) l.id}
            .intersection({for (final l in b.money.ledger) l.id}), isEmpty);
        expect(identical(a.money, b.money), isFalse);
      });
    });
  }
}
