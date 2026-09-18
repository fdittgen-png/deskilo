// SPDX-License-Identifier: 0BSD
//
// #1312 — does the server this app talks to run a schema the app can use?
//
// Pure Dart: the CLI, the doctor and the app ask the same question with
// the same arithmetic.

/// The schema this build of the app needs: the number of the last
/// migration in `supabase/migrations`, which is also the last entry of the
/// instance bundle it installs.
///
/// Pinned to the migration directory by
/// `test/lint/migration_version_marker_test.dart`, so a migration cannot
/// land without the app saying it needs it.
const int requiredSchemaVersion = 245;

/// How a server's schema compares with what this app needs.
enum SchemaCompatibility {
  /// The server runs exactly this app's schema.
  current,

  /// The server is older than this app, or predates the version marker.
  /// A newer app on an older schema is not supported (OPERATIONS.md): the
  /// first screen reading a missing column fails, and says nothing useful.
  behind,

  /// The server is newer. Supported: an older app ignores what it does not
  /// know.
  ahead,

  /// The question could not be asked — offline, a timeout. Never blocks:
  /// a train tunnel is not a schema failure.
  unknown,
}

/// Compares [server] — the value of `deskilo_schema_version()`, or null
/// when the server has no such function — with [required].
///
/// A missing function is `behind`, not `unknown`: the server ANSWERED, and
/// what it said is that it predates 0226.
SchemaCompatibility compareSchema(int? server, {int required = requiredSchemaVersion}) {
  if (server == null || server < required) return SchemaCompatibility.behind;
  if (server > required) return SchemaCompatibility.ahead;
  return SchemaCompatibility.current;
}
