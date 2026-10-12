// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2358 — where a customer receives e-invoices. A network delivers by
// this address (Peppol, the French directory, a Leitweg-ID, an SdI
// recipient code) and CIUS-RO wants the county of the address; both are
// frozen into every invoice's buyer snapshot.
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../domain/member.dart';
import '../domain/workspace_repository.dart';
import '../providers/workspace_providers.dart';

part 'set_member_einvoice_address.g.dart';

class MemberEInvoiceAddresses {
  const MemberEInvoiceAddresses(this._workspaces);
  final WorkspaceRepository _workspaces;

  /// Stores [member]'s address. Returns false when nothing changed; a
  /// server refusal (an address without its scheme, a field too long)
  /// propagates.
  Future<bool> set(
    Member member, {
    required String endpointId,
    required String endpointScheme,
    required String subdivision,
  }) async {
    final id = endpointId.trim();
    final scheme = endpointScheme.trim().toUpperCase();
    final county = subdivision.trim().toUpperCase();
    if (id == member.einvoiceEndpointId &&
        scheme == member.einvoiceEndpointScheme &&
        county == member.billingSubdivision) {
      return false;
    }
    await _workspaces.setMemberEInvoiceAddress(
      member.id,
      endpointId: id,
      endpointScheme: scheme,
      subdivision: county,
    );
    return true;
  }
}

/// #2358 — the command that states a customer's e-invoicing address.
@riverpod
MemberEInvoiceAddresses memberEInvoiceAddresses(Ref ref) =>
    MemberEInvoiceAddresses(ref.watch(workspaceRepositoryProvider));
