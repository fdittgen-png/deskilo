// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3832 — Zurich (Switzerland, francs) and Milan (Italy, euros): two small
// coworking businesses whose story is buying and selling. Each is one
// [DemoTradeCity]: the facts of the business, from which its workspace row,
// its people, its sites, its sales invoices and its purchase documents are
// all derived, so a figure on a screen can be recomputed from these facts.
//
// Synthetic throughout: the names, streets and e-mail addresses are
// invented (`example.test` is reserved and reaches nobody).
import '../../../features/workspace/domain/member.dart';
import '../../../features/workspace/domain/site.dart';
import '../../../features/workspace/domain/workspace.dart';
import '../../../features/workspace/domain/workspace_permission.dart';
import '../data/workspace_repository.dart';
import '../demo_dataset.dart';
import '../demo_space_ids.dart';
import 'demo_city_people_seed.dart';
import 'demo_flags.dart';

export '../demo_space_ids.dart' show demoMilanSpaceId, demoZurichSpaceId;

/// One of the trade cities: everything that tells Zurich from Milan.
class DemoTradeCity {
  const DemoTradeCity({
    required this.id,
    required this.prefix,
    required this.name,
    required this.countryCode,
    required this.currency,
    required this.timezone,
    required this.city,
    required this.street,
    required this.postalCode,
    required this.inviteCode,
    required this.vatPercent,
    required this.siteNames,
    required this.vendorStem,
    required this.foreignCurrency,
    required this.foreignCountry,
    required this.foreignRate,
    required this.nameOffset,
    required this.seedColor,
    required this.symbol,
  });

  final String id, prefix, name, countryCode, currency, timezone;
  final String city, street, postalCode, inviteCode;

  /// The standard rate its invoices and purchase lines carry, in percent.
  final double vatPercent;

  /// The names of its sites; the first is the main one.
  final List<String> siteNames;

  /// What its suppliers are called after ("Limmat Vending Rentals (Demo)").
  final String vendorStem;

  /// The currency of the supplier bill that is NOT in the space's currency,
  /// the country of the supplier abroad, and the demo rate it was entered at (units of [currency] per unit of
  /// [foreignCurrency]); a decimal string, never a double.
  final String foreignCurrency, foreignCountry, foreignRate;

  /// Where the locals' names start in the shared list of invented names.
  final int nameOffset;
  final String seedColor, symbol;

  List<String> get siteIds => [
    for (var i = 0; i < siteNames.length; i++) '$prefix-site-$i',
  ];

  /// How many years of history the trade cities hold: businesses two years
  /// old, short enough to be built with every session.
  static const years = 2;

  /// The members of the demo's cast who work here, besides its locals.
  static const castHere = 5;

  /// How many people of this city are not in the cast. The daily booking
  /// history gives each seat of a day to a different person, so a city holds
  /// more full-time people than its plan holds seat entries.
  static const locals = 16;

  Workspace workspace() => Workspace(
    id: id,
    name: name,
    countryCode: countryCode,
    currencyCode: currency,
    timezone: timezone,
    inviteCode: inviteCode,
    environment: 'prod',
    rolePermissions: everydayMatrix(),
    featureFlags: demoOtherSpacesFeatureFlags,
    address: '$street\n$postalCode $city',
    street: street,
    city: city,
    postalCode: postalCode,
    branding: {
      'seed_color': seedColor,
      'pattern': 'dots',
      'symbol_text': symbol,
    },
  );

  /// The cast: Ada owns it, Chiara runs the day, Bruno, Dov and Elise are
  /// members — Dov and Elise are active here although their membership in
  /// the main space is pending and paused. The kiosk is a device, not a
  /// person, and holds no membership in a trade city.
  void seedPeople(FakeWorkspaceRepository space) {
    Member cast(DemoPerson p, {bool owner = false, bool admin = false}) =>
        Member(
          id: p.memberId,
          workspaceId: id,
          userId: p.userId,
          isAdmin: admin,
          isOwner: owner,
          status: MemberStatus.active,
          subscriptionPct: p.subscriptionPct,
        );
    final people = demoCast.take(castHere).toList();
    final members = [
      cast(people[0], owner: true, admin: true),
      cast(people[1]),
      cast(people[2], admin: true),
      cast(people[3]),
      cast(people[4]),
    ];
    space.myMember = members.first;
    space.otherMembers.addAll(members.skip(1));
    for (final person in people) {
      space.memberNames[person.memberId] = person.name;
      space.memberEmails[person.memberId] = person.email;
    }
    final ids = siteIds;
    for (var i = 0; i < locals; i++) {
      final memberId = '$prefix-member-${i + 1}';
      space.otherMembers.add(
        Member(
          id: memberId,
          workspaceId: id,
          userId: '$prefix-user-${i + 1}',
          isAdmin: false,
          isOwner: false,
          status: MemberStatus.active,
          homeSiteId: ids[i % ids.length],
        ),
      );
      space.memberNames[memberId] = demoCityPersonName(nameOffset + i);
      space.memberEmails[memberId] = '$prefix.member${i + 1}@example.test';
    }
    space.sites.addAll([
      for (final (i, siteName) in siteNames.indexed)
        Site(
          id: ids[i],
          workspaceId: id,
          name: siteName,
          city: city,
          countryCode: countryCode,
          isDefault: i == 0,
          sortOrder: i,
        ),
    ]);
  }
}

const demoZurich = DemoTradeCity(
  id: demoZurichSpaceId,
  prefix: 'ch',
  name: 'Limmat Cowork Zurich',
  countryCode: 'CH',
  currency: 'CHF',
  timezone: 'Europe/Zurich',
  city: 'Zurich',
  street: '10 Beispielstrasse',
  postalCode: '8001',
  inviteCode: 'LIMMATDEMO',
  vatPercent: 8.1,
  siteNames: ['Limmat House', 'Oerlikon Studio'],
  vendorStem: 'Limmat',
  foreignCurrency: 'EUR',
  foreignCountry: 'DE',
  foreignRate: '0.9383',
  nameOffset: 40,
  seedColor: '#B91C1C',
  symbol: 'LC',
);

const demoMilan = DemoTradeCity(
  id: demoMilanSpaceId,
  prefix: 'it',
  name: 'Navigli Coworking Milano',
  countryCode: 'IT',
  currency: 'EUR',
  timezone: 'Europe/Rome',
  city: 'Milano',
  street: 'Via Esempio 10',
  postalCode: '20121',
  inviteCode: 'NAVIGLIDEMO',
  vatPercent: 22,
  siteNames: ['Navigli Hall', 'Isola Studio'],
  vendorStem: 'Navigli',
  foreignCurrency: 'CHF',
  foreignCountry: 'CH',
  foreignRate: '1.0657',
  nameOffset: 80,
  seedColor: '#15803D',
  symbol: 'NC',
);
