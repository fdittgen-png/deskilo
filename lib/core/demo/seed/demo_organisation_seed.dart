// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4009 -- the Demo's reference is an organisation: Atelier du Marché heads
// it, and the Demo's other production businesses of the trade (London, New
// York, Zurich, Milan, Leipzig) are its houses. The houses are not listed a
// second time: they are the businesses the person is a member of, read from
// the Demo's own list, each with its own country and currency and the role the
// person holds there. The Berlin practice is a business of its own outside it,
// and a development twin is no house.
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/organisation.dart';
import '../data/workspace_repository.dart';
import '../demo_space_ids.dart';
import '../demo_spaces.dart';

/// The organisation's name and id in the Demo.
const _name = 'Atelier du Marché';
const _id = 'demo-organisation-atelier';

/// The Demo's businesses that belong to no organisation (the twin is a
/// development environment and is left out by its environment).
const _outside = {DemoSpaceKey.practice, DemoSpaceKey.freelancer, DemoSpaceKey.shop};

HouseRole _roleOf(Member m) {
  if (m.isOwner) return HouseRole.owner;
  if (m.coOwner == CoOwnerStatus.active) return HouseRole.coOwner;
  if (m.isAdmin) return HouseRole.admin;
  return HouseRole.member;
}

/// #4008 — whether [workspaceId] is a house of the Demo's organisation.
bool demoIsHouse(String workspaceId, String environment) =>
    environment == 'prod' &&
    DemoSpaceKey.values.any(
      (k) => k.id == workspaceId && !_outside.contains(k),
    );

/// The Demo's organisations as the person is a member of their houses: the
/// head and every other production business of the Demo, except those
/// [_outside], each with its row's own country and currency.
Future<List<Organisation>> demoOrganisations(
  FakeWorkspaceRepository home,
) async {
  final businesses = await home.fetchMyWorkspaces();
  final memberships = await home.fetchMyMembers();
  final houses = [
    for (final business in businesses)
      if (demoIsHouse(business.id, business.environment))
        for (final m in memberships)
          if (m.workspaceId == business.id && m.status == MemberStatus.active)
            OrganisationHouse(
              workspaceId: business.id,
              name: business.name,
              countryCode: business.countryCode,
              currencyCode: business.currencyCode,
              role: _roleOf(m),
            ),
  ];
  if (houses.isEmpty) return const [];
  return [
    Organisation(
      id: _id,
      name: _name,
      headWorkspaceId: demoFirstSpaceId,
      houses: houses,
    ),
  ];
}

/// #4006 — every production business of the Demo the person is an active
/// member of, as the house it would be: what an owner may add to an
/// organisation (the Berlin practice among them).
Future<List<OrganisationHouse>> demoBusinessesAsHouses(
  FakeWorkspaceRepository home,
) async {
  final businesses = await home.fetchMyWorkspaces();
  final memberships = await home.fetchMyMembers();
  return [
    for (final business in businesses)
      if (business.environment == 'prod')
        for (final m in memberships)
          if (m.workspaceId == business.id && m.status == MemberStatus.active)
            OrganisationHouse(
              workspaceId: business.id,
              name: business.name,
              countryCode: business.countryCode,
              currencyCode: business.currencyCode,
              role: _roleOf(m),
            ),
  ];
}
