// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2561 L3 -- the personal home an installation names, explicitly.
//
// An installation's `installation_identity` row carries its roles (0559) and
// the personal home it declares (9999): `unset`, `self` or an `endpoint`
// (HTTPS origin + publishable key). A client reads that declaration from the
// installation it booted on and decides from it where the directory source
// list lives. Nothing here derives a personal home from the workspace
// somebody selected last, and a configuration the roles contradict is an
// explicit [PersonalHomeUnavailable], never a quiet fallback.
import 'package:supabase_flutter/supabase_flutter.dart';

import 'backend_settings.dart';

/// What an installation declared about the personal home of its people.
enum PersonalHomeKind {
  /// Nothing declared: a personal home keeps the reference directory.
  unset,

  /// This installation is the personal home and its directory is its own.
  self,

  /// Another installation is the personal home ([PersonalHomeDeclaration.endpoint]).
  endpoint,
}

/// Why no personal home can be used.
enum PersonalHomeFault {
  /// A workspace host that is not a personal home named none.
  missing,

  /// The declaration contradicts the roles: `self` on an installation that
  /// is not a personal home, or another home named by one that is.
  contradictory,

  /// The row could not be read as a declaration (unknown kind, an endpoint
  /// that is not an HTTPS origin with a publishable key).
  invalid,
}

/// The typed refusal: no personal home, and nothing taken in its place.
class PersonalHomeUnavailable implements Exception {
  const PersonalHomeUnavailable(this.fault);
  final PersonalHomeFault fault;
  @override
  String toString() => 'PersonalHomeUnavailable(${fault.name})';
}

/// One installation's roles and personal-home declaration.
class PersonalHomeDeclaration {
  const PersonalHomeDeclaration({
    required this.roles,
    required this.kind,
    this.endpoint,
  });

  /// A server from before the declaration (and before the roles): a
  /// combined installation that declared nothing.
  static const legacy = PersonalHomeDeclaration(
    roles: [],
    kind: PersonalHomeKind.unset,
  );

  /// The row as `installation_identity` answers it. Throws
  /// [PersonalHomeUnavailable] ([PersonalHomeFault.invalid]) for a shape
  /// this client does not know.
  factory PersonalHomeDeclaration.fromRow(Map<String, Object?> row) {
    final rawRoles = row['roles'];
    final roles = rawRoles == null
        ? const <String>[]
        : rawRoles is List
        ? [for (final r in rawRoles) '$r']
        : throw const PersonalHomeUnavailable(PersonalHomeFault.invalid);
    final kind = PersonalHomeKind.values
        .where((k) => k.name == (row['personal_home_kind'] ?? 'unset'))
        .firstOrNull;
    if (kind == null) {
      throw const PersonalHomeUnavailable(PersonalHomeFault.invalid);
    }
    final url = row['personal_home_url'];
    final key = row['personal_home_key'];
    return PersonalHomeDeclaration(
      roles: roles,
      kind: kind,
      endpoint: url is String && key is String
          ? BackendEndpoint(url, key)
          : null,
    );
  }

  /// `personal_home`, `workspace_host`, or both; empty = combined.
  final List<String> roles;
  final PersonalHomeKind kind;
  final BackendEndpoint? endpoint;

  /// Whether this installation is itself a personal home.
  bool get isPersonalHome => roles.isEmpty || roles.contains('personal_home');
}

/// Reads the declaration of the installation [client] talks to. A schema
/// from before the declaration answers [PersonalHomeDeclaration.legacy];
/// every other failure is the caller's to see.
Future<PersonalHomeDeclaration> readPersonalHomeDeclaration(
  SupabaseClient client,
) async {
  try {
    final row = await client
        .from('installation_identity')
        .select(
          'roles, personal_home_kind, personal_home_url, personal_home_key',
        )
        .single();
    return PersonalHomeDeclaration.fromRow(row);
  } on PostgrestException catch (e, st) {
    // trace-exempt: an undefined column is a schema from before 9999;
    // anything else is rethrown unchanged, stack kept.
    if (e.code != '42703') Error.throwWithStackTrace(e, st);
    return PersonalHomeDeclaration.legacy;
  }
}

/// Where the directory source list lives for an installation with
/// [declaration], whose own endpoint is [self]. [reference] is the hosted
/// reference deployment, today's directory for everything that declared
/// nothing.
BackendEndpoint directoryHomeOf(
  PersonalHomeDeclaration declaration, {
  required BackendEndpoint self,
  BackendEndpoint reference = referenceEndpoint,
}) {
  const contradictory = PersonalHomeUnavailable(
    PersonalHomeFault.contradictory,
  );
  switch (declaration.kind) {
    case PersonalHomeKind.unset:
      if (!declaration.isPersonalHome) {
        throw const PersonalHomeUnavailable(PersonalHomeFault.missing);
      }
      return reference;
    case PersonalHomeKind.self:
      if (!declaration.isPersonalHome) throw contradictory;
      return self;
    case PersonalHomeKind.endpoint:
      if (declaration.isPersonalHome) throw contradictory;
      final home = declaration.endpoint;
      if (home == null || validateBackendEndpoint(home.url, home.key) != null) {
        throw const PersonalHomeUnavailable(PersonalHomeFault.invalid);
      }
      return BackendEndpoint(canonicalBackendUrl(home.url)!, home.key);
  }
}
