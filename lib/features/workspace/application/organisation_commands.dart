// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4006 — the owners' commands on an organisation, as the organisation's
// page asks for them: each answers null once done (and the organisations
// are read again), else why the server did not change it.
import '../domain/organisation.dart';

class OrganisationCommands {
  const OrganisationCommands(this._repository, this._changed);

  final OrganisationRepository _repository;

  /// Called once a command changed an organisation.
  final void Function() _changed;

  Future<OrganisationRefusal?> create(String headWorkspaceId, String name) =>
      _run(_repository.create(headWorkspaceId, name.trim()));

  Future<OrganisationRefusal?> rename(String organisationId, String name) =>
      _run(_repository.rename(organisationId, name.trim()));

  Future<OrganisationRefusal?> add(String organisationId, String workspaceId) =>
      _run(_repository.add(organisationId, workspaceId));

  Future<OrganisationRefusal?> remove(String workspaceId) =>
      _run(_repository.remove(workspaceId));

  Future<OrganisationRefusal?> setHead(
    String organisationId,
    String headWorkspaceId,
  ) => _run(_repository.setHead(organisationId, headWorkspaceId));

  /// #4005 — makes a house abroad; the organisations and the person's
  /// businesses are read again once it exists.
  Future<({String? workspaceId, OrganisationRefusal? refused})> createHouse(
    HouseRequest request,
  ) async {
    final answer = await _repository.createHouse(request);
    if (answer.refused == null) _changed();
    return answer;
  }

  /// The birth record of [workspaceId], if it was made as a house.
  Future<HouseBirth?> houseBirth(String workspaceId) =>
      _repository.houseBirth(workspaceId);

  Future<OrganisationRefusal?> _run(
    Future<OrganisationRefusal?> command,
  ) async {
    final refused = await command;
    if (refused == null) _changed();
    return refused;
  }
}
