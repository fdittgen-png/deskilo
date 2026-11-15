// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4005 — the house abroad the Demo adds: Atelier Kraków, in Poland, in
// złoty. It is dormant until the visitor adds a house abroad from Settings ›
// Organisation: then its row and Ada's ownership appear, the head's services
// and packages arrive in it inactive (their amounts at 0: the currency is not
// the head's), and its birth record says its prices are still to be named.
//
// Poland: a country the tax reference supports whose currency is neither the
// head's (euro) nor that of any other Demo business, so the visitor sees the
// prices arrive empty, to be named.
import '../../../features/workspace/domain/business_kind_proposal.dart';
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../data/business_kind_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_dataset.dart';
import '../demo_space_ids.dart';

const _houseName = 'Atelier Kraków';

/// The house's country and currency.
const demoHouseCountry = 'PL';
const demoHouseCurrency = 'PLN';
const _houseTimezone = 'Europe/Warsaw';

/// The house's features: a new business's, without places — neither its
/// sites nor its floor plan travel from the head, so it has none yet.
Map<String, bool> _houseFlags() {
  final fresh = defaultFeatureFlagsForNewWorkspace();
  return {
    ...fresh,
    ...proposalFor(
      profile: demoNoPlacesProfile,
      raw: resolveEnabledFeatures(fresh),
      country: demoHouseCountry,
    ).flags,
    WorkspaceFeature.workspaceOverview.dbKey: true,
  };
}

/// The house as it is made: a new business's features, in Poland, in złoty.
Workspace demoHouseSpace() => Workspace(
  id: demoHouseSpaceId,
  rolePermissions: everydayMatrix(),
  name: _houseName,
  countryCode: demoHouseCountry,
  currencyCode: demoHouseCurrency,
  timezone: _houseTimezone,
  inviteCode: 'KRAKOW2026',
  featureFlags: _houseFlags(),
  environment: 'prod',
  city: 'Kraków',
);

/// Ada, who adds the house, owns it; the cast's second person is added
/// once at birth as its co-owner (what the server does).
void seedHousePeople(FakeWorkspaceRepository space) {
  final owner = demoCast.first;
  final coOwner = demoCast[1];
  space
    ..myMember = Member(
      id: owner.memberId,
      workspaceId: demoHouseSpaceId,
      userId: owner.userId,
      isAdmin: true,
      isOwner: true,
      status: MemberStatus.active,
      subscriptionPct: owner.subscriptionPct,
    )
    ..memberNames[owner.memberId] = owner.name
    ..memberEmails[owner.memberId] = owner.email
    ..otherMembers.add(
      Member(
        id: coOwner.memberId,
        workspaceId: demoHouseSpaceId,
        userId: coOwner.userId,
        isAdmin: true,
        isOwner: false,
        coOwner: CoOwnerStatus.active,
        status: MemberStatus.active,
      ),
    )
    ..memberNames[coOwner.memberId] = coOwner.name
    ..memberEmails[coOwner.memberId] = coOwner.email;
}
