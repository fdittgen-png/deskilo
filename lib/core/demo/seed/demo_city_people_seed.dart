// SPDX-License-Identifier: AGPL-3.0-or-later
// Invented names; email addresses remain under example.test.
import '../../../features/profile/domain/personal_info.dart';
import '../../../features/profile/domain/profile.dart';
import '../data/workspace_repository.dart';

/// Where the people of a city's prefix live: their country, town and street.
const _homes = <String, ({String country, String city, String street})>{
  'uk': (country: 'GB', city: 'London', street: 'Example Street'),
  'ch': (country: 'CH', city: 'Zurich', street: 'Beispielstrasse'),
  'it': (country: 'IT', city: 'Milano', street: 'Via Esempio'),
  // #3863 — the practice's clients.
  'practice': (country: 'DE', city: 'Berlin', street: 'Musterstraße'),
};
const _newYork = (country: 'US', city: 'New York', street: 'Example Avenue');

List<Profile> demoCityProfiles(FakeWorkspaceRepository space, String prefix) {
  final home = _homes[prefix] ?? _newYork;
  return [
    for (final member in [space.myMember, ...space.otherMembers])
      if (member.userId.startsWith('$prefix-user-'))
        Profile(
          id: member.userId,
          displayName: space.memberNames[member.id] ?? '',
          countryCode: home.country,
          address: '${home.street}, ${home.city}',
          identity: PersonalInfo(
            firstName: space.memberNames[member.id] ?? '',
            city: home.city,
            countryCode: home.country,
            email: space.memberEmails[member.id] ?? '',
          ),
        ),
  ];
}

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
