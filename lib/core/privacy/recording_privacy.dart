// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1514 — filming the app without filming the members.
//
// A guide, a support video, a store listing or a conference talk needs a
// screenshot of a LIVE workspace: its real plan, its real bookings, its
// real figures. What it must not carry is a real person. Demo answers a
// different question — it shows an invented WORKSPACE — and is the right
// answer whenever the structure itself may be invented. This is the
// answer when it may not.
//
// THE SHAPE, and why it is this one (ADR 0032). The retired mechanism
// (#970, removed by #1380) painted over the rendered result: it scanned
// the render tree every frame and blurred the rectangles whose text
// matched a registry of personal strings that a dozen providers had to
// remember to feed. A provider that forgot left a name in the clear,
// silently, in the recording nobody re-watches — it failed OPEN.
//
// This substitutes invented people at the DATA seam instead. Every
// personal value the app shows arrives through one of six providers;
// each of them hands its result to this file before anybody can read it,
// so a name that reaches a widget has already been replaced. There is no
// per-frame scan to get wrong and no string registry to forget, because
// nothing real was ever rendered.
//
// It fails CLOSED in the only sense that matters: the failure mode of a
// substitution is a name that is invented when it did not need to be,
// never a real one that stayed. Adding a screen cannot leak — a screen
// reads the providers. Adding a PROVIDER could, which is why
// `recording_seam_test` pins the repository reads that carry people and
// fails on a new one.
//
// Pure Dart on purpose: the substitution is a property of the data, so
// it is testable without a widget and readable without a frame.
import '../../features/profile/domain/personal_info.dart';
import '../../features/profile/domain/profile.dart';
import '../../features/workspace/domain/member.dart';

/// One invented person: what the app shows in place of somebody real.
class RecordingPerson {
  const RecordingPerson({
    required this.firstName,
    required this.lastName,
    required this.street,
    required this.postalCode,
    required this.city,
    required this.phone,
  });

  final String firstName;
  final String lastName;
  final String street;
  final String postalCode;
  final String city;
  final String phone;

  /// `prenom.nom@example.test` — RFC 2606 reserves `.test`, so it can
  /// never be delivered to anybody, and a viewer who types it reaches
  /// nothing.
  String get email =>
      '${_slug(firstName)}.${_slug(lastName)}@example.test';

  /// "Prénom NOM", the rendering every surface already uses.
  String get fullName => '$firstName ${lastName.toUpperCase()}';
}

/// The halves the cast is drawn from. Two independent draws over
/// sixteen names each give 256 people, which is more than a workspace
/// that fits on a floor plan — so two members sharing a pseudonym is
/// rare, and never wrong when it happens.
const List<String> _firstNames = [
  'Ada', 'Bruno', 'Chiara', 'Dov', 'Elise', 'Farid', 'Gaia', 'Hugo',
  'Iris', 'Jonas', 'Katia', 'Léo', 'Maya', 'Noor', 'Ravi', 'Selma',
];

const List<String> _lastNames = [
  'Almeida', 'Brandt', 'Costa', 'Delaunay', 'Eriksen', 'Fontaine',
  'Garnier', 'Holm', 'Imbert', 'Jansen', 'Kessler', 'Lindqvist',
  'Moreau', 'Novak', 'Ortiz', 'Pereira',
];

/// Invented streets and localities. None of them exists: a viewer who
/// looks one up finds nothing, which is the whole requirement.
const List<String> _streets = [
  'rue des Quatre-Vents', 'allée du Hameau Clair', 'chemin des Ardoises',
  'place du Vieux Puits', 'impasse des Cerisiers', 'route de la Fontaine',
  'quai des Tilleuls', 'cours de la Palmeraie',
];

const List<List<String>> _localities = [
  ['34999', 'Sainte-Colombe-des-Vignes'],
  ['31998', 'Bellerive-sur-Lèze'],
  ['44997', 'Port-Adrien'],
  ['67996', 'Hautmoulin'],
];

/// FNV-1a over the key's code units. A hand-rolled hash rather than
/// `String.hashCode`, because the pseudonym has to be the same on every
/// screen, in every process and in the test that pins it — a hash the
/// runtime is free to salt would give a recording a different cast after
/// a restart, mid-shoot.
int _fnv1a(String key, int salt) {
  var hash = 0x811c9dc5 ^ salt;
  for (final unit in key.codeUnits) {
    hash = (hash ^ unit) * 0x01000193 & 0x7fffffff;
  }
  return hash;
}

/// Lower-case, accent-free, for an e-mail local part.
String _slug(String name) {
  const from = 'àâäéèêëîïôöùûüç';
  const to = 'aaaeeeeiioouuuc';
  final buffer = StringBuffer();
  for (final rune in name.toLowerCase().runes) {
    final char = String.fromCharCode(rune);
    final index = from.indexOf(char);
    buffer.write(index < 0 ? char : to[index]);
  }
  return buffer.toString().replaceAll(RegExp('[^a-z0-9]'), '-');
}

