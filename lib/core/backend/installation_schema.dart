// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3729 (K2) — the schema number of the installation that hosts a workspace,
// read with THAT installation's own client and kept per installation. The
// personal home's number is `schemaCompatibilityProvider`'s; this is the
// number of a business that may live elsewhere, so one old business neither
// sends the whole account to the update screen nor lends its verdict to
// another.
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show SupabaseClient;

import '../instance/app_compatibility.dart';
import '../instance/schema_compatibility.dart';
import '../lifecycle/app_foreground.dart';
import '../trace/trace_logger.dart';
import 'app_floor.dart';
import 'context_client_providers.dart';
import 'context_clients.dart';
import 'schema_version.dart';

part 'installation_schema.g.dart';

/// What an installation answered about its schema, and how its app floor
/// judges this app.
class InstallationSchema {
  /// An answer: [number] is the marker, or null for a server that has no
  /// `deskilo_schema_version()` — it predates 0226.
  const InstallationSchema.answered(
    this.number, {
    this.floor = AppFloorVerdict.unknown,
  }) : answered = true;

  /// Nothing answered yet, or ever: offline, a timeout, a host that could not
  /// be reached. Never a block.
  const InstallationSchema.unknown()
    : number = null,
      answered = false,
      floor = AppFloorVerdict.unknown;

  final int? number;
  final bool answered;

  /// #3726 — how THIS installation's `deskilo_app_floor()` judges this app:
  /// below it, the installation's workspaces show the app update screen and
  /// the account's pages stay. Unknown (never read) blocks nothing.
  final AppFloorVerdict floor;

  /// Against what this app needs and was built against.
  SchemaCompatibility get verdict =>
      answered ? compareSchema(number) : SchemaCompatibility.unknown;

  /// The number a feature's `since` is compared with: null while it is not
  /// established, 0 for a server without a marker (older than every
  /// migration that matters).
  int? get featureSchema => answered ? (number ?? 0) : null;

  @override
  bool operator ==(Object other) =>
      other is InstallationSchema &&
      other.answered == answered &&
      other.number == number &&
      other.floor == floor;

  @override
  int get hashCode => Object.hash(answered, number, floor);
}

/// The host could not be asked: [installationId] is known once the host
/// identified itself, null when it could not even be reached.
@visibleForTesting
class InstallationSchemaUnavailable implements Exception {
  const InstallationSchemaUnavailable(this.cause, {this.installationId});
  final Object cause;
  final String? installationId;
  @override
  String toString() => 'installation schema unavailable: $cause';
}

/// One answer of the installation hosting a workspace: its id, its schema
/// marker (null: no such function) and how its app floor judges this app
/// ([AppFloorVerdict.unknown] when the floor alone could not be read).
typedef InstallationAnswer = ({
  String installationId,
  int? number,
  AppFloorVerdict floor,
});

/// Reads the schema number and the app floor of the installation that hosts
/// a workspace.
abstract interface class InstallationSchemaSource {
  /// Throws [InstallationSchemaUnavailable] when the schema got no answer.
  Future<InstallationAnswer> read(String workspaceId);
}

class _HostedInstallationSchemaSource implements InstallationSchemaSource {
  const _HostedInstallationSchemaSource(this._ref);
  final Ref _ref;

  @override
  Future<InstallationAnswer> read(String workspaceId) async {
    final ResolvedWorkspaceHost host;
    try {
      host = await _ref.read(workspaceHostResolverProvider).resolve(workspaceId);
    } on Object catch (e, st) {
      // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
      Error.throwWithStackTrace(InstallationSchemaUnavailable(e), st);
    }
    try {
      final number = await readSchemaVersion(host.client);
      return (
        installationId: host.installationId,
        number: number,
        floor: await _floorOf(host.client),
      );
    } on SchemaVersionUnavailable catch (e, st) {
      // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
      Error.throwWithStackTrace(
        InstallationSchemaUnavailable(e, installationId: host.installationId),
        st,
      );
    } finally {
      host.lease?.release();
    }
  }
}

/// The host's floor; one that cannot be read is unknown, never a refusal.
Future<AppFloorVerdict> _floorOf(SupabaseClient client) async {
  try {
    return judgeAppFloor(await readAppFloor(client));
  } on Object catch (e, st) {
    TraceLogger.instance.warn(
      'backend',
      'installation app floor could not be read — not refusing',
      error: e,
      stackTrace: st,
    );
    return AppFloorVerdict.unknown;
  }
}

@Riverpod(keepAlive: true)
InstallationSchemaSource installationSchemaSource(Ref ref) =>
    _HostedInstallationSchemaSource(ref);

/// What each installation last answered, by installation id, for the
/// process: a failed refresh never lends one installation's answer to
/// another, and never erases one's own.
class InstallationSchemaMemory {
  final Map<String, InstallationSchema> _byInstallation = {};

  /// The last answer that said an installation is older than the app needs,
  /// for the update screen to name what it lacks. Not a verdict: the
  /// routes read [workspaceSchemaProvider].
  InstallationSchema? lastBehind;
  InstallationSchema? of(String? installationId) =>
      installationId == null ? null : _byInstallation[installationId];
  void remember(String installationId, InstallationSchema schema) =>
      _byInstallation[installationId] = schema;
}

@Riverpod(keepAlive: true)
InstallationSchemaMemory installationSchemaMemory(Ref ref) =>
    InstallationSchemaMemory();

/// The schema of the installation that hosts [workspaceId].
///
/// - A successful answer decides and is remembered under the installation's
///   id; a host that answers "no marker" is an answer.
/// - A failed read keeps what THAT installation last answered, or is
///   unknown, which withholds nothing.
/// - Asked again each time the app returns to the foreground (an event,
///   never a timer).
@Riverpod(keepAlive: true)
Future<InstallationSchema> workspaceSchema(Ref ref, String workspaceId) async {
  ref.onDispose(onReturnToForeground(ref.invalidateSelf));
  final memory = ref.read(installationSchemaMemoryProvider);
  try {
    final answer = await ref
        .read(installationSchemaSourceProvider)
        .read(workspaceId);
    // A floor that could not be read this time keeps what that
    // installation last said: a known refusal is not reopened by silence.
    final floor = answer.floor == AppFloorVerdict.unknown
        ? memory.of(answer.installationId)?.floor ?? AppFloorVerdict.unknown
        : answer.floor;
    final schema = InstallationSchema.answered(answer.number, floor: floor);
    memory.remember(answer.installationId, schema);
    if (schema.verdict == SchemaCompatibility.behind) {
      memory.lastBehind = schema;
    }
    return schema;
  } on InstallationSchemaUnavailable catch (e, st) {
    TraceLogger.instance.warn(
      'backend',
      'installation schema could not be read — not withholding',
      error: e,
      stackTrace: st,
    );
    return memory.of(e.installationId) ?? const InstallationSchema.unknown();
  }
}
