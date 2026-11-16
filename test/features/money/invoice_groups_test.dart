// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3556 (part 2) — a group names an invoice by the installation that holds
// it, so two installations' equal local ids stay two invoices; it reads what
// it names from the overview now, one total per currency, and names what
// cannot be read without counting it.
import 'package:deskilo/features/money/domain/finance_hosts.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/domain/invoice_groups.dart';
import 'package:flutter_test/flutter_test.dart';

const _home = '11111111-1111-4111-8111-111111111111';
const _lyon = '22222222-2222-4222-8222-222222222222';
const _ws = '33333333-3333-4333-8333-333333333333';
const _zurich = '44444444-4444-4444-8444-444444444444';

FinanceInvoice _invoice(String id, String ws, int total, String currency) =>
    FinanceInvoice(
      timezone: 'Europe/Paris',
      id: id,
      workspaceId: ws,
      workspaceName: ws,
      number: 'N-$id',
      issuedAt: DateTime.utc(2026, 9),
      totalCents: total,
      paidCents: 0,
      currency: currency,
      state: FinanceState.open,
    );

const _lyonHost = FinanceHost(installationId: _lyon, workspaceIds: [_ws]);

void main() {
  group('an invoice\'s reference', () {
    test(
      'the home\'s own invoice names the home; a host\'s names the host',
      () {
        final home = _invoice('i1', 'ws-home', 100, 'EUR');
        final away = _invoice('i2', _ws, 100, 'EUR');
        final overview = FinanceOverview(
          invoices: [home, away],
          hosts: const [
            FinanceHostRead(
              _lyonHost,
              FinanceHostStatus.answered,
              workspaceIds: {_ws},
            ),
          ],
        );
        expect(
          invoiceRefOf(overview, home, homeInstallationId: _home),
          const InvoiceRef('$_home:ws-home', 'i1'),
        );
        expect(
          invoiceRefOf(overview, away, homeInstallationId: _home),
          const InvoiceRef('$_lyon:$_ws', 'i2'),
        );
      },
    );

    test('an invoice whose installation cannot be told has none', () {
      final home = _invoice('i1', 'ws-home', 100, 'EUR');
      final selected = _invoice('i2', 'ws-sel', 100, 'EUR');
      final overview = FinanceOverview(
        invoices: [home, selected],
        answered: const [
          FinanceSourceRead(
            origin: 'https://sel.example',
            workspaceIds: {'ws-sel'},
          ),
        ],
      );
      expect(
        invoiceRefOf(overview, home, homeInstallationId: null),
        isNull,
        reason: 'the home\'s id is not known yet',
      );
      expect(
        invoiceRefOf(overview, selected, homeInstallationId: _home),
        isNull,
        reason: 'read only through the selected workspace\'s origin',
      );
    });
  });

  test('two installations\' equal local ids stay two invoices', () {
    const group = InvoiceGroup(
      id: 'g',
      name: 'To reimburse',
      items: [InvoiceGroupItem(InvoiceRef('$_zurich:$_ws', 'i1'), 'Z-1')],
    );
    // the overview holds the same local workspace and invoice id, but on Lyon
    final overview = FinanceOverview(
      invoices: [_invoice('i1', _ws, 500, 'EUR')],
      hosts: const [
        FinanceHostRead(
          _lyonHost,
          FinanceHostStatus.answered,
          workspaceIds: {_ws},
        ),
      ],
    );
    final view = invoiceGroupView(group, overview, homeInstallationId: _home);
    expect(view.invoices, isEmpty, reason: 'Lyon\'s i1 is not Zurich\'s i1');
    expect(view.unreadable.single.number, 'Z-1');
  });

  test('a group reads what it names now: one total per currency, by code, '
      'and what cannot be read is named and left out', () {
    final eur1 = _invoice('a', 'ws-a', 12000, 'EUR');
    final chf = _invoice('b', 'ws-b', 8400, 'chf');
    final eur2 = _invoice('c', 'ws-c', 3000, 'EUR');
    const group = InvoiceGroup(
      id: 'g',
      name: 'Taxes 2026',
      items: [
        InvoiceGroupItem(InvoiceRef('$_home:ws-b', 'b'), 'N-b'),
        InvoiceGroupItem(InvoiceRef('$_home:ws-a', 'a'), 'N-a'),
        InvoiceGroupItem(InvoiceRef('$_home:ws-gone', 'x'), 'F-OLD-9'),
        InvoiceGroupItem(InvoiceRef('$_home:ws-c', 'c'), 'N-c'),
      ],
    );
    final view = invoiceGroupView(
      group,
      FinanceOverview(invoices: [eur1, chf, eur2]),
      homeInstallationId: _home,
    );
    expect(view.count, 4);
    expect(view.totals, [('CHF', 8400), ('EUR', 15000)]);
    expect(view.unreadable.map((i) => i.number), ['F-OLD-9']);
    expect(view.shows(eur1), isTrue);
    expect(
      view.shows(_invoice('a', 'ws-other', 1, 'EUR')),
      isFalse,
      reason: 'an invoice is its workspace and its id',
    );
  });

  test('a group\'s name is trimmed and 1 to 80 characters', () {
    expect(invoiceGroupName('  Taxes 2026 ').name, 'Taxes 2026');
    expect(invoiceGroupName('   ').refusal, InvoiceGroupRefusal.nameShape);
    expect(invoiceGroupName('x' * 81).refusal, InvoiceGroupRefusal.nameShape);
    expect(invoiceGroupName('x' * 80).name, hasLength(80));
  });
}
