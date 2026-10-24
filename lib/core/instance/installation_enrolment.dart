// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2562 C2a -- a personal home's operator enrols a workspace installation.
//
// The facts recorded at the home are READ, never typed: the installation
// id, roles and capability versions come from the workspace project's own
// database (`installation_id()`, `public_network_descriptor()`), and its
// origin and publishable key from the Management API. An installation that
// is not a workspace host, or that is the home itself, is refused before
// anything is written. The write is one call of the home's operator
// function `operator_enrol_installation` (SECURITY DEFINER, reachable only
// through the Management API), which validates everything again and audits
// the change. The CLI (`tool/instance.dart enrol`) and the instance wizard
// both drive this class; neither prints or stores a secret.
import 'dart:convert';

import 'instance_builder.dart';
import 'management_api.dart';

/// Why an enrolment was refused before anything was written.
enum EnrolmentRefusal {
  /// The candidate's database does not answer as a Deskilo installation.
  notAnInstallation,

  /// The candidate does not host workspaces (`workspace_host`, `workspace@1`).
  notAWorkspaceHost,

  /// The home does not hold the `personal_home` role.
  notAPersonalHome,

  /// The candidate and the home are one installation.
  sameInstallation,
}

/// A typed refusal; [message] is the operator-facing English of the CLI.
class EnrolmentRefused implements Exception {
  const EnrolmentRefused(this.reason, this.message);
  final EnrolmentRefusal reason;
  final String message;
  @override
  String toString() => 'EnrolmentRefused(${reason.name}): $message';
}

/// What the home records about a workspace installation, as inspected.
class EnrolmentCandidate {
  const EnrolmentCandidate({
    required this.installationId,
    required this.origin,
    required this.publishableKey,
    required this.roles,
    required this.capabilities,
  });
  final String installationId;
  final String origin;
  final String publishableKey;
  final List<String> roles;
  final List<String> capabilities;
}

/// One row of the home's enrolments.
class EnrolledInstallation {
  const EnrolledInstallation({
    required this.installationId,
    required this.origin,
    required this.acceptingNewWorkspaces,
    required this.enabled,
  });
  final String installationId;
  final String origin;
  final bool acceptingNewWorkspaces;
  final bool enabled;
}

/// The result of an enrol or revoke call: what the home now says.
typedef EnrolmentOutcome = ({
  String installationId,
  String status,
  bool unchanged,
});

final _uuid = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$',
);

/// Whether [value] is an installation id (a lower-case UUID).
bool isInstallationId(String value) => _uuid.hasMatch(value);

String _literal(String s) => "'${s.replaceAll("'", "''")}'";

String _array(List<String> values) =>
    'array[${values.map(_literal).join(', ')}]::text[]';

class InstallationEnrolment {
  const InstallationEnrolment(this.api);

  final SupabaseManagement api;

  Future<({String id, List<String> roles, List<String> capabilities})>
  _identity(String ref) async {
    final List<Map<String, Object?>> rows;
    try {
      rows = await api.query(ref, '''
select public.installation_id()::text as id,
       public.public_network_descriptor()::text as descriptor''');
    } on ManagementApiException catch (e, st) {
      if (e.unauthorized) rethrow;
      Error.throwWithStackTrace(
        EnrolmentRefused(
          EnrolmentRefusal.notAnInstallation,
          '$ref does not answer as a Deskilo installation: ${e.message}',
        ),
        st,
      );
    }
    final id = rows.length == 1 ? '${rows.single['id']}' : '';
    final descriptor = rows.length == 1 ? rows.single['descriptor'] : null;
    final decoded = descriptor is String ? jsonDecode(descriptor) : descriptor;
    if (!_uuid.hasMatch(id) || decoded is! Map) {
      throw EnrolmentRefused(
        EnrolmentRefusal.notAnInstallation,
        '$ref does not answer as a Deskilo installation',
      );
    }
    List<String> strings(Object? v) => v is List
        ? [
            for (final x in v)
              if (x is String) x,
          ]
        : const [];
    return (
      id: id,
      roles: strings(decoded['roles']),
      capabilities: strings(decoded['role_capabilities']),
    );
  }

  /// Reads the workspace project [workspaceRef] as the home will record it.
  Future<EnrolmentCandidate> inspect(String workspaceRef) async {
    final identity = await _identity(workspaceRef);
    if (!identity.roles.contains('workspace_host') ||
        !identity.capabilities.contains('workspace@1')) {
      throw EnrolmentRefused(
        EnrolmentRefusal.notAWorkspaceHost,
        '$workspaceRef does not host workspaces (roles: ${identity.roles.join(', ')})',
      );
    }
    final endpoint = await InstanceBuilder(api).endpointOf(workspaceRef);
    return EnrolmentCandidate(
      installationId: identity.id,
      origin: endpoint.url,
      publishableKey: endpoint.key,
      roles: identity.roles,
      capabilities: identity.capabilities,
    );
  }

  /// Checks that [homeRef] is a personal home other than [candidate].
  Future<void> checkHome(String homeRef, EnrolmentCandidate candidate) async {
    final home = await _identity(homeRef);
    if (!home.roles.contains('personal_home')) {
      throw EnrolmentRefused(
        EnrolmentRefusal.notAPersonalHome,
        '$homeRef is not a personal home: it enrols no workspace installation',
      );
    }
    if (home.id == candidate.installationId) {
      throw const EnrolmentRefused(
        EnrolmentRefusal.sameInstallation,
        'an installation does not enrol itself',
      );
    }
  }

  /// Enrols [candidate] at [homeRef]; the home's function decides and audits.
  Future<EnrolmentOutcome> enrol(
    String homeRef,
    EnrolmentCandidate candidate, {
    bool accepting = true,
  }) async {
    await checkHome(homeRef, candidate);
    return _call(
      homeRef,
      'public.operator_enrol_installation('
      '${_literal(candidate.installationId)}::uuid, '
      '${_literal(candidate.origin)}, ${_literal(candidate.publishableKey)}, '
      '${_array(candidate.roles)}, ${_array(candidate.capabilities)}, $accepting)',
    );
  }

  /// Revokes the enrolment of [installationId] at [homeRef].
  Future<EnrolmentOutcome> revoke(String homeRef, String installationId) {
    if (!_uuid.hasMatch(installationId)) {
      throw EnrolmentRefused(
        EnrolmentRefusal.notAnInstallation,
        '$installationId is not an installation id',
      );
    }
    return _call(
      homeRef,
      'public.operator_revoke_installation(${_literal(installationId)}::uuid)',
    );
  }

  /// Every enrolment the home holds, revoked ones included.
  Future<List<EnrolledInstallation>> list(String homeRef) async {
    final rows = await api.query(homeRef, '''
select installation_id::text as id, origin, accepting_new_workspaces as accepting, enabled
  from public.operator_enrolled_installations()''');
    return [
      for (final r in rows)
        EnrolledInstallation(
          installationId: '${r['id']}',
          origin: '${r['origin']}',
          acceptingNewWorkspaces: r['accepting'] == true,
          enabled: r['enabled'] == true,
        ),
    ];
  }

  Future<EnrolmentOutcome> _call(String homeRef, String call) async {
    final rows = await api.query(homeRef, 'select $call::text as result');
    final result = rows.length == 1 ? rows.single['result'] : null;
    final decoded = result is String ? jsonDecode(result) : result;
    if (decoded is! Map) {
      throw const ManagementApiException(
        0,
        'the home answered without a result',
      );
    }
    return (
      installationId: '${decoded['installation_id']}',
      status: '${decoded['status']}',
      unchanged: decoded['unchanged'] == true,
    );
  }
}
