// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4163 -- who bought, for the French e-reporting, from the FROZEN facts of
// the issued document: the capacity the customer stated at issue
// (`legal_snapshot.buyer_capacity`, with its source) and the country the
// document froze. A missing VAT identifier never decides: a micro business
// is a taxable person that may have none. A mutable profile, a company name
// or the current business kind never rewrite the classification.
//
// Evidence that is missing or contradicts itself is a typed unresolved
// outcome, never a fallback: a legacy invoice without a frozen capacity is
// not silently assigned business or consumer.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

/// Who bought, as e-reporting sorts it.
enum FrBuyerKind {
  /// A private person, in the reporting country or abroad: reported per day,
  /// aggregated.
  b2c,

  /// A business abroad: reported per invoice, with its VAT identifier.
  b2bInternational,

  /// A business of the reporting country: its e-invoice reports it.
  b2bDomestic,
}

/// Why a document cannot be sorted.
enum FrUnresolvedReason {
  /// The invoice carries no frozen legal snapshot (issued before it).
  noFrozenCapacity('no_frozen_capacity'),

  /// The snapshot did not state whether the customer is a business or a
  /// consumer.
  capacityUnknown('capacity_unknown'),

  /// A business whose country was frozen nowhere.
  buyerCountryMissing('buyer_country_missing'),

  /// The snapshot and the buyer party froze different countries.
  buyerCountryConflict('buyer_country_conflict'),

  /// A business abroad without the VAT identifier its line must carry.
  buyerVatIdMissing('buyer_vat_id_missing'),

  /// #4163 checkpoint 2 -- a commercial line this reader cannot interpret.
  unsupportedCommercialLine('unsupported_commercial_line'),

  /// A goods line at a zero rate: no category is inferred from the rate.
  goodsZeroRateUnsupported('goods_zero_rate_unsupported'),

  /// Goods delivered to a business abroad: not a supported treatment.
  goodsAbroadUnsupported('goods_abroad_unsupported'),

  /// A mixed goods/services document with money in the period: no
  /// authoritative line allocation of the receipt.
  missingReceiptAllocation('missing_receipt_allocation'),

  /// A service whose frozen tax is not what its rate says, with money in the
  /// period: the payment data cannot follow the invoice.
  amountRuleUnsupported('amount_rule_unsupported');

  const FrUnresolvedReason(this.code);

  /// The stable code shown and logged.
  final String code;
}

/// The outcome of sorting one invoice: a [kind], or the [reasons] it has
/// none. Exactly one of the two.
class FrBuyerClass {
  const FrBuyerClass.resolved(FrBuyerKind this.kind) : reasons = const [];
  const FrBuyerClass.unresolved(this.reasons) : kind = null;

  final FrBuyerKind? kind;
  final List<FrUnresolvedReason> reasons;
}

/// An in-scope document the report could not sort.
class FrUnresolved {
  const FrUnresolved({
    required this.invoiceId,
    required this.number,
    required this.reasons,
  });

  final String invoiceId;
  final String number;
  final List<FrUnresolvedReason> reasons;
}

/// Sorts [invoice] for a seller reporting from [homeCountry], from what the
/// document froze.
FrBuyerClass classifyFrBuyer(Invoice invoice, String homeCountry) {
  final frozen = invoice.legalClauses;
  if (frozen == null) {
    return const FrBuyerClass.unresolved([FrUnresolvedReason.noFrozenCapacity]);
  }
  if (frozen.buyerCapacity == CustomerCapacity.unknown) {
    return const FrBuyerClass.unresolved([FrUnresolvedReason.capacityUnknown]);
  }
  final snapshotCountry = frozen.buyerCountry.trim().toUpperCase();
  final partyCountry = (invoice.buyerParty?.country ?? '').trim().toUpperCase();
  if (snapshotCountry.isNotEmpty &&
      partyCountry.isNotEmpty &&
      snapshotCountry != partyCountry) {
    return const FrBuyerClass.unresolved([
      FrUnresolvedReason.buyerCountryConflict,
    ]);
  }
  if (frozen.buyerCapacity == CustomerCapacity.consumer) {
    // A stray VAT-like value on a consumer does not make a business.
    return const FrBuyerClass.resolved(FrBuyerKind.b2c);
  }
  final country = snapshotCountry.isNotEmpty ? snapshotCountry : partyCountry;
  if (country.isEmpty) {
    return const FrBuyerClass.unresolved([
      FrUnresolvedReason.buyerCountryMissing,
    ]);
  }
  if (country == homeCountry.toUpperCase()) {
    return const FrBuyerClass.resolved(FrBuyerKind.b2bDomestic);
  }
  if ((invoice.buyerParty?.vatId ?? '').trim().isEmpty) {
    return const FrBuyerClass.unresolved([
      FrUnresolvedReason.buyerVatIdMissing,
    ]);
  }
  return const FrBuyerClass.resolved(FrBuyerKind.b2bInternational);
}
