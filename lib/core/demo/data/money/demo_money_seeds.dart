// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:deskilo/core/demo/data/fixture_clock.dart';
import 'package:deskilo/core/time/date_text.dart';
import 'package:deskilo/features/money/domain/ledger_entry.dart';
import 'package:deskilo/features/money/domain/usage_record.dart';

import '../money_repository.dart';

/// #2591 — what the demo and the tests put in one space's money store
/// before a screen reads it: a confirmed payment, a credit note, a usage
/// record. Not a port: the server has no such call, a seeded row is what
/// it would already hold.
class DemoMoneySeeds {
  DemoMoneySeeds(this._m);

  final FakeMoneyRepository _m;

  /// Seeds a CONFIRMED registered payment (0068) — what record_payment
  /// or an online settlement leaves on the ledger; returns its id.
  String seedPayment(
    String memberId,
    int amountCents, {
    String description = '',
    String? period,
  }) {
    final id = 'pay-${_m.ledger.length + 1}';
    final now = kTestNow;
    _m.ledger.add(
      LedgerEntry(
        id: id,
        memberId: memberId,
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: amountCents,
        description: description,
        period: period ?? yearMonth(now.year, now.month),
        createdAt: now,
      ),
    );
    return id;
  }

  /// #512 — an account credit (credit-note excess, category
  /// 'adjustment') the imputation flow can spend on open invoices.
  String seedCreditNote(
    String memberId,
    int amountCents, {
    String description = 'Credit note',
    String? period,
  }) {
    final id = 'avoir-${_m.ledger.length + 1}';
    final now = kTestNow;
    _m.ledger.add(
      LedgerEntry(
        id: id,
        memberId: memberId,
        kind: LedgerKind.credit,
        category: LedgerCategory.adjustment,
        amountCents: amountCents,
        description: description,
        period: period ?? yearMonth(now.year, now.month),
        createdAt: now,
      ),
    );
    return id;
  }

  /// Seeds one record the way a check-out would leave it.
  UsageRecord seedUsage({
    required int reservedMinutes,
    int? actualMinutes,
    String memberId = 'member-1',
    String period = '2026-08',
    String space = 'Desk A1',
  }) {
    final from = DateTime.utc(2026, 8, 12, 9);
    final record = UsageRecord(
      id: 'usage-${_m.nextUsageNumber++}',
      memberId: memberId,
      reservationId: 'res-${_m.nextUsageNumber}',
      period: period,
      reservedFrom: from,
      reservedTo: from.add(Duration(minutes: reservedMinutes)),
      checkedInAt: actualMinutes == null ? null : from,
      checkedOutAt: actualMinutes == null
          ? null
          : from.add(Duration(minutes: actualMinutes)),
      countedMinutes: reservedMinutes,
      reservedMinutes: reservedMinutes,
      actualMinutes: actualMinutes,
      spaceLabel: space,
    );
    _m.usageRecords.add(record);
    return record;
  }
}
