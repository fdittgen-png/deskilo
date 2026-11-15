// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — a customer's businesses as one organisation (decision 0052): one
// head and its houses, each a business of its own with its country's rules
// and its currency. The reader sees only the houses they are an active
// member of, each with their role there; no right flows from one house to
// another.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

import '../../../core/text/collation.dart';
import 'workspace.dart';

/// The reader's role in one house.
enum HouseRole {
  owner('owner'),
  coOwner('co_owner'),
  admin('admin'),
  member('member');

  const HouseRole(this.wire);

  /// The server's word for it.
  final String wire;

  /// The role [wire] names; a word this app does not know reads as member,
  /// the role with the least rights.
  static HouseRole of(String? wire) =>
      values.where((r) => r.wire == wire).firstOrNull ?? member;
}

/// One house of an organisation, as the reader is a member of it.
class OrganisationHouse {
  const OrganisationHouse({
    required this.workspaceId,
    required this.name,
    required this.countryCode,
    required this.currencyCode,
    required this.role,
  });

  factory OrganisationHouse.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'organisation house');
    return OrganisationHouse(
      workspaceId: row.string('workspace_id'),
      name: row.stringOr('name'),
      countryCode: row.stringOr('country_code'),
      currencyCode: row.stringOr('currency_code'),
      role: HouseRole.of(row.stringOrNull('role')),
    );
  }

  final String workspaceId;
  final String name;
  final String countryCode;
  final String currencyCode;
  final HouseRole role;
}

/// An organisation: its name, its head business and the houses the reader
/// is a member of, the head first.
class Organisation {
  const Organisation({
    required this.id,
    required this.name,
    required this.headWorkspaceId,
    required this.houses,
  });

  factory Organisation.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'organisation');
    return Organisation(
      id: row.string('id'),
      name: row.stringOr('name'),
      headWorkspaceId: row.string('head_workspace_id'),
      houses: [
        for (final house in row.listOrAbsent('houses'))
          OrganisationHouse.fromJson(house),
      ],
    );
  }

  final String id;
  final String name;
  final String headWorkspaceId;
  final List<OrganisationHouse> houses;

  /// The house of [workspaceId], or none when it is not one of these.
  OrganisationHouse? houseOf(String workspaceId) =>
      houses.where((h) => h.workspaceId == workspaceId).firstOrNull;

  /// The houses as Me lists them: the head first, then by country, then
  /// by name.
  List<OrganisationHouse> get byCountry => [
    ...houses.where((h) => h.workspaceId == headWorkspaceId),
    ...houses.where((h) => h.workspaceId != headWorkspaceId).toList()..sort(
      (a, b) => switch (a.countryCode.compareTo(b.countryCode)) {
        0 => compareNames(a.name, b.name),
        final c => c,
      },
    ),
  ];

  /// The other houses of the organisation [workspaceId] is a house of, as
  /// the chip offers them; none when it is in no organisation of [all].
  static List<OrganisationHouse> othersOf(
    List<Organisation> all,
    String workspaceId,
  ) {
    for (final organisation in all) {
      if (organisation.houseOf(workspaceId) == null) continue;
      return [
        for (final house in organisation.byCountry)
          if (house.workspaceId != workspaceId) house,
      ];
    }
    return const [];
  }
}

/// #4006 — the houses of [houses] in the environment of [current]: on the
/// server a business and its development twin are two houses; to the
/// person they are one. A house not among [spaces] (not read yet) stays.
List<OrganisationHouse> housesInEnvironment(
  Iterable<OrganisationHouse> houses,
  Workspace current,
  Map<String, Workspace> spaces,
) => [
  for (final house in houses)
    if ((spaces[house.workspaceId]?.env ?? current.env) == current.env) house,
];

/// Why the server did not change an organisation.
enum OrganisationRefusal {
  /// Only an owner of the business (and of the head) may do this.
  notOwner,

  /// An organisation needs a name.
  noName,

  /// The business is already in an organisation.
  alreadyInOne,

  /// The business is in no organisation.
  inNone,

  /// The head leaves last.
  headLeavesLast,

  /// The new head is not a house of this organisation.
  notAHouse,

  /// A development twin is never the head.
  twinNeverHead,

  /// The organisation is off in this business (its feature).
  featureOff,

  /// #4005 — the documents do not speak that language.
  language,

  /// #4005 — this request already made another business.
  requestUsed,

  /// #4005 — the Demo adds one house abroad, in its own country and
  /// currency, and says which.
  demoOneHouse,

  /// #4008 — only a member of a house of the organisation asks another.
  notAMember,

  /// #4008 — a person asks; an assistant's token does not.
  onlyAPerson,

  /// #4008 — the business is no house of an organisation.
  noHouse,

  /// Anything else the server said no to.
  other,
}

/// The organisations of the reader, and the owners' commands on them
/// (#4004). Each command answers null once done, else why not.
abstract interface class OrganisationRepository {
  /// Every organisation the reader is a member of a house of, by name.
  Future<List<Organisation>> myOrganisations();

  /// Makes [headWorkspaceId] the head of a new organisation named [name].
  Future<OrganisationRefusal?> create(String headWorkspaceId, String name);

  /// Renames [organisationId].
  Future<OrganisationRefusal?> rename(String organisationId, String name);

  /// Makes the business [workspaceId] a house of [organisationId].
  Future<OrganisationRefusal?> add(String organisationId, String workspaceId);

  /// Takes the business [workspaceId] out of its organisation.
  Future<OrganisationRefusal?> remove(String workspaceId);

