// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2472 (P) -- the strict adapter of `my_personal_message_directory_v1`,
// always on the personal home's own client: switching workspaces never
// changes where my directory is read. A refusal the reader raises on
// purpose comes back typed; a missing reader (an older personal home) is
// `unsupported`, the one answer that lets the screen use the per-server
// directory it had before.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/data/json_reader.dart';
import '../domain/personal_message_directory.dart';

/// A typed refusal or any answer of the home itself is final; only a
/// transport failure is tried again, twice and quickly.
Duration? personalDirectoryRetry(int retryCount, Object error) {
  if (retryCount >= 2) return null;
  return switch (error) {
    DirectoryRefused() || PostgrestException() => null,
    _ => Duration(milliseconds: 200 << retryCount),
  };
}

class SupabasePersonalMessageDirectoryRepository
    implements PersonalMessageDirectoryRepository {
  const SupabasePersonalMessageDirectoryRepository(this.personal);

  /// The personal home's client.
  final SupabaseClient personal;

  Future<DirectoryPage<T>> _page<T>(
    DirectorySection section,
    T Function(JsonReader row) item, {
    String? workspace,
    String? after,
    String query = '',
  }) async {
    final Object? raw;
    try {
      raw = await personal.rpc<Object?>(
        'my_personal_message_directory_v1',
        params: {
          'p_section': section.name,
          'p_workspace_network_id': workspace,
          'p_after_key': after,
          'p_query': query,
        },
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the screen says which refusal.
      final failure = _refusalOf(e);
      if (failure == null) rethrow;
      Error.throwWithStackTrace(
        DirectoryRefused(failure, detail: e.message),
        st,
      );
    }
    try {
      return DirectoryPage.decode(raw, section, item);
    } on JsonShapeException catch (e, st) {
      // trace-exempt: rethrown typed; a malformed answer is never shown as empty.
      Error.throwWithStackTrace(
        DirectoryRefused(DirectoryFailure.malformed, detail: '$e'),
        st,
      );
    }
  }

  @override
  Future<DirectoryPage<DirectoryWorkspace>> workspaces({String? after}) =>
      _page(
        DirectorySection.workspaces,
        DirectoryWorkspace.decode,
        after: after,
      );

  @override
  Future<DirectoryPage<DirectoryPerson>> people(
    String networkId, {
    String? after,
    String query = '',
  }) => _page(
    DirectorySection.people,
    DirectoryPerson.decode,
    workspace: networkId,
    after: after,
    query: query,
  );

  @override
  Future<DirectoryPage<DirectoryGroup>> groups({String? after}) =>
      _page(DirectorySection.groups, DirectoryGroup.decode, after: after);

  /// The SQLSTATEs the reader raises on purpose, and PostgREST's answer
  /// for a function it does not know. Anything else is not a refusal.
  static DirectoryFailure? _refusalOf(PostgrestException e) => switch (e.code) {
    'PGRST202' || '42883' => DirectoryFailure.unsupported,
    '42501' => DirectoryFailure.forbidden,
    '22023' => DirectoryFailure.invalid,
    _ => null,
  };
}
