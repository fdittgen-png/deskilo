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

/// The practice's country: Leipzig's, reused (#3863).
const demoPracticeCountry = 'DE';

/// The practice's features: a new space's, the kind's profile applied on top
/// (with the parents it needs), and the Overview it opens on.
Map<String, bool> _practiceFlags() {
  final fresh = defaultFeatureFlagsForNewWorkspace();
  return {
    ...fresh,
    ...proposalFor(
      profile: demoNoPlacesProfile,
      raw: resolveEnabledFeatures(fresh),
      country: demoPracticeCountry,
    ).flags,
    WorkspaceFeature.workspaceOverview.dbKey: true,
  };
}

/// The practice as its owner set it up: German, in euros, registered for VAT.
Workspace demoPracticeSpace() => Workspace(
  id: demoPracticeSpaceId,
  rolePermissions: everydayMatrix(),
  name: demoPracticeName,
  countryCode: demoPracticeCountry,
  currencyCode: 'EUR',
  timezone: 'Europe/Berlin',
  inviteCode: 'LINDNER2026',
  featureFlags: _practiceFlags(),
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

/// The practice's clients, people of the city.
const _clients = 4;

/// Ada owns the practice; its clients are people of the city (the cast's
/// own finances stay those of the spaces they belong to). A persona switch
/// moves the "mine" pointer.
void seedPracticePeople(FakeWorkspaceRepository space) {
  final owner = demoCast.first;
  space
    ..myMember = Member(
      id: owner.memberId,
      workspaceId: demoPracticeSpaceId,
      userId: owner.userId,
      isAdmin: true,
      isOwner: true,
      status: MemberStatus.active,
      subscriptionPct: owner.subscriptionPct,
    )
    ..memberNames[owner.memberId] = owner.name
    ..memberEmails[owner.memberId] = owner.email;
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
  billsOwner: false,
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
