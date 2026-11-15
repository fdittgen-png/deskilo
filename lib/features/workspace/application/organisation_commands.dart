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

  Future<OrganisationRefusal?> _run(
    Future<OrganisationRefusal?> command,
  ) async {
    final refused = await command;
    if (refused == null) _changed();
    return refused;
  }
}
