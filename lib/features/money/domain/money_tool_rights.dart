// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3627 — who reaches each money tool, by permission name: the tool's tile
// asks it and its route asks it (test/app/money_tool_rights_test.dart holds
// the two equal). Holding ANY one name opens the tool.
abstract final class MoneyToolRights {
  /// The workspace status: what the server's `workspace_status` itself asks.
  static const Set<String> status = {'viewFinances'};

  /// The guided repartition of shared expenses.
  static const Set<String> repartitionWizard = {
    'issueInvoices',
    'manageBilling',
  };

  /// The suppliers, master data of the expense flows.
  static const Set<String> suppliers = {
    'viewFinances',
    'manageBilling',
    'managePurchases',
  };
}
