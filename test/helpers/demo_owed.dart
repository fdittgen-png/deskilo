// SPDX-License-Identifier: AGPL-3.0-or-later
//
// What the Demo person still owes, per currency, read straight from the four
// spaces' money (the invoices addressed to them, less what was matched), so a
// test of Me's overview does not derive its expectation from the overview.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';

Map<String, int> demoOwedFromTheSpaces(DemoFixture f) {
  final me = f.actor.memberId;
  final out = <String, int>{};
  for (final money in [
    f.money,
    f.secondSpace.money,
    f.london.money,
    f.newYork.money,
  ]) {
    for (final i in money.invoices) {
      if (i.memberId != me ||
          i.voidedAt != null ||
          i.kind == InvoiceKind.settlement ||
          i.totalCents <= 0 ||
          i.settledByInvoiceId != null) {
        continue;
      }
      final paid = money.invoiceMatchesStore[i.id]?.paidCents ?? 0;
      final left = i.totalCents - paid;
      if (left > 0) out[i.currency] = (out[i.currency] ?? 0) + left;
    }
  }
  return out;
}
