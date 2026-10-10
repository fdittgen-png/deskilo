// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2355 — the VAT TAX POINT: on which day the tax on a supply falls due,
// per country, and for how much. One engine, read by the declaration,
// the VAT report and the FEC/DATEV exports, so the three cannot
// disagree about the same invoice.
//
// A coworking sells services. The law dates the tax on them differently
// in every country the app serves:
//
// | country | the rule by default                                   | option        |
// |---------|-------------------------------------------------------|---------------|
// | FR      | each payment, when received (CGI art. 269-2-c)        | débits        |
// | DE      | end of the month the service is performed (§ 13 UStG), | Ist (§ 20)   |
// |         | an earlier payment when received (Mindest-Ist)        |               |
// | ES      | the service period, prepayments when received (75 LIVA) | criterio de caja |
// | IT      | invoice or payment, whichever comes first (art. 6)    | IVA per cassa |
// | UK      | invoice or payment, whichever comes first (reg. 90)   | cash accounting |
// | CH      | the invoice (vereinbarte Entgelte, art. 39 MWSTG)      | vereinnahmte  |
// | CA      | invoice or payment, whichever comes first (ETA s. 168) | none         |
//
// Everywhere else the invoice date is the rule, with a cash option, which
// is what the app did before.
//
// The result is a list of DATED AMOUNTS per rate: an invoice paid in two
// instalments under a receipts rule falls into two periods, and the two
// parts add up to the invoice to the cent. A credit note follows its OWN
// tax point (its issue, or its refund under a receipts rule) and never
// re-opens the period of the invoice it corrects.
//
// Pure Dart: the CLI and the tests read it, and #2357's SQL
// `compute_vat_return` is meant to be its twin.
import '../../../core/time/workspace_time.dart';
import 'billing_rules.dart';
import 'invoice.dart';
import 'vat_declaration.dart';
import 'vat_rate.dart';

/// How a country dates the tax on a service.
enum VatTaxPointRule {
  /// The day the document is issued.
  invoiceDate,

  /// The day each payment is received; an unpaid part is not due yet.
  receipt,

  /// The last day of the month the service is performed (the invoice's
  /// `period`); a payment received before that day is due when received.
  servicePeriod,

  /// The invoice or the payment, whichever comes first.
  earlierOf,
}

/// The workspace's choice, stored as `invoice_legal.vat_tax_point`.
enum VatTaxPointOption {
  /// The country's legal default.
  standard,

  /// The invoice date, where the law lets a seller opt for it (FR débits).
  invoice,

  /// Cash: each payment when received (Ist, criterio de caja, per cassa,
  /// cash accounting, vereinnahmte Entgelte).
  cash;

  /// Null for anything else — a workspace that never chose.
  static VatTaxPointOption? fromWire(String? raw) =>
      values.asNameMap()[raw ?? ''];
}

/// When an unpaid part falls due anyway under a cash scheme.
enum VatCashBackstop {
  none,

  /// ES — 31 December of the year after the service (art. 163 terdecies
  /// LIVA).
  endOfFollowingYear,

  /// IT — one year after the operation (art. 32-bis D.L. 83/2012).
  oneYearAfterIssue,
}

/// The rule a declaration applies, with its backstop.
class VatTaxPointBasis {
  const VatTaxPointBasis(this.rule, [this.backstop = VatCashBackstop.none]);

  static const invoiceDate = VatTaxPointBasis(VatTaxPointRule.invoiceDate);
  static const receipt = VatTaxPointBasis(VatTaxPointRule.receipt);

  final VatTaxPointRule rule;
  final VatCashBackstop backstop;

  /// Whether the tax waits for the money: the invoice then says so.
  bool get onReceipts => rule == VatTaxPointRule.receipt;

  @override
  bool operator ==(Object other) =>
      other is VatTaxPointBasis &&
      other.rule == rule &&
      other.backstop == backstop;

  @override
  int get hashCode => Object.hash(rule, backstop);
}

/// What one country allows.
class VatTaxPointPolicy {
  const VatTaxPointPolicy(
    this.standard, {
    this.invoiceOption = false,
    this.cashOption = true,
    this.cashBackstop = VatCashBackstop.none,
  });

  final VatTaxPointRule standard;

  /// The seller may opt for the invoice date (FR « option pour les
  /// débits »).
  final bool invoiceOption;

  /// The seller may opt for cash, where that differs from [standard].
  final bool cashOption;
  final VatCashBackstop cashBackstop;

  /// The options a settings screen offers, the default first.
  List<VatTaxPointOption> get options => [
    VatTaxPointOption.standard,
    if (invoiceOption) VatTaxPointOption.invoice,
    if (cashOption) VatTaxPointOption.cash,
  ];