/// The invented person [key] is shown as — the same one every time.
///
/// [key] is whatever identifies the person to the app: an auth user id,
/// a member id. Two different keys for the same human (their user id on
/// one screen, their member id on another) would show two different
/// pseudonyms, so each provider passes the key its data is keyed BY and
/// the ADR records which.
RecordingPerson recordingPersonFor(String key) {
  final locality = _localities[_fnv1a(key, 3) % _localities.length];
  return RecordingPerson(
    firstName: _firstNames[_fnv1a(key, 0) % _firstNames.length],
    lastName: _lastNames[_fnv1a(key, 1) % _lastNames.length],
    street: '${1 + _fnv1a(key, 2) % 80} ${_streets[_fnv1a(key, 4) % _streets.length]}',
    postalCode: locality[0],
    city: locality[1],
    // ARCEP reserves 06 39 98 xx xx for fiction; it can never ring.
    phone: '+33639980${(100 + _fnv1a(key, 5) % 900)}',
  );
}

/// The invented name [key] is shown under, or '' when there was no name
/// to begin with — an absent name is not personal data, and inventing
/// one would put a person where the workspace has none.
String recordingName(String key, String real) =>
    real.trim().isEmpty ? '' : recordingPersonFor(key).fullName;

/// [real], with every field that identifies a human replaced.
///
/// The fields kept are the ones that describe the DOCUMENT rather than
/// the person: the courtesy title (a form of address, shown as chosen)
/// and the country (what decides the VAT treatment and the postal
/// rendering, and which a recording is usually about). Everything a
/// person could be found by — name, company, street, locality, phone,
/// e-mail, VAT and legal identifiers — is substituted or cleared.
///
/// Empty in, empty out: a blank identity stays blank, so a screen that
/// says "nothing recorded" keeps saying it.
PersonalInfo recordingIdentity(String key, PersonalInfo real) {
  if (real.isEmpty) return real;
  final person = recordingPersonFor(key);
  return PersonalInfo(
    courtesy: real.courtesy,
    firstName: real.firstName.isEmpty && real.lastName.isEmpty
        ? ''
        : person.firstName,
    lastName:
        real.firstName.isEmpty && real.lastName.isEmpty ? '' : person.lastName,
    company: real.company.isEmpty ? '' : '${person.lastName} & Associés',
    street: real.street.isEmpty ? '' : person.street,
    postalCode: real.postalCode.isEmpty ? '' : person.postalCode,
    city: real.city.isEmpty ? '' : person.city,
    countryCode: real.countryCode,
    phone: real.phone.isEmpty ? '' : person.phone,
    email: real.email.isEmpty ? '' : person.email,
    // An identifier is a lookup key into a public register: substituted
    // to a shape that is recognisable and resolves to nobody.
    vatId: real.vatId.isEmpty ? '' : 'FR00${_fnv1a(key, 6) % 1000000000}',
    legalId: real.legalId.isEmpty ? '' : '${100000000 + _fnv1a(key, 7) % 899999999}',
  );
}

/// [real], as a recording may show it.
///
/// A membership row carries two personal things and no more: the
/// addressee line the server derives, and the identity of somebody an
/// admin manages who has no account yet. Everything else on it — the
/// subscription, the quota, the role, the payment terms — is about the
/// MEMBERSHIP rather than the person, and a recording is usually about
/// exactly that, so it is left alone.
Member recordingMember(Member real) => real.copyWith(
      managedName: recordingName(real.id, real.managedName),
      managedIdentity: recordingIdentity(real.id, real.managedIdentity),
    );

/// [real], as a recording may show it.
///
/// The photograph goes with the name: a face identifies a person at
/// least as well as the name beside it, and the nine published guide
/// images that kept real faces after the #1199 sweep are why this drops
/// [Profile.avatarPath] rather than leaving it to the caller. The
/// self-set status line goes too — it is free text a member wrote about
/// themselves, and nothing can vouch for what is in it.
Profile recordingProfile(Profile real) {
  final person = recordingPersonFor(real.id);
  return Profile(
    id: real.id,
    displayName: recordingName(real.id, real.displayName),
    whatsapp: real.whatsapp.isEmpty ? '' : person.phone,
    statusText: '',
    address: real.address.isEmpty
        ? ''
        : '${person.street}\n${person.postalCode} ${person.city}',
    countryCode: real.countryCode,
    vatId: real.vatId.isEmpty ? '' : 'FR00${_fnv1a(real.id, 6) % 1000000000}',
    lastSeenAt: real.lastSeenAt,
    avatarPath: null,
    preferredLocale: real.preferredLocale,
    formatPrefs: real.formatPrefs,
    privacyAcceptedVersion: real.privacyAcceptedVersion,
    privacyAcceptedAt: real.privacyAcceptedAt,
    identity: recordingIdentity(real.id, real.identity),
    system: real.system,
  );
}
