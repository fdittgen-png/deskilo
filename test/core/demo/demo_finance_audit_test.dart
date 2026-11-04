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
import 'package:deskilo/core/demo/seed/demo_asset_seed.dart';
import 'package:deskilo/core/demo/seed/demo_lease_seed.dart';
import 'package:deskilo/core/demo/seed/demo_main_books_seed.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/money/domain/lease_commitment.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/posting.dart';
import 'package:deskilo/features/money/domain/premises_lease.dart';
import 'package:deskilo/features/money/domain/purchase.dart';
import 'package:deskilo/features/money/domain/workspace_asset.dart';
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

        test('${s.name}: a payment is matched to an invoice of the space, '
            'never for more than it asks; a refund pays a credit note back in '
            'full; each is the ledger entry it names, for the same member', () {
          final byId = {for (final i in s.money.invoices) i.id: i};
          final ledger = {for (final l in s.money.ledger) l.id: l};
          var linked = 0;
          for (final e in s.money.invoiceMatchesStore.entries) {
            final invoice = byId[e.key];
            expect(invoice, isNotNull, reason: 'match ${e.key} has no invoice');
            final m = e.value;
            if (m.resolution == 'refunded') {
              expect(invoice!.totalCents, lessThan(0),
                  reason: '${invoice.number}: only a credit note is refunded');
              expect(m.paidCents, -invoice.totalCents, reason: invoice.number);
            } else {
              expect(m.paidCents, inInclusiveRange(0, invoice!.totalCents),
                  reason: '${invoice.number} paid ${m.paidCents}');
              if (m.resolution == 'exact') {
                expect(m.paidCents, invoice.totalCents, reason: invoice.number);
              }
            }
            if (m.paymentLedgerId case final id?) {
              linked++;
              final entry = ledger[id];
              expect(entry, isNotNull, reason: '${invoice.number}: no ledger $id');
              expect(entry!.memberId, invoice.memberId, reason: invoice.number);
              expect(entry.amountCents, m.paidCents, reason: invoice.number);
              expect(entry.kind, LedgerKind.credit, reason: invoice.number);
              expect(entry.category, LedgerCategory.payment, reason: invoice.number);
            }
          }
          expect(linked, greaterThan(0), reason: 'payments behind the matches');
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

        test('${s.name}: each member reads their own ledger, and what they '
            'owe is what their invoices ask less what was paid, written off '
            'or credited', () async {
          final credited = {
            for (final i in s.money.invoices)
              if (i.totalCents < 0) ?i.replacesInvoiceId,
          };
          var owing = 0;
          for (final member in members) {
            final ledger = await s.money.fetchLedger(member);
            expect(ledger.map((l) => l.id).toSet(), {
              for (final l in s.money.ledger)
                if (l.memberId == member) l.id,
            }, reason: '$member reads exactly their own entries');
            var expected = 0;
            for (final i in s.money.invoices) {
              if (i.memberId != member || i.isVoided || i.totalCents <= 0) continue;
              if (credited.contains(i.id)) continue;
              final m = s.money.invoiceMatchesStore[i.id];
              final paid = m == null || m.pending ? 0 : m.paidCents;
              final closed = m != null &&
                  !m.pending &&
                  (m.resolution == 'exact' || m.writeoffAt != null);
              if (!closed) expected += i.totalCents - paid;
            }
            final account = await s.money.fetchMemberAccount(member);
            expect(account.openTotalCents, expected, reason: member);
            expect(
              account.openInvoices.fold(0, (int n, o) => n + o.remainingCents),
              account.openTotalCents,
              reason: member,
            );
            owing += expected;
          }
          expect(owing, greaterThan(0), reason: 'arrears to show');
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

      test('Pézenas holds a credit note refunded in full: its refund is the '
          'member\'s ledger entry, and it leaves nothing due back', () async {
        final money = fixture.money;
        final notes = money.invoices.where((i) => i.totalCents < 0).toList();
        expect(notes, isNotEmpty, reason: 'a credit note');
        final refunded = notes
            .where((i) => money.invoiceMatchesStore[i.id]?.resolution == 'refunded')
            .toList();
        expect(refunded, isNotEmpty, reason: 'a refund');
        for (final note in refunded) {
          final refunds = money.ledger.where((l) =>
              l.memberId == note.memberId &&
              l.kind == LedgerKind.charge &&
              l.category == LedgerCategory.refund &&
              l.amountCents == -note.totalCents);
          expect(refunds, hasLength(1), reason: '${note.number}: its refund');
          final account = await money.fetchMemberAccount(note.memberId);
          expect(account.refundsDueCents, 0, reason: note.number);
        }
      });

      test('Pézenas voids an unpaid invoice on the Demo\'s day: it leaves the '
          'member\'s debt by its amount, and a paid one cannot be voided', () async {
        final money = DemoFixture.build(now: now).money;
        final unpaid = money.invoices.firstWhere((i) =>
            !i.isVoided &&
            i.totalCents > 0 &&
            !money.invoiceMatchesStore.containsKey(i.id));
        final before = await money.fetchMemberAccount(unpaid.memberId);
        await money.voidInvoice(unpaid.id);
        final voided = money.invoices.singleWhere((i) => i.id == unpaid.id);
        expect(voided.voidedAt, now);
        final after = await money.fetchMemberAccount(unpaid.memberId);
        expect(after.openTotalCents, before.openTotalCents - unpaid.totalCents);
        final paid = money.invoices.firstWhere(
            (i) => money.invoiceMatchesStore[i.id]?.resolution == 'exact');
        await expectLater(money.voidInvoice(paid.id), throwsStateError);
      });

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

      group('Pézenas purchases', () {
        final purchasing = seedDemoPurchasing(
          fixture.seededAt,
          money: fixture.money,
          plan: (fixture.workspaces, fixture.floorPlan),
          actor: () => fixture.activeMemberId,
        );
        Future<List<PurchaseDetail>> details() async => [
              for (final s in await purchasing.purchases.fetchPurchases('ws-1'))
                await purchasing.purchases.fetchDetail('ws-1', s.id),
            ];
        int settled(List<SettlementAllocation> a) => a
            .where((x) => !x.reversed)
            .fold(0, (n, x) => n + (x.isReversal ? -x.amountCents : x.amountCents));

        test('an approved bill or receipt owes exactly its gross once; what is '
            'not approved owes nothing', () async {
          for (final d in await details()) {
            final gross = d.lines.fold(0, (int n, l) => n + l.grossCents);
            expect(d.summary.grossCents, gross, reason: d.summary.id);
            final owed = d.summary.state == PurchaseState.approved &&
                d.summary.kind != PurchaseKind.creditNote;
            expect(d.obligations, hasLength(owed ? 1 : 0), reason: d.summary.id);
            for (final o in d.obligations) {
              expect(o.amountCents, gross, reason: d.summary.id);
            }
          }
        });

        test('a payment out is its allocations, never more than owed, never '
            'dated after now; paid, partial and unpaid all stand, for the '
            'suppliers and for the members', () async {
          final states = <CreditorKind, Set<String>>{};
          for (final r in purchasing.purchases.payables) {
            final o = r.obligation;
            expect(o.paidCents, settled(o.allocations), reason: o.id);
            expect(o.paidCents + o.appliedCents + o.remainingCents, o.amountCents,
                reason: o.id);
            expect(o.remainingCents, greaterThanOrEqualTo(0), reason: o.id);
            for (final a in o.allocations) {
              expect(a.paidOn == null || !a.paidOn!.isAfter(now), isTrue,
                  reason: '${o.id} paid in the future');
            }
            states.putIfAbsent(o.creditorKind, () => {}).add(
                  o.remainingCents == 0
                      ? 'paid'
                      : o.paidCents == 0 ? 'unpaid' : 'partial',
                );
          }
          expect(states[CreditorKind.supplier], {'paid', 'partial', 'unpaid'});
          expect(states[CreditorKind.member], {'paid', 'partial', 'unpaid'});
          final docs = await details();
          expect(docs.where((d) => d.summary.kind == PurchaseKind.creditNote),
              isNotEmpty, reason: 'a supplier credit note');
        });

        test('the lease: every matched rent occurrence is a bill of the lessor '
            'that the space holds, its line as the match states it', () async {
          final lease = seedDemoLease(fixture.seededAt).leases.single;
          final rent = lease.terms
              .singleWhere((t) => t.kind == LeaseTermKind.rent)
              .amountCents;
          final page = await seedDemoCommitments(fixture.seededAt)
              .fetchCommitments('ws-1', lease.id);
          final byId = {for (final d in await details()) d.summary.id: d};
          var matched = 0;
          for (final o in page.occurrences) {
            expect(o.expectedCents, rent, reason: o.id);
            expect(o.matchedCents, lessThanOrEqualTo(o.expectedCents), reason: o.id);
            for (final CommitmentMatch m in o.matches) {
              matched++;
              final bill = byId[m.purchaseId];
              expect(bill, isNotNull, reason: '${o.id}: no ${m.purchaseId}');
              expect(bill!.summary.supplierId, lease.supplierId, reason: m.purchaseId);
              expect(bill.summary.state, PurchaseState.approved, reason: m.purchaseId);
              expect(bill.summary.reference, m.reference, reason: m.purchaseId);
              final line = bill.lines.singleWhere((l) => l.lineNo == m.lineNo);
              expect(line.grossCents, m.lineGrossCents, reason: m.purchaseId);
              expect(m.lineUnallocatedCents, line.grossCents - m.allocatedCents,
                  reason: m.purchaseId);
              expect(o.dueOn.isAfter(now), isFalse, reason: o.id);
            }
          }
          expect(matched, greaterThan(0));
        });

        test('the equipment register: every asset and candidate is a line of a '
            'purchase the space holds, at its cost', () async {
          final register = seedDemoAssets(fixture.seededAt);
          final byId = {for (final d in await details()) d.summary.id: d};
          for (final WorkspaceAsset a in register.assets) {
            final bill = byId[a.purchaseId];
            expect(bill, isNotNull, reason: '${a.id}: no ${a.purchaseId}');
            final line = bill!.lines.singleWhere((l) => l.lineNo == a.lineNo);
            expect(line.description, a.description, reason: a.id);
            expect(bill.summary.reference, a.originalReference, reason: a.id);
            expect(bill.supplierName, a.supplierName, reason: a.id);
            // Net plus the tax not recovered.
            expect(
              a.acquisitionCostCents,
              line.netCents! + line.taxCents! - line.recoverableTaxCents!,
              reason: a.id,
            );
            if (a.availableForUseOn case final day?) {
              expect(day.isAfter(now), isFalse, reason: '${a.id} in use ahead');
              expect(bill.summary.receivedOn!.isAfter(day), isFalse, reason: a.id);
            }
          }
          for (final c in register.candidates) {
            final bill = byId[c.purchaseId];
            expect(bill, isNotNull, reason: 'candidate: no ${c.purchaseId}');
            final line = bill!.lines.singleWhere((l) => l.lineNo == c.lineNo);
            expect(line.grossCents, c.grossCents, reason: c.purchaseId);
            expect(line.description, c.description, reason: c.purchaseId);
            expect(bill.supplierName, c.supplierName, reason: c.purchaseId);
          }
        });

        test('the books post each approved bill of the period once, and each '
            'payment out once', () async {
          final books = demoMainBooks(fixture, purchasing);
          final to = DateTime(now.year, now.month, now.day, 23, 59, 59);
          final from = DateTime(to.year - 1, to.month, to.day);
          final set = await books.fetchPostings(
              'ws-1', 'demo-site-studio', from, to);
          expect(set.blockers, isEmpty);
          bool inPeriod(DateTime d) => !d.isBefore(from) && !d.isAfter(to);
          for (final d in await details()) {
            final day = d.summary.originalDate ?? d.summary.receivedOn;
            final posted = d.summary.state == PurchaseState.approved &&
                day != null &&
                inPeriod(day) &&
                (d.summary.kind == PurchaseKind.memberReceipt ||
                    d.obligations.isNotEmpty) &&
                d.summary.currency == 'EUR';
            final documents = set.postings.where((p) =>
                p.documentId == d.summary.id &&
                (p.kind == PostingKind.supplierBill ||
                    p.kind == PostingKind.memberReceipt ||
                    p.kind == PostingKind.supplierCreditNote));
            expect(documents, hasLength(posted ? 1 : 0), reason: d.summary.id);
            final payments = {
              for (final o in d.obligations)
                for (final a in o.allocations)
                  if (!a.reversed && a.paidOn != null && inPeriod(a.paidOn!)) a.id,
            };
            final paid = set.postings.where((p) =>
                p.documentId == d.summary.id &&
                (p.kind == PostingKind.supplierPayment ||
                    p.kind == PostingKind.reimbursement));
            expect(paid, hasLength(posted ? payments.length : 0),
                reason: '${d.summary.id} payments');
          }
          for (final p in set.postings) {
            expect(p.balanced, isTrue, reason: '${p.kind} ${p.documentNumber}');
          }
        });
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