  /// [stored] where this country allows it; the default otherwise — a
  /// stored `cash` in France IS the default, a stored `invoice` in
  /// Germany is the Soll rule.
  VatTaxPointOption effective(VatTaxPointOption? stored) => switch (stored) {
    VatTaxPointOption.invoice when invoiceOption => VatTaxPointOption.invoice,
    VatTaxPointOption.cash when cashOption => VatTaxPointOption.cash,
    _ => VatTaxPointOption.standard,
  };

  /// The rule [option] stands for here.
  VatTaxPointRule ruleOf(VatTaxPointOption option) => switch (option) {
    VatTaxPointOption.standard => standard,
    VatTaxPointOption.invoice => VatTaxPointRule.invoiceDate,
    VatTaxPointOption.cash => VatTaxPointRule.receipt,
  };

  /// The basis a workspace that stored [stored] declares on.
  VatTaxPointBasis basisOf(VatTaxPointOption? stored) {
    final option = effective(stored);
    return VatTaxPointBasis(
      ruleOf(option),
      option == VatTaxPointOption.cash ? cashBackstop : VatCashBackstop.none,
    );
  }
}

/// The policy of the seller's [country] (ISO 3166-1 alpha-2).
VatTaxPointPolicy vatTaxPointPolicy(String country) => switch (country
    .trim()
    .toUpperCase()) {
  'FR' => const VatTaxPointPolicy(
    VatTaxPointRule.receipt,
    invoiceOption: true,
    cashOption: false,
  ),
  'DE' => const VatTaxPointPolicy(VatTaxPointRule.servicePeriod),
  'ES' => const VatTaxPointPolicy(
    VatTaxPointRule.servicePeriod,
    cashBackstop: VatCashBackstop.endOfFollowingYear,
  ),
  'IT' => const VatTaxPointPolicy(
    VatTaxPointRule.earlierOf,
    cashBackstop: VatCashBackstop.oneYearAfterIssue,
  ),
  'GB' || 'UK' => const VatTaxPointPolicy(VatTaxPointRule.earlierOf),
  'CH' => const VatTaxPointPolicy(VatTaxPointRule.invoiceDate),
  'CA' => const VatTaxPointPolicy(VatTaxPointRule.earlierOf, cashOption: false),
  _ => const VatTaxPointPolicy(VatTaxPointRule.invoiceDate),
};

/// The basis of a seller in [country] whose stored choice is [option].
VatTaxPointBasis vatTaxPointBasis(String country, VatTaxPointOption? option) =>
    vatTaxPointPolicy(country).basisOf(option);

/// Money that settled part of a document — or, on a credit note, the
/// refund paid out. [cents] is positive either way.
class TaxPointPayment {
  const TaxPointPayment(this.on, this.cents);
  final DateTime on;
  final int cents;
}

/// One dated amount of one invoice at one rate.
class VatTaxPointAmount {
  const VatTaxPointAmount({
    required this.invoiceId,
    required this.on,
    required this.percent,
    required this.grossCents,
    required this.netCents,
    required this.vatCents,
  });

  final String invoiceId;

  /// The tax point, a date on the workspace's calendar.
  final DateTime on;
  final double percent;
  final int grossCents;
  final int netCents;
  final int vatCents;

  /// Whether [on] lies in [start]..[end], both inclusive days.
  bool within(DateTime start, DateTime end) =>
      !on.isBefore(DateTime(start.year, start.month, start.day)) &&
      !on.isAfter(DateTime(end.year, end.month, end.day));
}

