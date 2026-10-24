// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/visibility.dart';

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
