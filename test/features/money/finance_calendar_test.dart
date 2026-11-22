// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4322 -- a dated record is read on the calendar of the business it belongs to, never on the
// device's. The instants below sit at a year boundary for businesses far from any process zone (a
// laptop in Europe, a CI machine in UTC): in Auckland an invoice issued at 09:00 on 1 January 2027
// is 2027 whatever device opens it, and in Los Angeles the same instant is still 2026.
import 'package:deskilo/core/time/business_day.dart';
import 'package:deskilo/features/money/domain/finance_filter.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:flutter_test/flutter_test.dart';

/// 2026-12-31 20:00 UTC: 09:00 on 1 January 2027 in Auckland, 12:00 on 31 December 2026 in Los Angeles.
final _boundary = DateTime.utc(2026, 12, 31, 20);

FinanceInvoice _invoice(String id, String workspace, String? zone, DateTime issuedAt) => FinanceInvoice(
  id: id,
  workspaceId: workspace,
  workspaceName: workspace,
  number: 'INV-$id',
  issuedAt: issuedAt,
  totalCents: 10000,
  paidCents: 0,
  currency: 'EUR',
  state: FinanceState.open,
  timezone: zone,
);

void main() {
  final overview = FinanceOverview(
    invoices: [
      _invoice('nz', 'ws-nz', 'Pacific/Auckland', _boundary),
      _invoice('la', 'ws-la', 'America/Los_Angeles', _boundary),
    ],
  );

  test('the same instant is 2027 for the Auckland business and 2026 for the Los Angeles one', () {
    expect(financeYearOf(_boundary, 'Pacific/Auckland'), 2027);
    expect(financeYearOf(_boundary, 'America/Los_Angeles'), 2026);
  });

  test('the years offered read each document on its own business\'s calendar', () {
    expect(financeYears(overview), [2027, 2026], reason: '2027 is offered although a European or UTC device says 2026');
  });

  test('the year filter keeps a document by its business\'s year, not the device\'s', () {
    expect(const FinanceFilter(year: 2027).apply(overview).invoices.map((i) => i.id), ['nz']);
    expect(const FinanceFilter(year: 2026).apply(overview).invoices.map((i) => i.id), ['la']);
  });

  test('a payment is read on its workspace\'s calendar, through the zones of the overview', () {
    final zones = financeZones(overview);
    expect(zones['ws-nz'], 'Pacific/Auckland');
    const f = FinanceFilter(year: 2027);
    expect(f.inPeriod(_boundary, timezone: zones['ws-nz']), isTrue);
    expect(f.inPeriod(_boundary, timezone: zones['ws-la']), isFalse);
  });

  test('a business with no zone known is read in UTC, never on the device', () {
    expect(financeYearOf(DateTime.utc(2026, 12, 31, 23, 30), null), 2026);
    expect(financeYearOf(DateTime.utc(2027, 1, 1, 0, 30), null), 2027);
    expect(businessDateOf(DateTime.utc(2026, 12, 31, 23, 30), null), DateTime(2026, 12, 31));
  });

  test('a calendar date keeps its day: the business date of an instant at the edge of two days', () {
    expect(businessDateOf(_boundary, 'Pacific/Auckland'), DateTime(2027));
    expect(businessDateOf(_boundary, 'America/Los_Angeles'), DateTime(2026, 12, 31));
  });
}
