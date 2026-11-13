// SPDX-License-Identifier: AGPL-3.0-or-later
// Invented names; email addresses remain under example.test.
import '../../../features/profile/domain/personal_info.dart';
import '../../../features/profile/domain/profile.dart';
import '../data/workspace_repository.dart';

List<Profile> demoCityProfiles(FakeWorkspaceRepository space, String prefix, {required String country, required String city}) =>
    [
      for (final member in [space.myMember, ...space.otherMembers])
        if (member.userId.startsWith('$prefix-user-'))
          Profile(
            id: member.userId,
            displayName: space.memberNames[member.id] ?? '',
            countryCode: country,
            address: 'Example Street, $city',
            identity: PersonalInfo(
              firstName: space.memberNames[member.id] ?? '',
              city: city,
              countryCode: country,
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
