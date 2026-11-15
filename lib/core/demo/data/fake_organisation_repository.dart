// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the Demo's organisations: the ones it was given, none by default
// (the Demo's reference organisation is seeded by #4009), with the server's
// rules for the owners' commands: a name is needed, a business is in one
// organisation at most, and the head leaves last.
import '../../../features/workspace/domain/organisation.dart';

class FakeOrganisationRepository implements OrganisationRepository {
  /// [businesses] are the reader's businesses that may become houses, as
  /// the houses they would be.
  FakeOrganisationRepository({
    List<Organisation> organisations = const [],
    List<OrganisationHouse> businesses = const [],
  }) : _organisations = List.of(organisations),
       _businesses = {for (final b in businesses) b.workspaceId: b};

  final List<Organisation> _organisations;
  final Map<String, OrganisationHouse> _businesses;
  int _next = 0;

  @override
  Future<List<Organisation>> myOrganisations() async =>
      List.unmodifiable(_organisations);

  int _indexOf(String organisationId) =>
      _organisations.indexWhere((o) => o.id == organisationId);

  int _holding(String workspaceId) =>
      _organisations.indexWhere((o) => o.houseOf(workspaceId) != null);

  Organisation _with(
    Organisation o, {
    String? name,
    List<OrganisationHouse>? houses,
  }) => Organisation(
    id: o.id,
    name: name ?? o.name,
    headWorkspaceId: o.headWorkspaceId,
    houses: houses ?? o.houses,
  );

  @override
  Future<OrganisationRefusal?> create(
    String headWorkspaceId,
    String name,
  ) async {
    if (name.trim().isEmpty) return OrganisationRefusal.noName;
    if (_holding(headWorkspaceId) >= 0) return OrganisationRefusal.alreadyInOne;
    final head = _businesses[headWorkspaceId];
    if (head == null || head.role != HouseRole.owner) {
      return OrganisationRefusal.notOwner;
    }
    _organisations.add(
      Organisation(
        id: 'demo-organisation-${_next++}',
        name: name.trim(),
        headWorkspaceId: headWorkspaceId,
        houses: [head],
      ),
    );
    return null;
  }

  @override
  Future<OrganisationRefusal?> rename(
    String organisationId,
    String name,
  ) async {
    if (name.trim().isEmpty) return OrganisationRefusal.noName;
    final i = _indexOf(organisationId);
    if (i < 0) return OrganisationRefusal.notOwner;
    _organisations[i] = _with(_organisations[i], name: name.trim());
    return null;
  }

  @override
  Future<OrganisationRefusal?> add(
    String organisationId,
    String workspaceId,
  ) async {
    final i = _indexOf(organisationId);
    if (i < 0) return OrganisationRefusal.notOwner;
    if (_holding(workspaceId) >= 0) return OrganisationRefusal.alreadyInOne;
    final house = _businesses[workspaceId];
    if (house == null || house.role != HouseRole.owner) {
      return OrganisationRefusal.notOwner;
    }
    final o = _organisations[i];
    _organisations[i] = _with(o, houses: [...o.houses, house]);
    return null;
  }

  @override
  Future<OrganisationRefusal?> remove(String workspaceId) async {
    final i = _holding(workspaceId);
    if (i < 0) return OrganisationRefusal.inNone;
    final o = _organisations[i];
    if (o.headWorkspaceId == workspaceId && o.houses.length > 1) {
      return OrganisationRefusal.headLeavesLast;
    }
    _businesses[workspaceId] = o.houseOf(workspaceId)!;
    final left = [
      for (final h in o.houses)
        if (h.workspaceId != workspaceId) h,
    ];
    if (left.isEmpty) {
      _organisations.removeAt(i);
    } else {
      _organisations[i] = _with(o, houses: left);
    }
    return null;
  }
}
