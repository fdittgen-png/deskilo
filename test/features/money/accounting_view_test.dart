// SPDX-License-Identifier: 0BSD
//
// #831 — the accounting view: the settlement leaves, its payment is
// allocated to the sources it regroups — exact, partial oldest-first,
// nothing while pending, nothing for a voided settlement — and every
// export receives that view.
import 'package:deskilo/features/money/domain/accounting_view.dart';
import 'package:deskilo/features/money/domain/billing_rules.dart';
import 'package:deskilo/features/money/domain/fec.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_money_repository.dart';

Invoice _inv(String id, int total,
        {InvoiceKind kind = InvoiceKind.full,
        List<SettledSource> settles = const [],
        DateTime? voidedAt}) =>
    Invoice(
      id: id,
      workspaceId: 'ws-1',
      memberId: 'member-1',
      number: id.toUpperCase(),
      issuedAt: DateTime.utc(2026, 8, 1),
      period: '2026-08',
      title: '2026-08',
      lines: [InvoiceLine(kind: 'subscription', label: '', amountCents: total)],
      totalCents: total,
      currency: 'EUR',
      memberName: 'Flo',
      memberAddress: '',
      workspaceName: 'ws',
      workspaceAddress: '',
      issuerName: 'Flo',
      signature: '',
      kind: kind,
      settles: settles,
      voidedAt: voidedAt,
    );

SettledSource _src(String id, int total) => SettledSource(
      invoiceId: id,
      number: id.toUpperCase(),
      period: '2026-08',
      kind: InvoiceKind.full,
      totalCents: total,
      lines: const [],
    );

InvoiceMatch _match(String id, int paid,
        {String resolution = 'exact', String status = 'confirmed'}) =>
    InvoiceMatch(
      invoiceId: id,
      paidCents: paid,
      resolution: resolution,
      status: status,
      matchedAt: DateTime.utc(2026, 9, 1),
      byName: 'Flo',
    );

void main() {
  final a = _inv('a', 3000);
  final b = _inv('b', 2000);
  final s = _inv('s', 5000,
      kind: InvoiceKind.settlement, settles: [_src('a', 3000), _src('b', 2000)]);

  test('the settlement leaves the view; an exact payment letters every '
      'source in full, tagged with the settlement number', () {
    final view = accountingView([a, b, s], {'s': _match('s', 5000)});
    expect(view.invoices.map((i) => i.id), ['a', 'b']);
    expect(view.matches.keys.toSet(), {'a', 'b'});
    expect(view.matches['a']!.paidCents, 3000);
    expect(view.matches['a']!.resolution, 'exact');
    expect(view.matches['b']!.paidCents, 2000);
    expect(view.matches['a']!.note, contains('via S'));
  });

  test('a partial payment pays the oldest source first and leaves the '
      'rest as a partial or open', () {
    final view = accountingView(
        [a, b, s], {'s': _match('s', 4000, resolution: 'under_accepted')});
    expect(view.matches['a']!.paidCents, 3000);
    expect(view.matches['a']!.resolution, 'exact');
    expect(view.matches['b']!.paidCents, 1000);
    expect(view.matches['b']!.resolution, 'under_accepted');
    final less = accountingView(
        [a, b, s], {'s': _match('s', 2500, resolution: 'under_accepted')});
    expect(less.matches['a']!.paidCents, 2500);
    expect(less.matches['a']!.resolution, 'under_accepted');
    expect(less.matches.containsKey('b'), isFalse);
  });

  test('a pending match allocates nothing; an unpaid or voided settlement '
      'leaves its sources open', () {
    expect(accountingView([a, b, s], {'s': _match('s', 5000, status: 'pending')})
        .matches, isEmpty);
    expect(accountingView([a, b, s], {}).matches, isEmpty);
    final voided = _inv('s', 5000,
        kind: InvoiceKind.settlement,
        settles: [_src('a', 3000)],
        voidedAt: DateTime.utc(2026, 9, 2));
    expect(accountingView([a, voided], {'s': _match('s', 5000)}).matches,
        isEmpty);
  });

  test('a source seen through its settlement reads paid once the settlement '
      'is', () {
    expect(effectiveMatchOf(a, s, null), isNull);
    expect(effectiveMatchOf(a, s, _match('s', 5000))!.paidCents, 3000);
    expect(effectiveMatchOf(b, s, _match('s', 3000, resolution: 'under_accepted')),
        isNull);
  });

  test('the FEC receives the sources with the allocated payment and never '
      'the settlement document', () async {
    final money = FakeMoneyRepository();
    final x = await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-01');
    final y = await money.createInvoice(
        workspaceId: 'ws-1', memberId: 'member-1', period: '2026-02');
    final sid = await money.settleInvoices(
        workspaceId: 'ws-1', memberId: 'member-1', invoiceIds: [x, y]);
    final settlement = money.invoices.firstWhere((i) => i.id == sid);
    await money.matchInvoice(
      invoiceId: sid,
      paymentLedgerId: money.seedPayment('member-1', settlement.totalCents,
          period: '2026-01'),
      resolution: 'exact',
    );
    final view = accountingView(money.invoices, money.invoiceMatchesStore);
    expect(view.invoices.any((i) => i.kind == InvoiceKind.settlement), isFalse);
    expect(view.matches.keys.toSet(), {x, y});
    final fec = buildFecFile(
      invoices: view.invoices,
      matches: view.matches,
      company: const InvoiceParty(name: 'ws'),
      accounts: const FecAccounts(),
      lineText: (l) => l.label,
    );
    expect(fec, isNot(contains(settlement.number)));
    for (final id in [x, y]) {
      final number = money.invoices.firstWhere((i) => i.id == id).number;
      expect(fec, contains(number));
    }
  });
}
