// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4510 -- the services a Demo quote or invoice line may be picked from: the Demo business's own catalogue, the active
// services that are not kept in stock (a stocked item is goods, picked in its own picker).
import 'package:deskilo/features/money/domain/invoice_services.dart';
import 'package:deskilo/features/money/domain/service_item.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

class DemoInvoiceServiceCatalogue implements InvoiceServiceCatalogue {
  DemoInvoiceServiceCatalogue(this._services);

  final Future<List<ServiceItem>> Function(String workspaceId) _services;

  @override
  Future<List<InvoiceService>> services(String workspaceId) async => [
    for (final s in await _services(workspaceId))
      if (s.active && s.stock == null)
        InvoiceService(
          id: s.id,
          name: s.name,
          priceCents: s.priceCents,
          vatRateId: s.vatRateId.isEmpty ? null : s.vatRateId,
          supply: s.supplyClass == SupplyClass.general ? 'general' : 'property',
        ),
  ];
}
