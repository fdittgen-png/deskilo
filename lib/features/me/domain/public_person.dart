// SPDX-License-Identifier: AGPL-3.0-or-later

/// What a signed-out visitor may read of a person who published a public
/// profile (0389): the name, the profession and the bio — never a contact
/// channel, the presence or the spaces.
class PublicPerson {
  const PublicPerson({required this.name, this.profession = '', this.bio = ''});

  final String name, profession, bio;

  static PublicPerson fromJson(Map<String, dynamic> j) => PublicPerson(
    name: j['name'] as String? ?? '',
    profession: j['profession'] as String? ?? '',
    bio: j['bio'] as String? ?? '',
  );
}
