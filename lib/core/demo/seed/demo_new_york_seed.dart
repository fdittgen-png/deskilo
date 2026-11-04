// SPDX-License-Identifier: AGPL-3.0-or-later
// Synthetic New York tenant-run coworking workspace.
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/site.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_feature.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../data/workspace_repository.dart';
import '../demo_dataset.dart';
import 'demo_city_people_seed.dart';

const demoNewYorkSpaceId = 'ws-4';

Workspace demoNewYorkSpace() => Workspace(
  id: demoNewYorkSpaceId,
  name: 'Hudson Cooperative Workspaces',
  countryCode: 'US',
  currencyCode: 'USD',
  timezone: 'America/New_York',
  inviteCode: 'HUDSONDEMO',
  environment: 'prod',
  rolePermissions: everydayMatrix(),
  featureFlags: {
    for (final feature in featureManifest.keys) feature.dbKey: true,
  },
  address: '100 Example Avenue\nNew York, NY 10001',
  street: '100 Example Avenue',
  city: 'New York',
  postalCode: '10001',
  branding: const {
    'seed_color': '#0F766E',
    'pattern': 'dots',
    'symbol_text': 'HC',
  },
);

void seedNewYorkPeople(FakeWorkspaceRepository space) {
  Member cast(DemoPerson p, {bool owner = false, bool admin = false}) => Member(
    id: p.memberId,
    workspaceId: demoNewYorkSpaceId,
    userId: p.userId,
    isAdmin: admin,
    isOwner: owner,
    status: MemberStatus.active,
  );
  final members = [
    cast(demoCast[0], owner: true, admin: true),
    cast(demoCast[1]),
    cast(demoCast[2], admin: true),
  ];
  space.myMember = members.first;
  space.otherMembers.addAll(members.skip(1));
  for (final person in demoCast.take(3)) {
    space.memberNames[person.memberId] = person.name;
    space.memberEmails[person.memberId] = person.email;
  }
  for (var i = 0; i < 57; i++) {
    final id = 'ny-member-${i + 1}';
    space.otherMembers.add(
      Member(
        id: id,
        workspaceId: demoNewYorkSpaceId,
        userId: 'ny-user-${i + 1}',
        isAdmin: false,
        isOwner: false,
        status: MemberStatus.active,
        homeSiteId: [
          'ny-site-main',
          'ny-site-brooklyn',
          'ny-site-queens',
          'ny-site-bronx',
          'ny-site-harlem',
        ][i % 5],
      ),
    );
    space.memberNames[id] = demoCityPersonName(i);
    space.memberEmails[id] = 'ny.member${i + 1}@example.test';
  }
  space.sites.addAll(const [
    Site(
      id: 'ny-site-main',
      workspaceId: demoNewYorkSpaceId,
      name: 'Hudson House',
      city: 'New York',
      countryCode: 'US',
      isDefault: true,
    ),
    Site(
      id: 'ny-site-brooklyn',
      workspaceId: demoNewYorkSpaceId,
      name: 'Brooklyn Studio',
      city: 'New York',
      countryCode: 'US',
      sortOrder: 1,
    ),
    Site(
      id: 'ny-site-queens',
      workspaceId: demoNewYorkSpaceId,
      name: 'Queens Studio',
      city: 'New York',
      countryCode: 'US',
      sortOrder: 2,
    ),
    Site(
      id: 'ny-site-bronx',
      workspaceId: demoNewYorkSpaceId,
      name: 'Bronx Studio',
      city: 'New York',
      countryCode: 'US',
      sortOrder: 3,
    ),
    Site(
      id: 'ny-site-harlem',
      workspaceId: demoNewYorkSpaceId,
      name: 'Harlem Studio',
      city: 'New York',
      countryCode: 'US',
      sortOrder: 4,
    ),
  ]);
}
