// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4350 -- what the stock needs from the services of the business to create a NEW item from the Stock
// page: the VAT rates a new service may be taxed at. The stock never imports the money feature: the app
// wires this port (lib/app), and whether it is wired says whether a new item may be made here. The item
// itself is one stock command (#4402, `StockConfigCommands.createItem`) that makes its service on the server.

/// A VAT rate a new service may take: its id, and the owner's word for it.
typedef StockVatChoice = ({String id, String label});

abstract interface class StockServiceCreator {
  /// The active VAT rates of the business, the default first.
  Future<List<StockVatChoice>> vatChoices(String workspaceId);
}
