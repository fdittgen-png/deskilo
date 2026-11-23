// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- what the stock needs from the services of the business to create a NEW item from the Stock
// page: the VAT rates a new service may be taxed at, and the creation of the service itself. The stock
// never imports the money feature: the app wires this port (lib/app), so an item is made as a service
// first and its stock settings second, each by the command that owns it.

/// A VAT rate a new service may take: its id, and the owner's word for it.
typedef StockVatChoice = ({String id, String label});

abstract interface class StockServiceCreator {
  /// The active VAT rates of the business, the default first.
  Future<List<StockVatChoice>> vatChoices(String workspaceId);

  /// Creates the service (a price in minor units, a VAT rate or none) and returns its id.
  Future<String> create(String workspaceId, {required String name, required int priceCents, String? vatRateId, String? requestId});
}
