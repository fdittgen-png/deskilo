// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4365 -- the Épicerie du Marché: the Demo's shop. A small grocery in Pézenas (France, euros), owned by Bruno,
// of the kind `shop`, with no places to book: the features of a new space with the kind's reviewed profile
// applied on top, as the kind sheet applies it. Its goods ledger mirrors the reference business's (the
// same four items, the same places and movements), kept in the Demo's own memory under this business.
import '../../../features/workspace/domain/business_kind_proposal.dart';
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../data/business_kind_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_persona.dart';
import '../demo_space_ids.dart';

Map<String, bool> _flags() {
  final fresh = defaultFeatureFlagsForNewWorkspace();
  return {
    ...fresh,
    ...proposalFor(profile: demoShopProfile, raw: resolveEnabledFeatures(fresh), country: 'FR').flags,
    WorkspaceFeature.workspaceOverview.dbKey: true,
  };
}

/// The business as its owner set it up: French, in euros, registered for VAT.
Workspace demoShopSpace() => Workspace(
  id: demoShopSpaceId,
  rolePermissions: everydayMatrix(),
  name: 'Épicerie du Marché',
  countryCode: 'FR',
  currencyCode: 'EUR',
  timezone: 'Europe/Paris',
  inviteCode: 'MARCHE2026',
  featureFlags: _flags(),
  environment: 'prod',
  address: '3 place du Marché, 34120 Pézenas',
  street: '3 place du Marché',
  postalCode: '34120',
  city: 'Pézenas',
  vatRegime: 'vat_registered',
  legalId: '81234567800027',
  branding: const {
    'seed_color': '#16A34A',
    'pattern': 'dots',
    'symbol_text': 'EM',
    'symbol_color': '#16A34A',
  },
);

/// Bruno owns the business, and nobody else is in it: ownership is the membership of THIS business.
void seedShopPeople(FakeWorkspaceRepository space) {
  final owner = DemoPersona.member.person;
  space
    ..myMember = Member(
      id: owner.memberId,
      workspaceId: demoShopSpaceId,
      userId: owner.userId,
      isAdmin: true,
      isOwner: true,
      status: MemberStatus.active,
      subscriptionPct: owner.subscriptionPct,
    )
    ..memberNames[owner.memberId] = owner.name
    ..memberEmails[owner.memberId] = owner.email
    // a regular customer with no account: a member row of the business with no user (a space is never one person)
    ..otherMembers.add(
      Member(
        id: 'marche-customer-faure',
        workspaceId: demoShopSpaceId,
        userId: '',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      ),
    )
    ..memberNames['marche-customer-faure'] = 'Marie Faure';
}
