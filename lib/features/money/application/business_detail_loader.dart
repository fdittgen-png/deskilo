// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 -- the reads behind the rows of My businesses: the invoices of a
// business's receivables and the obligations it has to pay, one page at a time
// with the server's own continuation. The sheet asks this, never a repository.
import '../domain/business_payables.dart';
import '../domain/business_receivables.dart';
import '../domain/supplier_payables_page.dart';

class BusinessDetailLoader {
  /// The repositories are asked for when a page is read: a sheet of one
  /// direction never builds the other direction's repository.
  const BusinessDetailLoader(this._receivables, this._payables);

  final BusinessReceivablesRepository Function() _receivables;
  final BusinessPayablesRepository Function() _payables;

  Future<ReceivablesPage> receivables(
    String workspaceId,
    String currency, {
    ReceivableState? state,
    ReceivablesCursor? after,
  }) => _receivables().page(workspaceId, currency, state: state, after: after);

  Future<SupplierPayablesPage> payables(
    String workspaceId,
    String currency, {
    String? creditorKind,
    SupplierPayablesCursor? after,
  }) => _payables().payablesPage(
    workspaceId,
    currency,
    creditorKind: creditorKind,
    after: after,
  );
}
