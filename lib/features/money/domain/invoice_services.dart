// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4510 (FIN-05) -- the services of the business's catalogue a quote or an invoice line may be picked from. Picking one fills the
// line in (its name, its price, its VAT rate, what it supplies) and keeps its identity on the line; what the line holds is
// what was agreed, so a later edit of the catalogue changes no saved line.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// One service of the catalogue, as a line offers it.
class InvoiceService {
  const InvoiceService({
    required this.id,
    required this.name,
    required this.priceCents,
    this.vatRateId,
    this.supply = 'property',
  });

  factory InvoiceService.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'services');
    return InvoiceService(
      id: r.string('id'),
      name: r.stringOr('name'),
      priceCents: r.integer('price_cents'),
      vatRateId: r.stringOrNull('vat_rate_id'),
      supply: r.stringOr('supply_class', 'property') == 'general' ? 'general' : 'property',
    );
  }

  final String id;
  final String name;

  /// The service's price, VAT-inclusive, in minor units.
  final int priceCents;

  /// The VAT rate the service is taxed at; null takes the business's default.
  final String? vatRateId;

  /// What the line supplies for the place of supply: `property` (connected with the premises) or `general`.
  final String supply;
}

/// Reads the services a business has on offer that are not kept in stock.
abstract interface class InvoiceServiceCatalogue {
  Future<List<InvoiceService>> services(String workspaceId);
}
