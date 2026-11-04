// SPDX-License-Identifier: AGPL-3.0-or-later
// Synthetic monthly invoices and matched payments for city demos.
import '../../../features/money/domain/invoice.dart';
import '../../../features/money/domain/invoice_pdf_template.dart';
import '../../../features/money/domain/ledger_entry.dart';
import '../../../features/money/domain/service_item.dart';
import '../../../features/money/domain/vat_rate.dart';
import '../../../features/reservations/domain/reservation.dart';
import '../../../features/workspace/domain/member.dart';
import '../../time/date_text.dart';
import '../data/money_repository.dart';
import '../data/workspace_repository.dart';

typedef CityMoneySpec = ({
  String workspaceId,
  String prefix,
  String name,
  String currency,
  DateTime now,
  int years,
  List<Reservation> hourlyBookings,
  double vatPercent,
  List<({String siteId, String memberId, DateTime month})> siteRentals,
});

void seedCityMoney(
  FakeMoneyRepository money,
  FakeWorkspaceRepository workspace,
  CityMoneySpec spec,
) => _CityMoney(money, workspace, spec).seed();

class _CityMoney {
  _CityMoney(this.money, this.workspace, this.spec);
  final FakeMoneyRepository money;
  final FakeWorkspaceRepository workspace;
  final CityMoneySpec spec;
  static const catalogue = <(String, int, bool)>[
    ('Coffee', 250, true),
    ('Tea', 200, true),
    ('Bottled water', 150, true),
    ('Sweets and snacks', 200, true),
    ('Beer', 400, true),
    ('Black and white pages', 15, false),
    ('Colour pages', 50, false),
    ('Copies', 20, false),
    ('3D print jobs', 500, false),
  ];

  void seed() {
    final workspaceId = spec.workspaceId, prefix = spec.prefix;
    final now = spec.now;
    final years = spec.years;
    final hourlyBookings = spec.hourlyBookings;
    money.services
      ..clear()
      ..addAll([
        for (final (index, item) in catalogue.indexed)
          ServiceItem(
            id: '$prefix-service-$index',
            workspaceId: workspaceId,
            name: item.$1,
            priceCents: item.$2,
            active: true,
            stock: item.$3 ? 50 : null,
          ),
      ]);
    final members = [workspace.myMember, ...workspace.otherMembers];
    final hours = <(String, String), int>{};
    for (final booking in hourlyBookings) {
      final period = yearMonth(booking.startsAt.year, booking.startsAt.month);
      final key = (booking.memberId, period);
      final minutes = booking.endsAt.difference(booking.startsAt).inMinutes;
      hours[key] = (hours[key] ?? 0) + (minutes + 59) ~/ 60;
    }
    final stop = DateTime(now.year, now.month);
    var month = DateTime(now.year - years, now.month);
    while (month.isBefore(stop)) {
      for (final (index, member) in members.indexed) {
        _member(month, index, member, hours);
      }
      month = DateTime(month.year, month.month + 1);
    }
    _template();
  }

