// SPDX-License-Identifier: 0BSD
//
// #1120 — the workspace library half of the Supabase repository, on its
// own file because the repository was at its length budget and the rule
// is to extract, not to raise the number. A mixin rather than a second
// class so the interface stays ONE thing the app reads through.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_template.dart';

mixin SupabaseWorkspaceTemplates {
  SupabaseClient get client;


  Future<List<WorkspaceTemplate>> fetchWorkspaceTemplates() async {
    // RLS is the filter: `workspace_templates_read` asks
    // workspace_template_readable(id) per row.
    final rows = await client
        .from('workspace_templates')
        .select()
        .order('visibility')
        .order('name');
    return [
      for (final row in rows)
        WorkspaceTemplate.fromRow(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<void> applyWorkspaceTemplate(String workspaceId, String templateId) =>
      client.rpc<dynamic>('apply_workspace_template', params: {
        'p_workspace_id': workspaceId,
        'p_template_id': templateId,
      });

  Future<String> saveWorkspaceAsTemplate(
    String workspaceId, {
    required String key,
    required String name,
    String description = '',
    TemplateVisibility visibility = TemplateVisibility.private,
  }) async {
    final id = await client.rpc<dynamic>('save_workspace_as_template', params: {
      'p_workspace_id': workspaceId,
      'p_key': key,
      'p_name': name,
      'p_description': description,
      'p_visibility': visibility.name,
    });
    return id as String;
  }

  Future<void> setWorkspaceTemplateVisibility(
          String templateId, TemplateVisibility visibility) =>
      client.rpc<dynamic>('set_workspace_template_visibility', params: {
        'p_template_id': templateId,
        'p_visibility': visibility.name,
      });

  Future<void> deleteWorkspaceTemplate(String templateId) =>
      client.rpc<dynamic>('delete_workspace_template',
          params: {'p_template_id': templateId});

  Future<void> grantWorkspaceTemplate(String templateId, String email) =>
      client.rpc<dynamic>('grant_workspace_template',
          params: {'p_template_id': templateId, 'p_email': email});

  Future<void> revokeWorkspaceTemplateGrant(String templateId, String email) =>
      client.rpc<dynamic>('revoke_workspace_template_grant',
          params: {'p_template_id': templateId, 'p_email': email});

  Future<List<String>> workspaceTemplateGrantees(String templateId) async {
    final rows = await client.rpc<dynamic>('workspace_template_grantees',
        params: {'p_template_id': templateId});
    return [for (final r in rows as List) '$r'];
  }
}
