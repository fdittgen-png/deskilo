// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — a customer's businesses as one organisation (decision 0052): one
// head and its houses, each a business of its own with its country's rules
// and its currency. The reader sees only the houses they are an active
// member of, each with their role there; no right flows from one house to
// another.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

import '../../../core/text/collation.dart';

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

/// The organisations of the reader.
abstract interface class OrganisationRepository {
  /// Every organisation the reader is a member of a house of, by name.
  Future<List<Organisation>> myOrganisations();
}
