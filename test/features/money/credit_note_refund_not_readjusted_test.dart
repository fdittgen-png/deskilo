// SPDX-License-Identifier: AGPL-3.0-or-later
//
// A credit note the workspace refunded is settled by its match and booked as
// a refund: it is never offered as a spare credit, never an adjustment line
// on the member's next invoice, and never a section of the next bill.
// (The SQL side is pinned by pgTAP 191.)
import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/core/time/date_text.dart';
import 'package:deskilo/features/money/domain/bill_sections.dart';
import 'package:deskilo/features/money/domain/invoice_line_cash.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/screens/invoices.dart' show seededMoney;

void main() {
  test('a refunded credit note stays out of the next month: no adjustment '
      'line, no spare credit, no bill section', () async {
    final money = await seededMoney(matched: false);
    final credit = money.invoices.single.copyWith(totalCents: -8000);
    money.invoices[0] = credit;
    final before = await money.fetchMemberAccount('member-1');
    expect(before.refundsDueCents, 8000, reason: 'the refund is still owed');

    await money.settleCreditInvoice(credit.id, note: 'transfer');

    final refund = money.ledger.last;
    expect(refund.category, LedgerCategory.refund);
    expect(refund.category, isNot(LedgerCategory.adjustment));
    final match = money.invoiceMatchesStore[credit.id]!;
    expect(refundedCents(credit, match), 8000);

    final account = await money.fetchMemberAccount('member-1');
    expect(account.refundsDueCents, 0, reason: 'settled, no longer owed');
    expect(
      account.creditCents,
      before.creditCents,
      reason: 'the refund adds no spare credit',
    );

    final next = yearMonth(kTestNow.year, kTestNow.month + 1);
    for (final period in [yearMonth(kTestNow.year, kTestNow.month), next]) {
      final preview = await money.previewInvoice(
        workspaceId: 'ws-1',
        memberId: 'member-1',
        period: period,
      );
      expect(
        preview.lines.where(
          (l) => l.kind == 'adjustment' || l.kind == 'refund',
        ),
        isEmpty,
        reason: 'no taxable adjustment from the refund in $period',
      );
    }

    final sections = buildBillSections(
      period: next,
      memberId: 'member-1',
      ledger: money.ledger,
      pendingEvents: const [],
      nowPeriod: next,
    );
    expect(sections.creditEntries, isEmpty);
    expect(sections.serviceEntries, isEmpty);
    expect(sections.packageEntries, isEmpty);
  });
}
