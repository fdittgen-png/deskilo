// SPDX-License-Identifier: AGPL-3.0-or-later
// Ledger values retain their billing subject, booking/event dates, immutable
// copy semantics and unreadable-row refusal without a live member lookup.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:test/test.dart';

import '../../../lib/features/money/domain/ledger_entry.dart';

void main() {
  test(
    'ledger copies preserve the subject and choose the event date when present',
    () {
      final booked = DateTime.utc(2026, 3, 26);
      final occurred = DateTime.utc(2026, 3, 3);
      final entry = LedgerEntry(
        id: 'entry-1',
        memberId: 'billing-subject-1',
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: 12345,
        description: 'Transfer',
        period: '2026-03',
        createdAt: booked,
      );
      expect(entry.on, booked);
      expect(entry.system, SystemColumns.none);
      expect(entry.copyWith(), entry);
      final dated = entry.copyWith(occurredOn: occurred);
      expect(dated.on, occurred);
      expect(dated.memberId, 'billing-subject-1');
      expect(dated.amountCents, 12345);
      expect(dated.createdAt, booked);
      expect(entry.occurredOn, isNull);
      expect(dated.copyWith(occurredOn: null), entry);
    },
  );

  test(
    'unreadable rows keep their scoped refusal rather than becoming a total',
    () {
      expect(ledgerArea('billing-subject-1'), 'ledger:billing-subject-1');
      expect(ledgerArea('ws:issuer-1'), 'ledger:ws:issuer-1');
      expect(const LedgerRowsUnreadable().toString(), 'LedgerRowsUnreadable');
    },
  );
}
