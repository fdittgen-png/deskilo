// SPDX-License-Identifier: AGPL-3.0-or-later
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
const int requiredSchemaVersion = 940;

/// #3729 (K2) — the schema this build CANNOT WORK without: below it an
/// installation is told to update. [requiredSchemaVersion] only says what
/// this build was made against, and moves with every migration; this one
/// moves only with a change the app cannot work without, and every move
/// carries its reason in [appNeedsHistory]. A feature may need more still
/// (`FeatureManifestEntry.since`); it never needs less than this.
const int appNeedsSchemaVersion = 934;

/// Every value [appNeedsSchemaVersion] took, oldest first, each with the one
/// line that says why the app cannot work below it. Pinned by
/// `test/lint/schema_needs_pin_test.dart`: the last entry is the constant,
/// and it is never above [requiredSchemaVersion].
const List<({int number, String reason})> appNeedsHistory = [
  (
    number: 934,
    reason: 'the baseline of the split (#3729): the schema this app was '
        'built against when "needs at least" was introduced; no older '
        'schema has been proven to work, so none is claimed',
  ),
];

/// How a server's schema compares with what this app needs.
enum SchemaCompatibility {
  /// The server runs a schema this app can work with: at least what it
  /// needs ([appNeedsSchemaVersion]) and not newer than what it was built
  /// against. Since #3729 this includes an older but sufficient server; what
  /// a single feature needs is judged by its own number, never by this word.
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
/// when the server has no such function — with what the app [needs] and
/// what it was built against ([required]).
///
/// A missing function is `behind`, not `unknown`: the server ANSWERED, and
/// what it said is that it predates 0226.
SchemaCompatibility compareSchema(
  int? server, {
  int required = requiredSchemaVersion,
  int needs = appNeedsSchemaVersion,
}) {
  // What the app needs is never above what it was built against.
  if (server == null || server < (needs < required ? needs : required)) return SchemaCompatibility.behind;
  if (server > required) return SchemaCompatibility.ahead;
  return SchemaCompatibility.current;
}