/// The issue's `taxPointOf(invoice, payments, country, option)`.
List<VatTaxPointAmount> taxPointOf(
  Invoice invoice,
  List<TaxPointPayment> payments, {
  required String country,
  VatTaxPointOption? option,
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) => taxPointsOf(
  invoice,
  payments,
  basis: vatTaxPointBasis(country, option),
  dayOf: dayOf,
);

/// The dated amounts [invoice] declares under [basis], given the
/// [payments] it received (or, for a credit note, the refunds paid).
///
/// A voided document and a settlement declare nothing: the settlement's
/// sources carry the VAT, and their payments arrive through
/// `accountingView`'s allocation.
List<VatTaxPointAmount> taxPointsOf(
  Invoice invoice,
  List<TaxPointPayment> payments, {
  required VatTaxPointBasis basis,
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) {
  if (invoice.isVoided || invoice.kind == InvoiceKind.settlement) {
    return const [];
  }
  final gross = <double, int>{};
  final net = <double, int>{};
  for (final line in invoice.lines) {
    gross[line.vatPercent] = (gross[line.vatPercent] ?? 0) + line.amountCents;
    net[line.vatPercent] =
        (net[line.vatPercent] ?? 0) +
        vatSplit(line.amountCents, line.vatPercent).netCents;
  }
  if (gross.isEmpty) return const [];
  final total = gross.values.fold(0, (s, c) => s + c);
  final issued = dayOf(invoice.issuedAt);
  final portions = total == 0
      // Settled by itself — its credits paid it before it was issued.
      ? [(on: issued, cents: 0)]
      : _portions(invoice, payments, basis, issued, total.abs(), dayOf);
  return _slices(invoice.id, portions, gross, net, total);
}

/// The document's magnitude, cut into dated portions under [basis].
List<({DateTime on, int cents})> _portions(
  Invoice invoice,
  List<TaxPointPayment> payments,
  VatTaxPointBasis basis,
  DateTime issued,
  int magnitude,
  DateTime Function(DateTime) dayOf,
) {
  final paid = [
    for (final p in payments)
      if (p.cents > 0) (on: dayOf(p.on), cents: p.cents),
  ]..sort((a, b) => a.on.compareTo(b.on));
  final out = <({DateTime on, int cents})>[];
  var left = magnitude;
  void put(DateTime on, int cents) {
    if (cents <= 0) return;
    if (out.isNotEmpty && out.last.on == on) {
      out[out.length - 1] = (on: on, cents: out.last.cents + cents);
    } else {
      out.add((on: on, cents: cents));
    }
    left -= cents;
  }

  // A credit note has no service of its own: it is due when issued, or
  // when refunded under a receipts rule — never in the original's period.
  final rule = invoice.isCreditNote && basis.rule != VatTaxPointRule.receipt
      ? VatTaxPointRule.invoiceDate
      : basis.rule;
  switch (rule) {
    case VatTaxPointRule.invoiceDate:
      put(issued, left);
    case VatTaxPointRule.receipt:
      final backstop = invoice.isCreditNote
          ? null
          : _backstop(basis.backstop, invoice, issued);
      for (final p in paid) {
        final on = backstop != null && p.on.isAfter(backstop) ? backstop : p.on;
        put(on, p.cents < left ? p.cents : left);
      }
      if (backstop != null) put(backstop, left);
    case VatTaxPointRule.servicePeriod:
      final end = _serviceEnd(invoice.period) ?? issued;
      for (final p in paid) {
        if (!p.on.isBefore(end)) break;
        put(p.on, p.cents < left ? p.cents : left);
      }
      put(end, left);
    case VatTaxPointRule.earlierOf:
      for (final p in paid) {
        if (!p.on.isBefore(issued)) break;
        put(p.on, p.cents < left ? p.cents : left);
      }
      put(issued, left);
  }
  return out;
}

/// The last day of a `YYYY-MM` service period; null when there is none.
DateTime? _serviceEnd(String? period) {
  final match = RegExp(r'^(\d{4})-(\d{2})').firstMatch(period ?? '');
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  if (month < 1 || month > 12) return null;
  return DateTime(year, month + 1, 0);
}

DateTime? _backstop(
  VatCashBackstop backstop,
  Invoice invoice,
  DateTime issued,
) => switch (backstop) {
  VatCashBackstop.none => null,
  VatCashBackstop.endOfFollowingYear => DateTime(
    (_serviceEnd(invoice.period) ?? issued).year + 1,
    12,
    31,
  ),
  VatCashBackstop.oneYearAfterIssue => DateTime(
    issued.year + 1,
    issued.month,
    issued.day,
  ),
};

/// Spreads each portion over the rates in proportion to their weight in
/// the document, CUMULATIVELY: the share of a rate after k portions is
/// computed from everything received so far, so the parts of a fully
/// settled document add up to its per-line arithmetic exactly — the
/// declaration matches the issued document to the cent, however many
/// instalments paid it. The rounding remainder of each step goes to the
/// widest rate.
List<VatTaxPointAmount> _slices(
  String invoiceId,
  List<({DateTime on, int cents})> portions,
  Map<double, int> gross,
  Map<double, int> net,
  int total,
) {
  final magnitude = total.abs();
  final rates = gross.keys.toList()..sort((a, b) => b.compareTo(a));
  final widest = rates.reduce(
    (a, b) => gross[a]!.abs() >= gross[b]!.abs() ? a : b,
  );
  final prevGross = {for (final r in rates) r: 0};
  final prevNet = {for (final r in rates) r: 0};
  final out = <VatTaxPointAmount>[];
  var received = 0;
  for (final portion in portions) {
    received += portion.cents;
    final complete = magnitude == 0 || received >= magnitude;
    final cumGross = <double, int>{};
    if (complete) {
      cumGross.addAll(gross);
    } else {
      var placed = 0;
      for (final r in rates) {
        cumGross[r] = (gross[r]! * received / magnitude).round();
        placed += cumGross[r]!;
      }
      final target = (total * received / magnitude).round();
      cumGross[widest] = cumGross[widest]! + (target - placed);
    }
    for (final r in rates) {
      final cumNet = complete ? net[r]! : vatSplit(cumGross[r]!, r).netCents;
      final g = cumGross[r]! - prevGross[r]!;
      final n = cumNet - prevNet[r]!;
      prevGross[r] = cumGross[r]!;
      prevNet[r] = cumNet;
      if (g == 0 && n == 0) continue;
      out.add(
        VatTaxPointAmount(
          invoiceId: invoiceId,
          on: portion.on,
          percent: r,
          grossCents: g,
          netCents: n,
          vatCents: g - n,
        ),
      );
    }
  }
  return out;
}

/// The payments behind each invoice: the instalments recorded one by one
/// (`invoice_match_payments`, 0101) when there are any, the aggregate
/// match otherwise (a settlement's allocation, a refund, an older row).
/// A match still awaiting validation pays nothing yet — the exports make
/// the same exclusion — and the instalments never count for more than
/// the confirmed aggregate.
List<TaxPointPayment> paymentsOf(
  InvoiceMatch? match,
  List<TaxPointPayment> instalments,
) {
  if (match == null || match.pending) return const [];
  if (instalments.isEmpty) {
    return [TaxPointPayment(match.matchedAt, match.paidCents)];
  }
  final sorted = [...instalments]..sort((a, b) => a.on.compareTo(b.on));
  final out = <TaxPointPayment>[];
  var left = match.paidCents;
  for (final p in sorted) {
    if (left <= 0) break;
    final take = p.cents < left ? p.cents : left;
    out.add(TaxPointPayment(p.on, take));
    left -= take;
  }
  return out;
}

/// Every invoice's tax points — what the declaration, the VAT report and
/// the exports all read. [invoices] and [matches] are the accounting
/// view's (`accountingView`).
List<VatTaxPointAmount> vatTaxPointLedger(
  Iterable<Invoice> invoices, {
  Map<String, InvoiceMatch> matches = const {},
  Map<String, List<TaxPointPayment>> instalments = const {},
  VatTaxPointBasis basis = VatTaxPointBasis.invoiceDate,
  DateTime Function(DateTime instant) dayOf = WorkspaceTime.dateOf,
}) => [
  for (final invoice in invoices)
    ...taxPointsOf(
      invoice,
      paymentsOf(matches[invoice.id], instalments[invoice.id] ?? const []),
      basis: basis,
      dayOf: dayOf,
    ),
];

/// The declaration lines of [start]..[end]: the tax points inside the
/// period, summed per rate, with the documents behind each rate.
List<VatDeclarationLine> vatDeclarationLinesOf(
  Iterable<VatTaxPointAmount> amounts,
  DateTime start,
  DateTime end,
) {
  final gross = <double, int>{};
  final net = <double, int>{};
  final count = <double, Set<String>>{};
  for (final a in amounts) {
    if (!a.within(start, end)) continue;
    gross[a.percent] = (gross[a.percent] ?? 0) + a.grossCents;
    net[a.percent] = (net[a.percent] ?? 0) + a.netCents;
    count.putIfAbsent(a.percent, () => <String>{}).add(a.invoiceId);
  }
  final percents = gross.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final p in percents)
      VatDeclarationLine(
        percent: p,
        grossCents: gross[p]!,
        netCents: net[p]!,
        vatCents: gross[p]! - net[p]!,
        invoiceCount: count[p]!.length,
      ),
  ];
}

