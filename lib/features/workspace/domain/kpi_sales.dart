// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3294 step 3 — the sales side of the figures, on the KPI contract
// (#1918): what the space sells, by kind of line and by service, and the
// margin each room it rents leaves. The SERVER computes them
// (`kpi_sales_quality`, 0674) from the issued invoices' lines and the
// charges of the rented rooms; this layer names what it returns.
//
//   * sales are net of VAT, the gross beside them; credits on an invoice
//     (payments, reimbursements) are not sales; a credit note subtracts;
//   * a room's margin is what its bookings were charged minus the room's
//     own cost (its rent falling due, or its cost per use); no other cost
//     is allocated to it, so it is a margin, never a profit;
//   * amounts are minor units of the workspace currency; another currency
//     in scope leaves them unknown (`currency_mix`), never summed.
//
// A product's margin needs items on purchase lines and a cost price for
// services: a later step of #3294.
//
// Pure Dart: no Flutter, no l10n.
library;

import '../../../core/data/json_reader.dart';
import 'kpi_contract.dart';

const _revenueByKindKpi = KpiDefinition(
  id: 'sales.revenue_by_kind',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the invoices of whole months [from, to]: their sales lines net of '
      'VAT by the kind of line, a credit note subtracted, credits left out',
  dateBasis: KpiDateBasis.invoiceMonth,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'net_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['invoicing', 'the workspace currency'],
  minCohort: null,
);

const _revenueByServiceKpi = KpiDefinition(
  id: 'sales.revenue_by_service',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the invoices of whole months [from, to]: their service and package '
      'lines net of VAT, by the catalogue description',
  dateBasis: KpiDateBasis.invoiceMonth,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'net_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['invoicing', 'services', 'the workspace currency'],
  minCohort: null,
);

const _roomMarginKpi = KpiDefinition(
  id: 'sales.room_margin',
  version: 1,
  unit: 'currency_minor',
  timeBasis:
      'the billing months [from, to]: what the bookings of each rented room '
      'were charged, net, minus the room\'s rent falling due or its cost '
      'per use',
  dateBasis: KpiDateBasis.invoiceMonth,
  coverage: KpiCoverage.currentRecords,
  dimensions: [],
  numerator: 'margin_minor',
  denominator: '',
  aggregation: KpiAggregation.sum,
  permissions: ['viewAnalytics', 'viewFinances'],
  disclosure: KpiDisclosure.financial,
  prerequisites: ['rented rooms', 'room fees', 'the workspace currency'],
  minCohort: null,
);

/// The sales figures, in catalogue order.
const salesKpis = <KpiDefinition>[
  _revenueByKindKpi,
  _revenueByServiceKpi,
  _roomMarginKpi,
];

/// One kind of invoice line in the months: its lines, net and gross.
typedef SalesKind = ({String kind, int lines, int? netMinor, int? grossMinor});

/// One month's sales.
typedef SalesMonth = ({String month, int? netMinor, int? grossMinor});

/// One service or package by its description, by rank.
typedef ServiceSales = ({
  int rank,
  String name,
  String kind,
  int lines,
  int? netMinor,
  int? grossMinor,
});

/// One rented room: its uses, what they were charged, its own cost and
/// the margin left.
typedef RoomMargin = ({
  String officeId,
  String name,
  String costKind,
  int uses,
  int? chargesMinor,
  int? costMinor,
  int? marginMinor,
});

/// The rented rooms together.
class RoomMargins {
  const RoomMargins({
    required this.rooms,
    required this.uses,
    required this.chargesMinor,
    required this.costMinor,
    required this.marginMinor,
    required this.rows,
  });

  final int rooms;
  final int uses;
  final int? chargesMinor;
  final int? costMinor;
  final int? marginMinor;

  /// The rooms, the largest margin first.
  final List<RoomMargin> rows;
}

/// What `kpi_sales_quality` returned for the whole months
/// [fromMonth, toMonth], typed. A missing amount is null, never 0.
class SalesQualityKpi {
  const SalesQualityKpi({
    required this.fromMonth,
    required this.toMonth,
    required this.currency,
    required this.invoices,
    required this.lines,
    required this.netUnknownLines,
    required this.netMinor,
    required this.grossMinor,
    required this.kinds,
    required this.months,
    required this.serviceCount,
    required this.serviceNetMinor,
    required this.services,
    required this.rooms,
    required this.quality,
    required this.reasons,
    required this.computedAt,
  });

  final String fromMonth;
  final String toMonth;
  final String currency;
  final int invoices;
  final int lines;

  /// Lines without a net or a readable VAT rate: their net is unknown and
  /// left out of every net (`net_unknown`); an explicit 0 % is a rate.
  final int netUnknownLines;
  final int? netMinor;
  final int? grossMinor;

