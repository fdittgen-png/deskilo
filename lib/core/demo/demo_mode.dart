// SPDX-License-Identifier: 0BSD
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/money/domain/invoice.dart';
import '../../features/profile/domain/personal_info.dart';
import '../../features/profile/domain/profile.dart';
import '../storage/prefs_stores.dart';

part 'demo_mode.g.dart';

/// Demo mode (#970): while it is on, everything the screen shows that
/// identifies a person — names, e-mail addresses, phone numbers, postal
/// addresses, company registrations — is replaced by INVENTED but
/// natural-looking values, so a screenshot or a recording of the app
/// carries no personal data and still looks like the app.
///
/// Invented rather than smeared: a blur keeps the shape of the real
/// text (its length, its capitals), looks broken in a recording, and
/// the pixels can be sharpened back. A pseudonym is derived from the
/// real value by a hash, so the same person keeps the same invented
/// name on every screen, and "Camille Dubois" reads as a member, not as
/// a redaction.
///
/// The substitution happens at the DATA layer — in the providers that
/// hand names, profiles, identities and invoices to the widgets — so
/// no screen has to know. The forms that EDIT personal data refuse to
/// open while the mode is on: a form seeded with pseudonyms must never
/// save them over the real thing. Per device, like the theme.
abstract class DemoModeStore {
  Future<String?> read();
  Future<void> write(String? value);
}

class PrefsDemoModeStore extends PrefsStringStore implements DemoModeStore {
  const PrefsDemoModeStore() : super('demo_mode');
}

@Riverpod(keepAlive: true)
DemoModeStore demoModeStore(Ref ref) => const PrefsDemoModeStore();

@Riverpod(keepAlive: true)
class DemoModeController extends _$DemoModeController {
  static const _on = 'on';

  @override
  Future<bool> build() async =>
      await ref.watch(demoModeStoreProvider).read() == _on;

  Future<void> set(bool on) async {
    state = AsyncData(on);
    await ref.read(demoModeStoreProvider).write(on ? _on : null);
  }
}

// ---------------------------------------------------------------------------
// The pseudonyms — pure, deterministic, locale-neutral.
// ---------------------------------------------------------------------------

const _firstNames = [
  'Alex', 'Camille', 'Dominique', 'Sacha', 'Noa', 'Robin', 'Charlie',
  'Andrea', 'Eden', 'Louison', 'Maxime', 'Morgan', 'Sam', 'Lou', 'Kim',
  'Ange', 'Elie', 'Jules', 'Nour', 'Yael', 'Ilan', 'Milan', 'Leo', 'Emma',
];
const _lastNames = [
  'Martin', 'Bernard', 'Dubois', 'Thomas', 'Robert', 'Richard', 'Petit',
  'Durand', 'Leroy', 'Moreau', 'Simon', 'Laurent', 'Lefebvre', 'Michel',
  'Garcia', 'David', 'Bertrand', 'Roux', 'Vincent', 'Fournier', 'Morel',
  'Girard', 'Andre', 'Lefevre',
];
const _streets = [
  'rue des Lilas', 'avenue des Platanes', 'chemin du Moulin',
  'place de la Mairie', 'boulevard des Arts', 'impasse des Oliviers',
];
const _cities = [
  ('34120', 'PÉZENAS'), ('75011', 'PARIS'), ('69001', 'LYON'),
  ('31000', 'TOULOUSE'), ('44000', 'NANTES'), ('67000', 'STRASBOURG'),
];

/// FNV-1a over the trimmed, lower-cased value: the same person, the same
/// number, on every screen and every launch.
int demoSeed(String real) {
  var h = 0x811c9dc5;
  for (final unit in real.trim().toLowerCase().codeUnits) {
    h = ((h ^ unit) * 0x01000193) & 0xffffffff;
  }
  return h;
}

/// The invented first and last name for [real]; empty stays empty.
({String first, String last}) demoNameParts(String real) {
  if (real.trim().isEmpty) return (first: '', last: '');
  final h = demoSeed(real);
  return (
    first: _firstNames[h % _firstNames.length],
    last: _lastNames[(h ~/ _firstNames.length) % _lastNames.length],
  );
}

/// "Camille Dubois" for a real name; '' for ''.
String demoName(String real) {
  final parts = demoNameParts(real);
  return parts.first.isEmpty ? '' : '${parts.first} ${parts.last}';
}