/// The ledger by invoice, as the exports read it (#2355): the FEC moves
/// VAT to the collected account per tax point day, DATEV dates each part
/// of a sale in field 116.
class VatTaxPointIndex {
  VatTaxPointIndex(Iterable<VatTaxPointAmount> amounts) {
    for (final a in amounts) {
      _byInvoice.putIfAbsent(a.invoiceId, () => []).add(a);
    }
  }

  final _byInvoice = <String, List<VatTaxPointAmount>>{};

  /// [invoiceId]'s amounts summed per tax point day by [of], in date
  /// order; empty when nothing of it is due yet.
  Map<DateTime, int> byDay(
    String invoiceId,
    int Function(VatTaxPointAmount amount) of,
  ) {
    final days = <DateTime, int>{};
    for (final a in _byInvoice[invoiceId] ?? const <VatTaxPointAmount>[]) {
      days[a.on] = (days[a.on] ?? 0) + of(a);
    }
    final ordered = days.keys.toList()..sort();
    return {for (final day in ordered) day: days[day]!};
  }

  /// Whether the [booked] VAT of [invoiceId] is NOT exactly due on
  /// [issued] — and so waits on a pending account until its tax points.
  bool vatAwayFrom(String invoiceId, DateTime issued, int booked) {
    final days = byDay(invoiceId, (a) => a.vatCents)
      ..removeWhere((_, vat) => vat == 0);
    return days.keys.any((day) => day != issued) ||
        (days[issued] ?? 0) != booked;
  }
}