  /// Makes the house [headWorkspaceId] the head of [organisationId].
  Future<OrganisationRefusal?> setHead(
    String organisationId,
    String headWorkspaceId,
  );

  /// #4005 — creates a house abroad of [request]'s organisation, carrying
  /// the head's configuration; the same request answers the same house.
  Future<({String? workspaceId, OrganisationRefusal? refused})> createHouse(
    HouseRequest request,
  );

  /// #4005 — the birth record of [workspaceId], or none when it was not
  /// created as a house.
  Future<HouseBirth?> houseBirth(String workspaceId);

  /// #4005 — the house [workspaceId]'s prices are named: its first task
  /// closes.
  Future<OrganisationRefusal?> clearPricesPending(String workspaceId);

  /// #4008 — the houses of the reader's organisations they are not a member
  /// of, and whether they asked.
  Future<List<JoinableHouse>> joinableHouses();

  /// #4008 — asks the house [workspaceId] to take the reader, who is a
  /// member of another house of its organisation.
  Future<({HouseJoin? joined, OrganisationRefusal? refused})> askToJoin(
    String workspaceId,
  );

  /// #4008 — whether the house [workspaceId] of [organisationId] welcomes
  /// the members of the organisation's other houses at once.
  Future<bool> welcomesMembers(String organisationId, String workspaceId);

  /// #4008 — the house [workspaceId]'s owner says whether it welcomes the
  /// members of the other houses at once.
  Future<OrganisationRefusal?> setWelcome(String workspaceId, {required bool on});
}

/// #4008 — what asking a house answered: a member there at once (the house
/// welcomes the organisation's members), or a request the house decides.
enum HouseJoin {
  member,
  asked;

  /// From the member status the server answers.
  static HouseJoin of(String? status) =>
      status == 'active' || status == 'paused' ? member : asked;
}

/// #4008 — a house of one of the reader's organisations they are not a
/// member of: its country and currency, whether the reader asked it, and
/// whether it welcomes the members of the other houses at once.
class JoinableHouse {
  const JoinableHouse({
    required this.organisationId,
    required this.organisationName,
    required this.workspaceId,
    required this.name,
    required this.countryCode,
    required this.currencyCode,
    this.asked = false,
    this.welcome = false,
  });

  factory JoinableHouse.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'joinable house');
    return JoinableHouse(
      organisationId: row.string('organisation_id'),
      organisationName: row.stringOr('organisation_name'),
      workspaceId: row.string('workspace_id'),
      name: row.stringOr('name'),
      countryCode: row.stringOr('country_code'),
      currencyCode: row.stringOr('currency_code'),
      asked: row.stringOrNull('request') == 'pending',
      welcome: row.isTrue('welcome'),
    );
  }

  final String organisationId;
  final String organisationName;
  final String workspaceId;
  final String name;
  final String countryCode;
  final String currencyCode;
  final bool asked;
  final bool welcome;

  /// The same house, asked.
  JoinableHouse askedNow() => JoinableHouse(
    organisationId: organisationId,
    organisationName: organisationName,
    workspaceId: workspaceId,
    name: name,
    countryCode: countryCode,
    currencyCode: currencyCode,
    asked: true,
    welcome: welcome,
  );
}

/// #4005 — a house abroad to create: its name, country, currency, time zone
/// and document language, and the request id one opened form keeps.
typedef HouseRequest = ({
  String organisationId,
  String name,
  String country,
  String currency,
  String timezone,
  String language,
  String requestId,
});

/// #4005 — where a house came from and what came with it: the counts of
/// what was carried (priced rows inactive, to be priced), whether the
/// amounts were kept (the same currency), the head's owners added as
/// co-owners, and whether its prices are still to be named.
class HouseBirth {
  const HouseBirth({
    required this.workspaceId,
    required this.headWorkspaceId,
    required this.plans,
    required this.services,
    required this.packages,
    required this.validationPolicies,
    required this.features,
    required this.amountsKept,
    required this.coOwnersAdded,
    required this.pricesPending,
    this.createdAt,
    this.rateHints = const {},
  });

  factory HouseBirth.fromJson(Object? raw) {
    final row = JsonReader.of(raw, context: 'organisation house');
    final carried = row.objectOrAbsent('carried');
    return HouseBirth(
      workspaceId: row.string('workspace_id'),
      headWorkspaceId: row.stringOrNull('head_workspace_id'),
      plans: carried.intOrAbsent('plans') ?? 0,
      services: carried.intOrAbsent('services') ?? 0,
      packages: carried.intOrAbsent('packages') ?? 0,
      validationPolicies: carried.intOrAbsent('validation_policies') ?? 0,
      features: carried.intOrAbsent('features') ?? 0,
      amountsKept: carried.isTrue('amounts_kept'),
      coOwnersAdded: row.listOrAbsent('co_owners_added').length,
      pricesPending: row.isTrue('prices_pending'),
      createdAt: row.dateTimeOrNull('created_at'),
      rateHints: {
        for (final MapEntry(:key, :value)
            in carried.objectOrAbsent('rate_hints').json.entries)
          if (value is String) key: value,
      },
    );
  }

  final String workspaceId;

  /// The head it was created from; none once that business is gone.
  final String? headWorkspaceId;
  final int plans, services, packages, validationPolicies, features;
  final bool amountsKept;
  final int coOwnersAdded;
  final bool pricesPending;
  final DateTime? createdAt;

  /// #4005 — the head's rate category per carried priced row, keyed
  /// `<table>:<name>` (`services:Coffee`): the EN 16931 code (S, Z, E, O).
  final Map<String, String> rateHints;
}