/// The e-mail that goes with an invented name — derived from the
/// PSEUDONYM, so the directory row's name and address agree.
String demoEmailOf(String pseudonym) {
  final parts = pseudonym.trim().toLowerCase().split(RegExp(r'\s+'));
  final local = parts.where((p) => p.isNotEmpty).join('.');
  return local.isEmpty ? '' : '$local@example.org';
}

String demoPhone() => '+33 6 12 34 56 78';

/// An invented street, postal code and city, chosen by [seedSource].
({String street, String postalCode, String city}) demoAddress(
    String seedSource) {
  final h = demoSeed(seedSource);
  final city = _cities[(h ~/ 7) % _cities.length];
  return (
    street: '${h % 90 + 1} ${_streets[h % _streets.length]}',
    postalCode: city.$1,
    city: city.$2,
  );
}

/// The invented postal block, one line per element.
String demoAddressBlock(String seedSource) {
  final a = demoAddress(seedSource);
  return '${a.street}\n${a.postalCode} ${a.city}';
}

/// An invented company for a real one; '' stays ''.
String demoCompany(String real) =>
    real.trim().isEmpty ? '' : 'Société ${demoNameParts(real).last}';

/// A registration/VAT number of the same shape as a real one, all zeros.
String _demoRegistration(String real) =>
    real.trim().isEmpty ? '' : real.replaceAll(RegExp(r'[0-9A-Za-z]'), '0');

Map<String, String> scrubNames(Map<String, String> names) =>
    {for (final e in names.entries) e.key: demoName(e.value)};

PersonalInfo scrubPersonalInfo(PersonalInfo info) {
  if (info.isEmpty) return info;
  final seed = '${info.firstName} ${info.lastName} ${info.company}';
  final name = demoNameParts(seed);
  final address = demoAddress(seed);
  return info.copyWith(
    firstName: info.firstName.isEmpty ? '' : name.first,
    lastName: info.lastName.isEmpty ? '' : name.last,
    company: demoCompany(info.company),
    street: info.street.isEmpty ? '' : address.street,
    postalCode: info.postalCode.isEmpty ? '' : address.postalCode,
    city: info.city.isEmpty ? '' : address.city,
    phone: info.phone.isEmpty ? '' : demoPhone(),
    email: info.email.isEmpty
        ? ''
        : demoEmailOf('${name.first} ${name.last}'),
    vatId: _demoRegistration(info.vatId),
    legalId: _demoRegistration(info.legalId),
  );
}

Profile scrubProfile(Profile profile) => profile.copyWith(
      displayName: demoName(profile.displayName),
      whatsapp: profile.whatsapp.isEmpty ? '' : demoPhone(),
      address: profile.address.isEmpty
          ? ''
          : demoAddressBlock(profile.displayName),
      vatId: _demoRegistration(profile.vatId),
      identity: scrubPersonalInfo(profile.identity),
    );

InvoiceParty scrubParty(InvoiceParty party) {
  final seed = '${party.name} ${party.person} ${party.company}';
  final name = demoNameParts(seed);
  final address = demoAddress(seed);
  final pseudonym = '${name.first} ${name.last}';
  return party.copyWith(
    name: party.name.isEmpty
        ? ''
        : (party.company.isNotEmpty && party.name == party.company
            ? demoCompany(party.company)
            : pseudonym),
    person: party.person.isEmpty ? '' : pseudonym,
    company: demoCompany(party.company),
    street: party.street.isEmpty ? '' : address.street,
    postalCode: party.postalCode.isEmpty ? '' : address.postalCode,
    city: party.city.isEmpty ? '' : address.city,
    email: party.email.isEmpty ? '' : demoEmailOf(pseudonym),
    phone: party.phone.isEmpty ? '' : demoPhone(),
    vatId: _demoRegistration(party.vatId),
    legalId: _demoRegistration(party.legalId),
  );
}

Invoice scrubInvoice(Invoice invoice) => invoice.copyWith(
      memberName: demoName(invoice.memberName),
      memberAddress: invoice.memberAddress.isEmpty
          ? ''
          : demoAddressBlock(invoice.memberName),
      issuerName: demoName(invoice.issuerName),
      voidedByName: demoName(invoice.voidedByName),
      buyerParty: invoice.buyerParty == null
          ? null
          : scrubParty(invoice.buyerParty!),
    );
