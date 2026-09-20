// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../instance/schema_compatibility.dart';
import '../trace/trace_logger.dart';

part 'schema_version.g.dart';

/// #1312 — the question could not be asked: no network, a timeout, a
/// client that does not exist. Distinct from an ANSWER that the function
/// is missing, which is a real result.
class SchemaVersionUnavailable implements Exception {
  const SchemaVersionUnavailable(this.cause);
  final Object cause;
  @override
  String toString() => 'schema version unavailable: $cause';
}

/// Reads `deskilo_schema_version()` from a server.
abstract interface class SchemaVersionSource {
  /// The server's marker, or null when the server has no such function —
  /// it predates migration 0226. Throws [SchemaVersionUnavailable] when
  /// nothing answered.
  Future<int?> read();
}

/// Whether a PostgREST answer means "this function does not exist here".
bool isMissingFunction(PostgrestException e) =>
    e.code == 'PGRST202' ||
    e.code == '42883' ||
    e.message.toLowerCase().contains('could not find the function');

/// Asks [client] — the app's own, or a throwaway probe client.
Future<int?> readSchemaVersion(SupabaseClient client) async {
  try {
    final value = await client
        .rpc<Object?>('deskilo_schema_version')
        .timeout(const Duration(seconds: 8));
    return value is int ? value : int.tryParse('$value');
  } on PostgrestException catch (e, st) {
    if (isMissingFunction(e)) return null;
    // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
    Error.throwWithStackTrace(SchemaVersionUnavailable(e), st);
  } catch (e, st) {
    // trace-exempt: rethrown as a typed failure, stack kept; the caller traces.
    Error.throwWithStackTrace(SchemaVersionUnavailable(e), st);
  }
}

class SupabaseSchemaVersionSource implements SchemaVersionSource {
  const SupabaseSchemaVersionSource();

  @override
  Future<int?> read() async {
    final SupabaseClient client;
    try {
      client = Supabase.instance.client;
    } catch (e, st) {
      // trace-exempt: no client means no answer, stack kept; the caller traces.
      Error.throwWithStackTrace(SchemaVersionUnavailable(e), st);
    }
    return readSchemaVersion(client);
  }
}

@Riverpod(keepAlive: true)
SchemaVersionSource schemaVersionSource(Ref ref) =>
    const SupabaseSchemaVersionSource();

/// How this device's server compares with this build — asked once per
/// process, like the endpoint itself, which only changes at the next start.
///
/// Fails OPEN on silence: [SchemaCompatibility.unknown] never blocks, so
/// an offline start behaves exactly as it did before the gate existed.
@Riverpod(keepAlive: true)
Future<SchemaCompatibility> schemaCompatibility(Ref ref) async {
  try {
    final server = await ref.read(schemaVersionSourceProvider).read();
    final result = compareSchema(server);
    if (result != SchemaCompatibility.current) {
      TraceLogger.instance.warn(
        'backend',
        'schema $result: server ${server ?? 'has no marker'}, '
            'app needs $requiredSchemaVersion',
      );
    }
    return result;
  } on SchemaVersionUnavailable catch (e, st) {
    TraceLogger.instance.warn(
      'backend',
      'schema version could not be read — not blocking',
      error: e,
      stackTrace: st,
    );
    return SchemaCompatibility.unknown;
  }
}
