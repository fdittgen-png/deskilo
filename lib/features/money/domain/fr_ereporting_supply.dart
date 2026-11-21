// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4163 checkpoint 2 -- the transaction category is the SUPPLY (goods or
// services) and the rate separately, from the facts #4162 froze on a
// commercial line, never from the rate alone. A goods line and a service line
// at the same rate stay two lines of the report.
//
// Supported here: the reviewed French domestic capability. A legacy line (no
// `commercial` facts) keeps its service-only reading; a commercial line
// contributes its authoritative frozen net and tax, never a recomputation.
// Everything the engine cannot express yet is refused with a typed reason:
// no category is guessed, no payment is split in proportion, nothing is
// dropped.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart' show TaxReferenceSet;

import 'fr_ereporting_capacity.dart';

/// The transaction category of a taxed supply in the e-reporting flows:
/// TLB1 goods delivered and taxed in France, TPS1 services taxed in France.
const String _goodsCategory = 'TLB1';
const String _serviceCategory = 'TPS1';

/// One day's sale of one supply category at one rate, from frozen amounts.
typedef FrSupplySale = ({
  String category,
  double percent,
  int netCents,
  int vatCents,
});

/// What an invoice's lines say about its supply.
class FrSupply {
  const FrSupply({
    required this.hasGoods,
    required this.hasServices,
    required this.sales,
    required this.reasons,
  });

  /// Whether any commercial line is goods / is a service.
  final bool hasGoods;
  final bool hasServices;

  /// The frozen amounts per category and rate of the commercial lines.
  final List<FrSupplySale> sales;

  /// Why the invoice cannot be reported (supply side only).
  final List<FrUnresolvedReason> reasons;

  bool get mixed => hasGoods && hasServices;
}

/// Reads [invoice]'s lines for the supply distinction. [kind] is how its
/// buyer was sorted; [receiptsInPeriod] whether money for it falls in the
/// reported period (payment data would be owed).
FrSupply _supplyOf(
  Invoice invoice,
  FrBuyerKind kind, {
  required bool receiptsInPeriod,
}) {
  final reasons = <FrUnresolvedReason>[];
  var goods = false;
  var services = false;
  final sums = <(String, double), ({int net, int vat})>{};
  for (final line in invoice.lines) {
    final facts = line.exactFacts;
    if (line.unsupportedFacts != null) {
      reasons.add(FrUnresolvedReason.unsupportedCommercialLine);
      continue;
    }
    if (facts == null) continue; // a legacy line: the service-only reading
    final isGoods = facts.supply == CommercialSupply.goods;
    goods = goods || isGoods;
    services = services || !isGoods;
    if (!isGoods) {
      // The frozen tax of a service must be what the rate says, or the
      // payment data (derived from the rate) would disagree with the invoice.
      final legacy = vatSplit(line.amountCents, line.vatPercent);
      if (facts.amounts.taxMinor != legacy.vatCents && receiptsInPeriod) {
        reasons.add(FrUnresolvedReason.amountRuleUnsupported);
      }
    } else if (line.vatPercent <= 0) {
      // A zero rate alone proves neither an exemption nor an out-of-scope
      // supply: no category is inferred.
      reasons.add(FrUnresolvedReason.goodsZeroRateUnsupported);
      continue;
    }
    final category = isGoods
        ? _goodsCategory
        : (line.vatPercent > 0 ? _serviceCategory : 'TNT1');
    final key = (category, line.vatPercent);
    final seen = sums[key];
    sums[key] = (
      net: (seen?.net ?? 0) + facts.amounts.netMinor,
      vat: (seen?.vat ?? 0) + facts.amounts.taxMinor,
    );
  }
  if (goods && kind != FrBuyerKind.b2c) {
    // A delivery to a business abroad is an intra-EU or export treatment the
    // engine does not express.
    if (kind == FrBuyerKind.b2bInternational) {
      reasons.add(FrUnresolvedReason.goodsAbroadUnsupported);
    }
  }
  if (goods && services && receiptsInPeriod) {
    // The split of a receipt between goods and services needs a confirmed
    // line allocation or a reviewed rule; neither exists yet.
    reasons.add(FrUnresolvedReason.missingReceiptAllocation);
  }
  return FrSupply(
    hasGoods: goods,
    hasServices: services,
    sales: [
      for (final e in sums.entries)
        (
          category: e.key.$1,
          percent: e.key.$2,
          netCents: e.value.net,
          vatCents: e.value.vat,
        ),
    ],
    reasons: reasons.toSet().toList(),
  );
}

