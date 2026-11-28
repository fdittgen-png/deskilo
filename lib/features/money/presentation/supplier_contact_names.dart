// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4518 -- how a role of a supplier's contacts reads, and which are on offer. A role with a label of its own reads as the business wrote
// it; a built-in one that was never renamed reads in the app's words, in the member's language.
import '../../../l10n/app_localizations.dart';
import '../domain/supplier_contact.dart';

/// The roles a new contact may be given, in the business's order.
List<SupplierContactRole> activeSupplierContactRoles(List<SupplierContactRole> all) => [
  for (final r in all)
    if (!r.retired) r,
];

/// The name of [role] as the member reads it.
String supplierContactRoleName(AppLocalizations l10n, SupplierContactRole role) {
  final own = role.label.trim();
  if (own.isNotEmpty) return own;
  return switch (role.code) {
    BuiltInContactRole.orders => l10n.supplierContactRoleOrders,
    BuiltInContactRole.invoices => l10n.supplierContactRoleInvoices,
    BuiltInContactRole.delivery => l10n.supplierContactRoleDelivery,
    BuiltInContactRole.accounting => l10n.supplierContactRoleAccounting,
    _ => l10n.supplierContactRoleOther,
  };
}