  void _member(
    DateTime month,
    int index,
    Member member,
    Map<(String, String), int> hours,
  ) {
    final workspaceId = spec.workspaceId, prefix = spec.prefix;
    final name = spec.name, currency = spec.currency;
    final vatPercent = spec.vatPercent;
    final siteRentals = spec.siteRentals;
    final period = yearMonth(month.year, month.month);
    final id = '$prefix-invoice-$period-$index';
    final charge = member.subscriptionPct < 100 ? 18000 : 36000;
    final quantities = [
      (index + month.month) % 5,
      (index + month.month) % 3,
      (index * 2 + month.month) % 6,
      (index + month.month) % 4,
      (index + month.month) % 3,
      (index * 3 + month.month) % 25,
      (index + month.month) % 8,
      (index + month.month) % 6,
      (index + month.month) % 2,
    ];
    final sales = [
      for (final (i, item) in catalogue.indexed)
        (item.$1, quantities[i], item.$2),
    ];
    final supplies = sales.fold<int>(0, (sum, item) => sum + item.$2 * item.$3);
    final bookedHours = hours[(member.id, period)] ?? 0;
    final usage = bookedHours * 800;
    final rentals = siteRentals
        .where(
          (r) =>
              r.memberId == member.id &&
              r.month.year == month.year &&
              r.month.month == month.month,
        )
        .toList();
    final amount = charge + supplies + usage + rentals.length * 500000;
    // Snapshots must add the VAT rounded for each printed line, just as
    // the return engine does, rather than rounding the invoice as one line.
    final net = <int>[
      charge,
      if (bookedHours > 0) usage,
      for (final _ in rentals) 500000,
      for (final (_, quantity, unit) in sales)
        if (quantity > 0) quantity * unit,
    ].fold<int>(0, (sum, gross) => sum + vatSplit(gross, vatPercent).netCents);
    // The month has finished before its actual usage can be invoiced.
    final issued = DateTime(month.year, month.month + 1, 0);
    final paid = issued.add(const Duration(days: 5));
    final paymentId = '$id-payment';
    money.invoices.add(
      Invoice(
        id: id,
        workspaceId: workspaceId,
        memberId: member.id,
        number: '${prefix.toUpperCase()}-$period-$index',
        issuedAt: issued,
        period: period,
        title: 'Coworking · $period',
        lines: [
          InvoiceLine(
            label: 'Workspace membership',
            amountCents: charge,
            vatPercent: vatPercent,
          ),
          if (bookedHours > 0)
            InvoiceLine(
              label: 'Workspace use · $bookedHours hours at \$8/hour',
              quantity: bookedHours,
              amountCents: usage,
              vatPercent: vatPercent,
            ),
          for (final rental in rentals)
            InvoiceLine(
              label:
                  'Exclusive monthly hire · ${workspace.sites.where((s) => s.id == rental.siteId).firstOrNull?.name ?? rental.siteId}',
              amountCents: 500000,
              vatPercent: vatPercent,
            ),
          for (final (label, quantity, unit) in sales)
            if (quantity > 0)
              InvoiceLine(
                label: label,
                quantity: quantity,
                amountCents: quantity * unit,
                vatPercent: vatPercent,
              ),
        ],
        totalCents: amount,
        vatTotals: vatPercent > 0
            ? [
                InvoiceVatTotal(
                  percent: vatPercent,
                  category: 'S',
                  grossCents: amount,
                  netCents: net,
                  vatCents: amount - net,
                ),
              ]
            // #3294 — a sales-tax-free invoice freezes its zero rate too.
            : [
                InvoiceVatTotal(
                  percent: 0,
                  category: 'O',
                  grossCents: amount,
                  netCents: amount,
                  vatCents: 0,
                ),
              ],
        currency: currency,
        memberName: workspace.memberNames[member.id] ?? 'Demo member',
        memberAddress: currency == 'GBP'
            ? 'Example Street, London'
            : 'Example Avenue, New York',
        workspaceName: name,
        workspaceAddress: workspace.workspaces
            .firstWhere((w) => w.id == workspaceId)
            .address,
        issuerName: name,
        signature: 'demo',
        dueOn: issued.add(const Duration(days: 14)),
      ),
    );
    _payments((
      id: id,
      memberId: member.id,
      period: period,
      charge: charge,
      extra: supplies + usage + rentals.length * 500000,
      amount: amount,
      issued: issued,
      paid: paid,
      paymentId: paymentId,
    ));
  }

  void _payments(
    ({
      String id,
      String memberId,
      String period,
      int charge,
      int extra,
      int amount,
      DateTime issued,
      DateTime paid,
      String paymentId,
    })
    values,
  ) {
    final (
      :id,
      :memberId,
      :period,
      :charge,
      :extra,
      :amount,
      :issued,
      :paid,
      :paymentId,
    ) = values;
    money.ledger.add(
      LedgerEntry(
        id: '$id-charge',
        memberId: memberId,
        kind: LedgerKind.charge,
        category: LedgerCategory.subscription,
        amountCents: charge,
        description: 'Workspace membership',
        period: period,
        createdAt: issued,
      ),
    );
    if (extra > 0) {
      money.ledger.add(
        LedgerEntry(
          id: '$id-services',
          memberId: memberId,
          kind: LedgerKind.charge,
          category: LedgerCategory.service,
          amountCents: extra,
          description: 'Workspace use and services',
          period: period,
          createdAt: issued,
        ),
      );
    }
    // A future transfer cannot settle an invoice in the current Demo.
    final overdueMonth = DateTime(spec.now.year, spec.now.month - 2);
    final overdue = memberId == 'member-2' &&
        period == yearMonth(overdueMonth.year, overdueMonth.month);
    if (overdue) {
      money.invoiceReminders[id] = [issued.add(const Duration(days: 20))];
    }
    if (paid.isAfter(spec.now) || overdue) return;
    money.ledger.add(
      LedgerEntry(
        id: paymentId,
        memberId: memberId,
        kind: LedgerKind.credit,
        category: LedgerCategory.payment,
        amountCents: amount,
        description: 'Demo bank transfer',
        period: period,
        createdAt: paid,
        occurredOn: paid,
      ),
    );
    money.consumedPaymentIds.add(paymentId);
    money.invoiceMatchesStore[id] = InvoiceMatch(
      invoiceId: id,
      paidCents: amount,
      resolution: 'exact',
      paymentLedgerId: paymentId,
      matchedAt: paid,
      byName: 'Demo accounts',
    );
  }

  void _template() {
    final name = spec.name;
    money.pdfTemplate = InvoicePdfTemplate(
      header:
          '''
:::
$name
> WORK · CONNECT · CREATE
|||
INVOICE · {{ number }}
> Issued {{ issued }}
:::
---
:::
{{ workspace }}
> {{ workspace_address }}
|||
Billed to
{{ member }}
> {{ client_address }}
:::''',
      footer: '$name · Thank you for being part of our community.',
      statement: ReportBands(
        header: '$name · Account statement',
        footer: 'Payments and balances shown are demonstration data.',
      ),
      extraDocs: {
        'payments': ReportBands(
          header: '$name · Payment report',
          footer: 'Thank you for your payment.',
        ),
      },
    );
  }
}
