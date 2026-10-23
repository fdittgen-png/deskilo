// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/visibility.dart';

/// `my_visibility()` on [client]: this server's session or a linked one's.
Future<MyVisibility> readMyVisibility(SupabaseClient client) async {
  final raw = await client.rpc<dynamic>('my_visibility');
  return MyVisibility.fromJson(
    raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{},
  );
}

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
