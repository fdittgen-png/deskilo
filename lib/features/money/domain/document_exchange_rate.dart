// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The exchange rate recorded with a purchase document in another currency
// than the space's: how many units of the space's currency one unit of the
// document's is worth, on which day, and where the figure came from (a
// source from the reference list `exchange_rate_sources`). The books, the
// FEC and every other posted export read the document at this rate; a
// document without one is refused, named. Pure Dart.
import '../../../core/data/json_reader.dart';
import '../../../core/time/date_text.dart';
import 'accounting_amount.dart';

/// The most decimals a rate may carry (the server stores the same scale).
const int _scale = 10;

/// Why a typed rate is not one.
enum ExchangeRateEntryError { notANumber, notPositive, tooPrecise }

/// [text] as a rate (a decimal point or a comma), or why it is not one.
({ExactDecimal? rate, ExchangeRateEntryError? error}) parseExchangeRate(
  String text,
) {
  final s = text.trim().replaceAll(',', '.');
  if (!RegExp(r'^\d+(\.\d+)?$').hasMatch(s)) {
    return (rate: null, error: ExchangeRateEntryError.notANumber);
  }
  final rate = ExactDecimal.parse(s);
  if (rate.units <= BigInt.zero) {
    return (rate: null, error: ExchangeRateEntryError.notPositive);
  }
  if (rate.scale > _scale) {
    return (rate: null, error: ExchangeRateEntryError.tooPrecise);
  }
  return (rate: rate, error: null);
}

/// What a person enters for a document: the rate, its day and its source.
class ExchangeRateEntry {
  const ExchangeRateEntry({
    required this.rate,
    required this.rateDate,
    required this.source,
  });

  final ExactDecimal rate;
  final DateTime rateDate;

  /// A code of the reference list (`tax_authority`, `bank`, `manual`, …).
  final String source;

  /// What the server takes (`save_purchase_draft_v1`'s `exchange_rate`,
  /// `record_purchase_exchange_rate_v1`).
  Map<String, Object?> toJson() => {
    'rate': rate.toString(),
    'rate_date': isoDay(rateDate),
    'source': source,
  };

  @override
  bool operator ==(Object other) =>
      other is ExchangeRateEntry &&
      other.rate == rate &&
      other.rateDate == rateDate &&
      other.source == source;

  @override
  int get hashCode => Object.hash(rate, rateDate, source);
}

/// The rate recorded with one document, as the server keeps it.
class DocumentExchangeRate {
  const DocumentExchangeRate({
    required this.documentId,
    required this.currency,
    required this.functionalCurrency,
    required this.entry,
    required this.revision,
  });

  /// A row of `document_exchange_rates`.
  factory DocumentExchangeRate.fromRow(Map<String, Object?> row) {
    final r = JsonReader(row, context: 'document_exchange_rates');
    return DocumentExchangeRate(
      documentId: r.string('document_id'),
      currency: r.string('currency'),
      functionalCurrency: r.string('functional_currency'),
      entry: ExchangeRateEntry(
        rate: ExactDecimal.parse(r.string('rate')),
        rateDate: r.dateTime('rate_date'),
        source: r.string('source'),
      ),
      revision: r.integer('revision'),
    );
  }

  final String documentId;

  /// The document's own currency.
  final String currency;

  /// The space's currency, which the books are kept in.
  final String functionalCurrency;
  final ExchangeRateEntry entry;

  /// Raised by every correction while the document awaits its approval.
  final int revision;

  /// The rate the posting rules convert with.
  FxRate get fxRate => FxRate(
    base: currency,
    quote: functionalCurrency,
    rate: entry.rate,
    source: entry.source,
    date: entry.rateDate,
    version: '$revision',
  );
}
