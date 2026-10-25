// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../features/money/domain/purchase.dart';

/// The exchange rates of the demonstration's purchases in another currency,
/// kept as the server keeps them: one per document, corrected while the
/// document awaits its approval, fixed once it is approved.
mixin DemoPurchaseExchangeRates implements PurchaseRepository {
  /// The demo space's currency, which the books are kept in.
  static const spaceCurrency = 'EUR';

  /// The rate sources the demonstration offers (the server reads them from
  /// its reference list).
  static const sources = ['tax_authority', 'bank', 'manual'];

  final Map<String, DocumentExchangeRate> exchangeRates = {};

  @override
  Future<DocumentExchangeRate?> fetchExchangeRate(
    String workspaceId,
    String purchaseId,
  ) async => exchangeRates[purchaseId];

  @override
  Future<DocumentExchangeRate> recordExchangeRate(
    String workspaceId,
    String purchaseId,
    ExchangeRateEntry entry,
  ) async {
    final s = (await fetchDetail(workspaceId, purchaseId)).summary;
    return rememberRate(s, entry);
  }

  /// [entry] recorded for [s], under the server's rules.
  DocumentExchangeRate rememberRate(
    PurchaseSummary s,
    ExchangeRateEntry entry,
  ) {
    if (s.currency.isEmpty || s.currency == spaceCurrency) {
      throw StateError('the purchase is in the currency of the space');
    }
    if (!sources.contains(entry.source)) {
      throw StateError('unknown rate source');
    }
    final held = exchangeRates[s.id];
    if (held != null && s.state == PurchaseState.approved) {
      throw StateError('the rate of an approved purchase is fixed');
    }
    return exchangeRates[s.id] = DocumentExchangeRate(
      documentId: s.id,
      currency: s.currency,
      functionalCurrency: spaceCurrency,
      entry: entry,
      revision: (held?.revision ?? 0) + 1,
    );
  }

  @override
  Future<List<String>> fetchExchangeRateSources() async => sources;
}