/// Whether a document's sale, or the money for it, falls in the reported
/// period.
abstract interface class FrPeriodReach {
  bool sale(Invoice invoice);
  bool receipt(Invoice invoice);
}

/// One reported sale: a day, a supply category and a rate.
typedef FrSaleLine = ({
  String invoiceId,
  DateTime on,
  String category,
  double percent,
  int netCents,
  int vatCents,
});

/// The invoices sorted for a period: how each buyer was sorted, the invoices
/// the report lists ([reportable], domestic businesses left to their
/// e-invoice), the commercial invoices that carry goods ([goods], whose sales
/// come from their frozen lines), and the [unresolved] ones that reach the
/// period.
typedef FrSorted = ({
  Map<String, FrBuyerKind?> classes,
  List<Invoice> reportable,
  Map<String, FrSupply> goods,
  List<Invoice> plain,
  List<FrUnresolved> unresolved,
});

FrSorted sortFrInvoices(
  Iterable<Invoice> invoices,
  String homeCountry,
  FrPeriodReach reach, {
  required bool onReceipts,
}) {
  final classes = <String, FrBuyerKind?>{};
  final reportable = <Invoice>[];
  final goods = <String, FrSupply>{};
  final unresolved = <FrUnresolved>[];
  for (final i in invoices) {
    final sorted = classifyFrBuyer(i, homeCountry);
    final kind = sorted.kind;
    classes[i.id] = kind;
    var reasons = sorted.reasons;
    FrSupply? supply;
    if (kind != null && kind != FrBuyerKind.b2bDomestic) {
      supply = _supplyOf(
        i,
        kind,
        receiptsInPeriod: onReceipts && reach.receipt(i),
      );
      reasons = supply.reasons;
    }
    if (reasons.isNotEmpty) {
      if (reach.sale(i) || (onReceipts && reach.receipt(i))) {
        unresolved.add(
          FrUnresolved(invoiceId: i.id, number: i.number, reasons: reasons),
        );
      }
      continue;
    }
    if (kind == null || kind == FrBuyerKind.b2bDomestic) continue;
    reportable.add(i);
    if (supply!.hasGoods) goods[i.id] = supply;
  }
  return (
    classes: classes,
    reportable: reportable,
    goods: goods,
    plain: [
      for (final i in reportable)
        if (!goods.containsKey(i.id)) i,
    ],
    unresolved: unresolved,
  );
}

/// The sales of the period: the plain (service-only) invoices from the
/// tax-point ledger, the goods-bearing ones from their frozen lines on the
/// invoice day.
List<FrSaleLine> frSales(
  FrSorted sorted,
  Map<String, Invoice> byId, {
  required TaxReferenceSet reference,
  required DateTime Function(DateTime instant) dayOf,
  required DateTime start,
  required DateTime end,
}) {
  final from = DateTime(start.year, start.month, start.day);
  final to = DateTime(end.year, end.month, end.day);
  return [
    for (final a in vatTaxPointLedger(
      sorted.plain,
      reference: reference,
      dayOf: dayOf,
    ).where((a) => a.within(start, end)))
      (
        invoiceId: a.invoiceId,
        on: a.on,
        category: _legacyCategory(a.percent),
        percent: a.percent,
        netCents: a.netCents,
        vatCents: a.vatCents,
      ),
    for (final MapEntry(:key, :value) in sorted.goods.entries)
      for (final s in value.sales)
        if (dayOf(byId[key]!.issuedAt) case final on
            when !on.isBefore(from) && !on.isAfter(to))
          (
            invoiceId: key,
            on: on,
            category: s.category,
            percent: s.percent,
            netCents: s.netCents,
            vatCents: s.vatCents,
          ),
  ];
}

String _legacyCategory(double percent) => percent > 0 ? 'TPS1' : 'TNT1';
