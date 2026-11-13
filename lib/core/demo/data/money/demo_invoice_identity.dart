// SPDX-License-Identifier: AGPL-3.0-or-later
// Identity is read at issue time and frozen with the immutable document.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../../features/profile/domain/profile.dart';
import '../workspace_repository.dart';

typedef DemoInvoiceIdentity = ({
  String memberName,
  String memberAddress,
  String workspaceName,
  String workspaceAddress,
  String issuerName,
  InvoiceParty? seller,
  InvoiceParty? buyer,
});

/// Bare unit fakes retain their deliberately distinguishable test identities.
DemoInvoiceIdentity demoDefaultInvoiceIdentity(String memberId) => (
  memberName: memberId == 'member-1' ? 'Flo' : 'Ana',
  memberAddress: '1 Rue Test, 34120 Pézenas',
  workspaceName: 'Test Space',
  workspaceAddress: '2 Place du Marché, 34120 Pézenas',
  issuerName: 'Flo',
  seller: null,
  buyer: null,
);

DemoInvoiceIdentity demoInvoiceIdentityFor(
  FakeWorkspaceRepository repository, {
  required String memberId,
  required String actorMemberId,
  Profile? profile,
}) {
  final member = repository.memberOf(memberId);
  if (member == null) throw StateError('unknown invoice buyer');
  final workspace = repository.workspaces.firstWhere(
    (w) => w.id == member.workspaceId,
  );
  final identity = profile?.identity ?? member.managedIdentity;
  final name =
      repository.memberNames[memberId] ??
      profile?.fullName ??
      member.managedName;
  final address =
      profile?.postalBlock(workspaceCountry: workspace.countryCode) ??
      identity.postalBlock(workspaceCountry: workspace.countryCode);
  return (
    memberName: name,
    memberAddress: address,
    workspaceName: workspace.name,
    workspaceAddress: workspace.address,
    issuerName: repository.memberNames[actorMemberId] ?? '',
    seller: InvoiceParty(
      name: workspace.name,
      street: workspace.street,
      city: workspace.city,
      postalCode: workspace.postalCode,
      country: workspace.countryCode,
      legalId: workspace.legalId,
      vatId: workspace.vatId,
      vatRegime: workspace.vatRegime,
      taxExemptionReason: workspace.taxExemptionReason,
    ),
    buyer: InvoiceParty(
      name: name,
      company: identity.company,
      person: identity.personName,
      street: identity.street.isEmpty ? address : identity.street,
      city: identity.city,
      postalCode: identity.postalCode,
      country: identity.countryCode.isNotEmpty
          ? identity.countryCode
          : profile?.countryCode.isNotEmpty == true
          ? profile!.countryCode
          : workspace.countryCode,
      vatId: profile?.vatId ?? identity.vatId,
      memberNumber: member.memberNumber,
      email: identity.email,
      endpointId: member.einvoiceEndpointId,
      endpointScheme: member.einvoiceEndpointScheme,
      subdivision: member.billingSubdivision,
    ),
  );
}
