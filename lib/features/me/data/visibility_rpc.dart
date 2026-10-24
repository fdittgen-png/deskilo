// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:meta/meta.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/visibility.dart';
import '../domain/visibility_write.dart';

/// `my_visibility()` on [client]: this server's session or a linked one's.
Future<MyVisibility> readMyVisibility(SupabaseClient client) async =>
    _visibility(await client.rpc<Object?>('my_visibility'));

MyVisibility _visibility(Object? raw) => MyVisibility.fromJson(
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
    );

/// #2558 — `my_visibility_network_v1()` on the personal home's [client]:
/// the chosen spaces by network reference and the home that answered.
Future<MyVisibility> readMyNetworkVisibility(SupabaseClient client) async =>
    _visibility(await client.rpc<Object?>('my_visibility_network_v1'));

/// #2558 C2 — `set_visibility_if_unchanged_network_v1` on the personal
/// home's [client]: the chosen spaces by network reference, the field as it
/// was read as `p_expected`. `visibility_conflict` (SQLSTATE PT409) is a
/// [VisibilityConflict], a home without this writer [VisibilityUnsupported];
/// every other refusal stays the server's answer, and
/// nothing falls back to a weaker writer. No answer at all (a timeout, a
/// dropped connection) is [VisibilityReplyLost].
Future<MyVisibility> writeVisibilityIfUnchanged(
  SupabaseClient client,
  VisibilityField field,
  FieldAudience audience,
  FieldAudience expected,
) async {
  final Object? raw;
  try {
    raw = await client.rpc<Object?>(
      'set_visibility_if_unchanged_network_v1',
      params: {
        'p_field': field.wire,
        'p_audience': audience.audience.wire,
        'p_workspace_refs': audience.audience == VisibilityAudience.chosenSpaces
            ? (audience.workspaces.toList()..sort())
            : null,
        'p_expected': expected.expectedJson,
      },
    );
  } on PostgrestException catch (e, st) {
    // trace-exempt: rethrown typed; the editor reviews the conflict.
    final typed = visibilityWriteRefusal(e);
    if (typed == null) rethrow;
    Error.throwWithStackTrace(typed, st);
  } on Exception catch (e, st) {
    // trace-exempt: no answer came back; the command reads the outcome.
    Error.throwWithStackTrace(VisibilityReplyLost(e), st);
  }
  final reply = raw is Map ? raw['visibility'] : null;
  return _visibility(reply);
}

/// The typed answer [e] stands for, or null when it is the server's own
/// refusal, kept as it is: the checked writer's `visibility_conflict`
/// ([VisibilityConflict]), or a home without the checked writer
/// ([VisibilityUnsupported], PGRST202 / 42883).
@visibleForTesting
Exception? visibilityWriteRefusal(PostgrestException e) => switch (e.code) {
      'PT409' => const VisibilityConflict(),
      'PGRST202' || '42883' => const VisibilityUnsupported(),
      _ => e.message == 'visibility_conflict'
          ? const VisibilityConflict()
          : null,
    };

/// `set_visibility(field, audience, workspaces)` on [client]. The spaces
/// travel only with "chosen spaces"; every other audience sends none.
Future<void> writeVisibility(
  SupabaseClient client,
  VisibilityField field,
  FieldAudience audience,
) => client.rpc<void>(
  'set_visibility',
  params: {
    'p_field': field.wire,
    'p_audience': audience.audience.wire,
    'p_workspaces': audience.audience == VisibilityAudience.chosenSpaces
        ? audience.workspaces.toList()
        : null,
  },
);
