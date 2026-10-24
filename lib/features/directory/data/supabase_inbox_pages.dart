// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2556 C1 -- the strict adapter of the two inbox readers on one server:
// `my_account_inbox_v1` at a personal home, `my_workspace_inbox_v1` at a
// workspace host, through that server's own session. A refusal the readers
// raise on purpose comes back typed; a missing reader (an older server) is
// `unsupported`, the one answer that lets the inbox read it the legacy way.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_installations.dart';
import '../domain/inbox_sources.dart';

mixin SupabaseInboxPages {
  ConnectedInstallations get connections;

  /// The server's origin; '' is this one.
  String get source;

  Future<InboxSourcePage> inboxPage(
    InboxSourceRole role, {
    InboxCursor? before,
  }) async {
    final Object? raw;
    try {
      raw = await connections.use(
        source,
        (client) => client.rpc<Object?>(
          role.reader,
          params: {'p_before_at': before?.at, 'p_before_key': before?.key},
        ),
      );
    } on PostgrestException catch (e, st) {
      // trace-exempt: rethrown typed; the inbox names the source's state.
      final failure = switch (e.code) {
        'PGRST202' || '42883' => InboxSourceFailure.unsupported,
        '0A000' => InboxSourceFailure.wrongRole,
        '22023' => InboxSourceFailure.invalid,
        _ => null,
      };
      if (failure == null) rethrow;
      Error.throwWithStackTrace(
        InboxSourceRefused(failure, detail: e.message),
        st,
      );
    }
    return InboxSourcePage.decode(raw, role);
  }
}
