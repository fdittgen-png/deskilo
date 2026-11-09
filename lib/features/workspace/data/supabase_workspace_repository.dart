// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:supabase_flutter/supabase_flutter.dart';

import '../domain/workspace_repository.dart';
import 'supabase_badges.dart';
import 'supabase_booking_rules.dart';
import 'supabase_conversations.dart';
import 'supabase_managed_identity.dart';
import 'supabase_membership.dart';
import 'supabase_role_permissions.dart';
import 'supabase_sites.dart';
import 'supabase_workspace_identity.dart';
import 'supabase_workspace_lifecycle.dart';
import 'supabase_workspace_provenance.dart';
import 'supabase_workspace_rows.dart';
import 'supabase_workspace_templates.dart';

/// #2597 -- the sum of the per-capability mixins; each owns its operations.
class SupabaseWorkspaceRepository
    with
        SupabaseWorkspaceRows,
        SupabaseConversations,
        SupabaseBookingRules,
        SupabaseWorkspaceTemplates,
        SupabaseWorkspaceProvenance,
        SupabaseWorkspaceLifecycle,
        SupabaseManagedIdentity,
        SupabaseMembership,
        SupabaseBadges,
        SupabaseRolePermissions,
        SupabaseSites,
        SupabaseWorkspaceIdentity
    implements WorkspaceRepository {
  SupabaseWorkspaceRepository(this._client);

  final SupabaseClient _client;

  /// The one place the emblem's path is written down.
  static String emblemPath(String workspaceId) =>
      '$workspaceId/brand/emblem.png';

  @override
  SupabaseClient get client => _client;

  @override
  SupabaseClient get conversationClient => _client;
}
