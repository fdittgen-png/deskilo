// SPDX-License-Identifier: AGPL-3.0-or-later
import 'badge_repository.dart';
import 'booking_rules_repository.dart';
import 'conversation_repository.dart';
import 'managed_identity_repository.dart';
import 'membership_repository.dart';
import 'role_permission_repository.dart';
import 'site_repository.dart';
import 'template_repository.dart';
import 'workspace_identity_repository.dart';
import 'workspace_lifecycle_repository.dart';

/// Pure-Dart workspace boundary. Supabase impl in data/, fake in tests.
///
/// #2597 — the sum of ten sub-interfaces, each in its own file; the old
/// name keeps every method, so every `implements WorkspaceRepository` and
/// every `workspaceRepositoryProvider` read compiles unchanged.
abstract class WorkspaceRepository
    implements
        SiteRepository,
        MembershipRepository,
        ManagedIdentityRepository,
        BadgeRepository,
        RolePermissionRepository,
        BookingRulesRepository,
        WorkspaceIdentityRepository,
        ConversationRepository,
        TemplateRepository,
        WorkspaceLifecycleRepository {}
