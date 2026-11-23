// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4322 -- the business's own IANA time zone, for the dates a document is read on: a tax point is a
// calendar date, and which day a payment fell on is the business's answer, not the device's. A read
// that fails is an error, never "no zone": an unknown zone would date every payment in UTC.
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/server_names.dart';

/// The IANA zone of [workspaceId] as the business keeps it; null when it names none.
Future<String?> workspaceTimezone(SupabaseClient client, String workspaceId) async {
  final row = await client.from(ServerTable.workspaces).select('timezone').eq('id', workspaceId).maybeSingle();
  return row?['timezone'] as String?;
}
