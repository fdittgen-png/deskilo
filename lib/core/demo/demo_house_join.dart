// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4008 — in the Demo, a member of one house of the organisation asks to
// join another: the houses the persona is not an active member of are the
// ones they may ask, and asking makes them a member there (at once when
// the house welcomes the organisation's members, else waiting for the
// house). Bruno, the member the Demo looks through, starts outside Milan.
import '../../features/workspace/domain/member.dart';
import '../../features/workspace/domain/organisation.dart';
import 'demo_dataset.dart';
import 'demo_fixture.dart';
import 'seed/demo_organisation_seed.dart';

/// The houses of the Demo's organisation the persona may ask to join, and
/// whether they asked; none for a persona in no house of it.
Future<List<JoinableHouse>> demoJoinableHouses(DemoFixture f) async {
  final organisation = (await demoOrganisations(f.workspaces)).firstOrNull;
  if (organisation == null) return const [];
  final memberId = f.actor.memberId;
  return [
    for (final listing in f.listings)
      if (!listing.dormant)
        if (listing.row case final w?
            when demoIsHouse(w.id, w.environment) &&
                organisation.houseOf(w.id) == null)
          JoinableHouse(
            organisationId: organisation.id,
            organisationName: organisation.name,
            workspaceId: w.id,
            name: w.name,
            countryCode: w.countryCode,
            currencyCode: w.currencyCode,
            asked: listing.memberOf(memberId)?.status == MemberStatus.pending,
          ),
  ];
}

/// The persona becomes a member of [workspaceId]: active when the house
/// [welcome]s the organisation's members, else waiting for its decision.
Future<void> demoJoinHouse(
  DemoFixture f,
  String workspaceId, {
  required bool welcome,
}) async {
  final listing = f.listings.firstWhere((l) => l.id == workspaceId);
  final person = demoCast.firstWhere((p) => p.memberId == f.actor.memberId);
  listing.join(
    Member(
      id: person.memberId,
      workspaceId: workspaceId,
      userId: person.userId,
      isAdmin: false,
      isOwner: false,
      status: welcome ? MemberStatus.active : MemberStatus.pending,
      subscriptionPct: person.subscriptionPct,
    ),
  );
}
