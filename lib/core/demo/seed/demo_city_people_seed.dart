// SPDX-License-Identifier: AGPL-3.0-or-later
// Invented names; email addresses remain under example.test.
import '../../../features/profile/domain/personal_info.dart';
import '../../../features/profile/domain/profile.dart';
import '../data/workspace_repository.dart';

List<Profile> demoCityProfiles(FakeWorkspaceRepository space, String prefix) =>
    [
      for (final member in [space.myMember, ...space.otherMembers])
        if (member.userId.startsWith('$prefix-user-'))
          Profile(
            id: member.userId,
            displayName: space.memberNames[member.id] ?? '',
            countryCode: prefix == 'uk' ? 'GB' : 'US',
            address: prefix == 'uk'
                ? 'Example Street, London'
                : 'Example Avenue, New York',
            identity: PersonalInfo(
              firstName: space.memberNames[member.id] ?? '',
              city: prefix == 'uk' ? 'London' : 'New York',
              countryCode: prefix == 'uk' ? 'GB' : 'US',
              email: space.memberEmails[member.id] ?? '',
            ),
          ),
    ];

const _first = [
  'Avery',
  'Blair',
  'Casey',
  'Devon',
  'Ellis',
  'Finley',
  'Harper',
  'Indigo',
  'Jules',
  'Kai',
  'Lane',
  'Morgan',
  'Noel',
  'Oakley',
  'Parker',
  'Quinn',
  'Reese',
  'Sasha',
  'Taylor',
  'Val',
];
const _last = ['Ashford', 'Bellamy', 'Cedar', 'Dale', 'Ellery', 'Fairwood'];

String demoCityPersonName(int index) =>
    '${_first[index % _first.length]} ${_last[index ~/ _first.length]}';