  /// By kind of line, the largest net first.
  final List<SalesKind> kinds;
  final List<SalesMonth> months;

  final int serviceCount;
  final int? serviceNetMinor;

  /// The largest services and packages, the largest first.
  final List<ServiceSales> services;

  /// Null while the space rents no rooms (`externalRooms` off).
  final RoomMargins? rooms;

  final Set<KpiQuality> quality;
  final List<String> reasons;
  final DateTime computedAt;
}

JsonReader _object(JsonReader r, String key) =>
    r.objectOrNull(key) ?? (throw FormatException('Missing $key'));

int _count(JsonReader r, String key) {
  final n = r.integer(key);
  if (n < 0) throw FormatException('Invalid count $key');
  return n;
}

/// Parses the RPC's jsonb. An amount that cannot travel exactly makes the
/// amounts unavailable (`amount_not_exact`), never a rounded number.
SalesQualityKpi salesQualityFromJson(Map<String, Object?> json) {
  final r = JsonReader(json, context: 'kpi_sales_quality');
  var inexact = false;
  // A null amount is unknown on purpose (another currency in scope); only
  // a present value that cannot travel exactly is inexact.
  int? minor(JsonReader row, String key) {
    final raw = row.raw(key);
    final v = exactMinor(raw);
    if (raw != null && v == null) inexact = true;
    return v;
  }

  final revenue = _object(r, 'revenue');
  final kinds = revenue.objects(
    'kinds',
    (row) => (
      kind: row.string('kind'),
      lines: _count(row, 'lines'),
      netMinor: minor(row, 'net_minor'),
      grossMinor: minor(row, 'gross_minor'),
    ),
  );
  final months = revenue.objects(
    'months',
    (row) => (
      month: row.string('month'),
      netMinor: minor(row, 'net_minor'),
      grossMinor: minor(row, 'gross_minor'),
    ),
  );
  final serviceRow = _object(r, 'services');
  final services = serviceRow.objects(
    'rows',
    (row) => (
      rank: _count(row, 'rank'),
      name: row.stringOr('name'),
      kind: row.string('kind'),
      lines: _count(row, 'lines'),
      netMinor: minor(row, 'net_minor'),
      grossMinor: minor(row, 'gross_minor'),
    ),
  );
  final roomRow = r.objectOrNull('rooms');
  final rooms = roomRow == null
      ? null
      : RoomMargins(
          rooms: _count(roomRow, 'rooms'),
          uses: _count(roomRow, 'uses'),
          chargesMinor: minor(roomRow, 'charges_minor'),
          costMinor: minor(roomRow, 'cost_minor'),
          marginMinor: minor(roomRow, 'margin_minor'),
          rows: roomRow.objects(
            'rows',
            (row) => (
              officeId: row.string('office_id'),
              name: row.stringOr('name'),
              costKind: row.stringOr('cost_kind'),
              uses: _count(row, 'uses'),
              chargesMinor: minor(row, 'charges_minor'),
              costMinor: minor(row, 'cost_minor'),
              marginMinor: minor(row, 'margin_minor'),
            ),
          ),
        );
  final netMinor = minor(revenue, 'net_minor');
  final grossMinor = minor(revenue, 'gross_minor');
  final serviceNetMinor = minor(serviceRow, 'net_minor');
  final currency = r.stringOr('currency');
  return SalesQualityKpi(
    fromMonth: r.stringOr('from'),
    toMonth: r.stringOr('to'),
    currency: currency,
    invoices: _count(revenue, 'invoices'),
    lines: _count(revenue, 'lines'),
    netUnknownLines: _count(revenue, 'net_unknown_lines'),
    netMinor: netMinor,
    grossMinor: grossMinor,
    kinds: kinds,
    months: months,
    serviceCount: _count(serviceRow, 'services'),
    serviceNetMinor: serviceNetMinor,
    services: services,
    rooms: rooms,
    quality: {
      for (final q in r.strings('quality'))
        kpiQualityOf(q) ?? KpiQuality.unavailable,
      if (inexact || currency.isEmpty) KpiQuality.unavailable,
    },
    reasons: [...r.strings('reasons'), if (inexact) 'amount_not_exact'],
    computedAt: r.dateTime('computed_at'),
  );
}

/// Reads the sales figures (#3294 step 3). Every call is authorized there.
abstract interface class SalesKpiRepository {
  /// The figures of the whole months [fromMonth, toMonth] (`YYYY-MM`).
  Future<SalesQualityKpi> quality(
    String workspaceId, {
    required String fromMonth,
    required String toMonth,
  });
}
