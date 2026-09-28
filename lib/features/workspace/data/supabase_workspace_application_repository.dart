// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_application.dart';

class SupabaseWorkspaceApplicationRepository
    implements WorkspaceApplicationRepository {
  SupabaseWorkspaceApplicationRepository(this.client);
  final SupabaseClient client;
  Map<String, dynamic> _cursor(ApplicationCursor? before) => {
    'p_before_at': before?.at.toUtc().toIso8601String(),
    'p_before_id': before?.id,
  };
  @override
  Future<List<WorkspaceApplication>> list({ApplicationCursor? before}) async {
    final rows = await client.rpc<List<dynamic>>(
      'my_workspace_applications',
      params: _cursor(before),
    );
    return [
      for (final row in rows)
        WorkspaceApplication.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<List<ApplicationMessage>> thread(
    String id, {
    ApplicationCursor? before,
  }) async {
    final rows = await client.rpc<List<dynamic>>(
      'workspace_application_thread',
      params: {'p_event_id': id, ..._cursor(before)},
    );
    return [
      for (final row in rows)
        ApplicationMessage.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
  }

  @override
  Future<void> send(
    String id,
    String body, {
    required String expectedAccount,
  }) => client.rpc<void>(
    'send_workspace_application_message',
    params: {
      'p_event_id': id,
      'p_body': body,
      'p_expected_account': expectedAccount,
    },
  );
}
