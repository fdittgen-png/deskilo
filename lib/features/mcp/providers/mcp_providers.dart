// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/answer_confirmation.dart';
import '../application/assistant_access.dart';
import '../application/connect_assistant.dart';
import '../application/eligibility_review.dart';
import '../application/mcp_policy_editor.dart';
import '../data/supabase_mcp_admin_repository.dart';
import '../data/supabase_action_confirmation_repository.dart';
import '../data/supabase_mcp_connection_repository.dart';
import '../domain/action_confirmation.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_context.dart';
import '../domain/mcp_connection.dart';
import '../domain/mcp_usage.dart';

part 'mcp_providers.g.dart';

@Riverpod(keepAlive: true)
ActionConfirmationRepository actionConfirmationRepository(Ref ref) =>
    SupabaseActionConfirmationRepository(Supabase.instance.client);

/// One confirmation, as the server answers it now.
@riverpod
ConfirmationAnswers confirmationAnswers(Ref ref) =>
    ConfirmationAnswers(ref.watch(actionConfirmationRepositoryProvider));

/// #1625 — an answer for another confirmation is refused, not shown.
@riverpod
Future<ActionConfirmation> actionConfirmation(Ref ref, String id) async {
  final c = await ref.watch(actionConfirmationRepositoryProvider).get(id);
  return requireProvenance(c, what: 'confirmation', expected: id, answered: c.id);
}

/// #1615 — the consent RPCs and Auth's OAuth consent API.
@Riverpod(keepAlive: true)
McpConnectionRepository mcpConnectionRepository(Ref ref) =>
    SupabaseMcpConnectionRepository(Supabase.instance.client);

@riverpod
ConnectAssistant connectAssistant(Ref ref) {
  // Read up front: the closures outlive this auto-disposed provider's ref.
  final identity = ref.watch(identityBindingRepositoryProvider);
  final trace = ref.watch(traceLoggerProvider);
  return ConnectAssistant(
    ref.watch(mcpConnectionRepositoryProvider),
    () => identity.requestMcpEligibility(),
    onFinalizeFailed: (error, stack) => trace.error(
        'mcp', 'connection approved but not finalised',
        error: error, stackTrace: stack),
  );
}

/// The pending request and what this person may offer, loaded together.
@riverpod
Future<({AuthorizationRequest request, ConsentOptions options})> mcpConsent(
  Ref ref,
  String authorizationId,
) async {
  final repository = ref.watch(mcpConnectionRepositoryProvider);
  final request = await repository.authorization(authorizationId);
  if (request.alreadyRedirectTo != null) {
    return (
      request: request,
      options: const ConsentOptions(eligible: true, workspaces: []),
    );
  }
  return (request: request, options: await repository.options());
}

/// The assistants this person connected to this database.
@riverpod
Future<List<McpConnectionInfo>> myMcpConnections(Ref ref) =>
    ref.watch(mcpConnectionRepositoryProvider).connections();

/// #1626/#1627 — owner policy and database eligibility review.
@Riverpod(keepAlive: true)
McpAdminRepository mcpAdminRepository(Ref ref) =>
    SupabaseMcpAdminRepository(Supabase.instance.client);

/// The owner's policy for one workspace, as the server holds it now.
/// #1625 — an answer for another workspace is refused, not shown.
@riverpod
Future<McpPolicy> mcpPolicy(Ref ref, String workspaceId) async {
  final p = await ref.watch(mcpAdminRepositoryProvider).policy(workspaceId);
  return requireProvenance(
    p,
    what: 'workspace',
    expected: workspaceId,
    answered: p.workspaceId,
  );
}

/// #1630 — the workspace's assistant usage over 30 days, counts only.
/// An answer for another workspace is refused, not shown.
@riverpod
Future<McpWorkspaceUsage> mcpWorkspaceUsage(Ref ref, String workspaceId) async {
  final u = await ref
      .watch(mcpAdminRepositoryProvider)
      .workspaceUsage(workspaceId);
  return requireProvenance(
    u,
    what: 'workspace',
    expected: workspaceId,
    answered: u.workspaceId,
  );
}

/// #1630 — this person's own assistant usage today.
@riverpod
Future<List<McpClientUsage>> myMcpUsage(Ref ref) =>
    ref.watch(mcpConnectionRepositoryProvider).myUsage();

@riverpod
McpPolicyEditor mcpPolicyEditor(Ref ref) =>
    McpPolicyEditor(ref.watch(mcpAdminRepositoryProvider));

/// The pending eligibility requests on this database (administrators only).
@riverpod
Future<List<EligibilityRequest>> eligibilityRequests(Ref ref) =>
    ref.watch(mcpAdminRepositoryProvider).eligibilityRequests();

@riverpod
EligibilityReview eligibilityReview(Ref ref) => EligibilityReview(
  ref.watch(mcpAdminRepositoryProvider),
  ref.watch(secondFactorRepositoryProvider),
);

@riverpod
AssistantAccess assistantAccess(Ref ref) => AssistantAccess(
  ref.watch(mcpConnectionRepositoryProvider),
  ref.watch(identityBindingRepositoryProvider),
);
