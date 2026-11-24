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

import '../instance/schema_compatibility.dart';
import '../lifecycle/app_foreground.dart';
import '../trace/trace_logger.dart';
import 'context_client_providers.dart';
import 'context_clients.dart';
import 'schema_version.dart';

part 'installation_schema.g.dart';

/// What an installation answered about its schema.
class InstallationSchema {
  /// An answer: [number] is the marker, or null for a server that has no
  /// `deskilo_schema_version()` — it predates 0226.
  const InstallationSchema.answered(this.number) : answered = true;

  /// Nothing answered yet, or ever: offline, a timeout, a host that could not
  /// be reached. Never a block.
  const InstallationSchema.unknown() : number = null, answered = false;

  final int? number;
  final bool answered;

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
      other.number == number;

  @override
  int get hashCode => Object.hash(answered, number);
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

/// Reads the schema number of the installation that hosts a workspace.
abstract interface class InstallationSchemaSource {
  /// The installation's id and its marker (null: no such function). Throws
  /// [InstallationSchemaUnavailable] when nothing answered.
  Future<({String installationId, int? number})> read(String workspaceId);
}

class _HostedInstallationSchemaSource implements InstallationSchemaSource {
  const _HostedInstallationSchemaSource(this._ref);
  final Ref _ref;

  @override
  Future<({String installationId, int? number})> read(
    String workspaceId,
  ) async {
    final ResolvedWorkspaceHost host;
    try {
      host = await _ref.read(workspaceHostResolverProvider).resolve(workspaceId);
    } on Object catch (e, st) {
      // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
      Error.throwWithStackTrace(InstallationSchemaUnavailable(e), st);
    }
    try {
      final number = await readSchemaVersion(host.client);
      return (installationId: host.installationId, number: number);
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
    final schema = InstallationSchema.answered(answer.number);
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
