// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L3 -- what the instance wizard declares about the network: the
// installation's roles (0559) and, for a workspace host that is nobody's
// home, the EXPLICIT personal home its people use (9999). Nothing is derived
// from a workspace somebody selected; a personal home is checked before it is
// recorded: an HTTPS origin with a publishable key, an installation that
// advertises the personal_home role and understands `personal@1`, and an
// identity other than the instance being built.
import '../backend/backend_key.dart';

/// #2561 L3 -- an installation as the wizard names it: an origin and its
/// publishable key. Pure Dart, so the CLI that drives the builder never pulls
/// in the app's client libraries.
class PersonalHomeEndpoint {
  const PersonalHomeEndpoint(this.url, this.key);
  final String url;
  final String key;
}

/// [url] as an HTTPS origin (lower case, no path, query or trailing slash),
/// or null when it is not one.
String? _canonicalHomeOrigin(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      !uri.host.contains('.') ||
      uri.userInfo.isNotEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      (uri.path.isNotEmpty && uri.path != '/')) {
    return null;
  }
  return 'https://${uri.host.toLowerCase()}${uri.hasPort ? ':${uri.port}' : ''}';
}

/// The three deployment roles an operator chooses between.
enum InstanceRoleChoice {
  /// Personal home and workspace host: every installation before the split.
  combined(['personal_home', 'workspace_host'], 'unset'),

  /// A personal home only: it hosts people and no workspace.
  personalHome(['personal_home'], 'self'),

  /// A workspace host only: its people's home is another installation.
  workspaceHost(['workspace_host'], 'endpoint');

  const InstanceRoleChoice(this.roles, this.personalHomeKind);

  /// `installation_identity.roles` for this choice.
  final List<String> roles;

  /// The personal-home declaration this choice records.
  final String personalHomeKind;
}

/// The capability a personal home must advertise to be named one.
const _personalHomeCapability = 'personal@1';

/// Why a declaration was refused before anything was written.
enum InstanceNetworkFault {
  /// A workspace host needs a personal home, and none was given.
  homeRequired,

  /// The personal home is not an HTTPS origin with a publishable key.
  homeEndpoint,

  /// The personal home could not be read.
  homeUnreachable,

  /// The installation answering there is not a personal home, or does not
  /// understand `personal@1`.
  homeNotPersonal,

  /// The personal home is the instance being built.
  homeIsThisInstance,
}

class InstanceNetworkRefused implements Exception {
  const InstanceNetworkRefused(this.fault);
  final InstanceNetworkFault fault;
  @override
  String toString() => 'InstanceNetworkRefused(${fault.name})';
}

/// The operator's choice: a role set and, for [InstanceRoleChoice.workspaceHost],
/// the personal home.
class InstanceNetworkChoice {
  const InstanceNetworkChoice(this.role, {this.personalHome});
  final InstanceRoleChoice role;
  final PersonalHomeEndpoint? personalHome;

  /// The endpoint error of [personalHome], or null when it is usable (or not
  /// needed). Pure: the wizard shows it as the person types.
  InstanceNetworkFault? get shapeFault {
    if (role != InstanceRoleChoice.workspaceHost) return null;
    final home = personalHome;
    if (home == null || (home.url.trim().isEmpty && home.key.trim().isEmpty)) {
      return InstanceNetworkFault.homeRequired;
    }
    final kind = classifyBackendKey(home.key);
    return _canonicalHomeOrigin(home.url) != null &&
            (kind == BackendKeyKind.publishable ||
                kind == BackendKeyKind.legacyAnon)
        ? null
        : InstanceNetworkFault.homeEndpoint;
  }
}

/// What a personal home says about itself, read anonymously.
typedef PersonalHomeFacts = ({
  List<String> roles,
  List<String> capabilities,
  String installationId,
});

typedef PersonalHomeProbe = Future<PersonalHomeFacts> Function(
  PersonalHomeEndpoint home,
);

/// Checks [choice] and returns the endpoint to record (canonical), or null
/// when the choice records none. [ownInstallationId] is the instance being
/// built.
Future<PersonalHomeEndpoint?> verifyInstanceNetwork(
  InstanceNetworkChoice choice, {
  required String ownInstallationId,
  required PersonalHomeProbe probe,
}) async {
  if (choice.shapeFault case final fault?) throw InstanceNetworkRefused(fault);
  final home = choice.personalHome;
  if (choice.role != InstanceRoleChoice.workspaceHost || home == null) {
    return null;
  }
  final canonical = PersonalHomeEndpoint(
    _canonicalHomeOrigin(home.url)!,
    home.key.trim(),
  );
  final PersonalHomeFacts facts;
  try {
    facts = await probe(canonical);
  } on Object {
    // trace-exempt: rethrown as the typed refusal the wizard shows.
    throw const InstanceNetworkRefused(InstanceNetworkFault.homeUnreachable);
  }
  if (!facts.roles.contains('personal_home') ||
      !facts.capabilities.contains(_personalHomeCapability)) {
    throw const InstanceNetworkRefused(InstanceNetworkFault.homeNotPersonal);
  }
  if (facts.installationId == ownInstallationId) {
    throw const InstanceNetworkRefused(InstanceNetworkFault.homeIsThisInstance);
  }
  return canonical;
}

String _quote(String s) => "'${s.replaceAll("'", "''")}'";

/// The operator statements that record [choice]: the roles first, then the
/// declaration the roles allow ([home] for a workspace host).
String instanceNetworkSql(
  InstanceNetworkChoice choice,
  PersonalHomeEndpoint? home,
) {
  final roles = choice.role.roles.map(_quote).join(', ');
  final declaration = home == null
      ? _quote(choice.role.personalHomeKind)
      : '${_quote('endpoint')}, ${_quote(home.url)}, ${_quote(home.key)}';
  return 'select public.operator_set_installation_roles(array[$roles]::text[]);\n'
      'select public.operator_set_personal_home($declaration);\n';
}
