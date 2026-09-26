// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/connect_assistant.dart';
import '../data/supabase_action_confirmation_repository.dart';
import '../data/supabase_mcp_connection_repository.dart';
import '../domain/action_confirmation.dart';
import '../domain/mcp_connection.dart';

part 'mcp_providers.g.dart';

@Riverpod(keepAlive: true)
ActionConfirmationRepository actionConfirmationRepository(Ref ref) =>
    SupabaseActionConfirmationRepository(Supabase.instance.client);

/// One confirmation, as the server answers it now.
@riverpod
Future<ActionConfirmation> actionConfirmation(Ref ref, String id) =>
    ref.watch(actionConfirmationRepositoryProvider).get(id);

/// #1615 — the consent RPCs and Auth's OAuth consent API.
@Riverpod(keepAlive: true)
McpConnectionRepository mcpConnectionRepository(Ref ref) =>
    SupabaseMcpConnectionRepository(Supabase.instance.client);

@riverpod
ConnectAssistant connectAssistant(Ref ref) => ConnectAssistant(
  ref.watch(mcpConnectionRepositoryProvider),
  () => ref.read(identityBindingRepositoryProvider).requestMcpEligibility(),
  onFinalizeFailed: (error, stack) => ref
      .read(traceLoggerProvider)
      .error(
        'mcp',
        'connection approved but not finalised',
        error: error,
        stackTrace: stack,
      ),
);

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
