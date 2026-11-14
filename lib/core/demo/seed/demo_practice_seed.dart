// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3863 — the Demo's practice: a consulting practice in Berlin, the one Demo
// business without places (the reference business, Atelier du Marché, cannot
// hold that variant). Its features are those of a space created today with
// the practice's kind applied on top, as the kind sheet applies it: no place
// booking, no floor plan, no seat. Its people are the cast's first three and
// a few clients; its money is three years of monthly invoices for its own
// services, in euros with German VAT.
import '../../../features/workspace/domain/business_kind_proposal.dart';
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../data/business_kind_repository.dart';
import '../data/workspace_repository.dart';
import '../demo_dataset.dart';
import '../demo_space_ids.dart';
import 'demo_city_money_seed.dart';
import 'demo_city_people_seed.dart';

const demoPracticeName = 'Lindner Beratung';

/// The practice's features: a new space's, the kind's profile applied on top
/// (with the parents it needs), and the Overview it opens on.
Map<String, bool> demoPracticeFeatureFlags() {
  final fresh = defaultFeatureFlagsForNewWorkspace();
  return {
    ...fresh,
    ...proposalFor(
      profile: demoNoPlacesProfile,
      raw: resolveEnabledFeatures(fresh),
      country: 'DE',
    ).flags,
    WorkspaceFeature.workspaceOverview.dbKey: true,
  };
}

/// The practice as its owner set it up: German, in euros, registered for VAT.
Workspace demoPracticeSpace() => Workspace(
  id: demoPracticeSpaceId,
  rolePermissions: everydayMatrix(),
  name: demoPracticeName,
  countryCode: 'DE',
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'LINDNER2026',
  featureFlags: demoPracticeFeatureFlags(),
  environment: 'prod',
  address: 'Kastanienallee 12, 10435 Berlin',
  street: 'Kastanienallee 12',
  postalCode: '10435',
  city: 'Berlin',
  vatRegime: 'vat_registered',
  legalId: 'HRB 228410',
  branding: const {
    'seed_color': '#0F766E',
    'pattern': 'dots',
    'symbol_text': 'LB',
    'symbol_color': '#0F766E',
  },
);

/// The clients beside the cast.
const _clients = 3;

/// Ada owns the practice; Chiara and Bruno are clients, as are a few people
/// of the city. A persona switch moves the "mine" pointer.
void seedPracticePeople(FakeWorkspaceRepository space) {
  Member member(DemoPerson p, {bool owner = false}) => Member(
    id: p.memberId,
    workspaceId: demoPracticeSpaceId,
    userId: p.userId,
    isAdmin: owner,
    isOwner: owner,
    status: MemberStatus.active,
    subscriptionPct: p.subscriptionPct,
  );
  final people = demoCast.take(3).toList();
  space
    ..myMember = member(people.first, owner: true)
    ..otherMembers.addAll([for (final p in people.skip(1)) member(p)]);
  for (final p in people) {
    space.memberNames[p.memberId] = p.name;
    space.memberEmails[p.memberId] = p.email;
  }
  for (var i = 0; i < _clients; i++) {
    final id = 'practice-member-${i + 1}';
    space.otherMembers.add(
      Member(
        id: id,
        workspaceId: demoPracticeSpaceId,
        userId: 'practice-user-${i + 1}',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
      ),
    );
    space.memberNames[id] = demoCityPersonName(40 + i);
    space.memberEmails[id] = 'practice.client${i + 1}@example.test';
  }
}

/// What the practice invoices: a monthly advisory retainer and its own
/// services, never a place.
const CityMoneyWords demoPracticeMoneyWords = (
  title: 'Beratung',
  fee: 'Monthly advisory retainer',
  memberAddress: 'Musterstraße, Berlin',
  catalogue: [
    ('Consultation hour', 9000, false),
    ('Workshop half-day', 45000, false),
    ('Written opinion', 30000, false),
    ('Document review', 6000, false),
    ('Phone advice (15 min)', 2500, false),
    ('Copies and binding', 20, false),
    ('Follow-up meeting', 7000, false),
    ('Travel to the client', 4000, false),
    ('Express handling', 5000, false),
  ],
);
