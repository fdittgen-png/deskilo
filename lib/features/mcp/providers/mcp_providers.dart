// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/backend/connected_installation_providers.dart';
import '../../../core/trace/trace_logger.dart';
import '../../auth/providers/auth_providers.dart';
import '../application/active_target_client.dart';
import '../application/answer_confirmation.dart';
import '../application/assistant_access.dart';
import '../application/connect_assistant.dart';
import '../application/eligibility_review.dart';
import '../application/mcp_client_registry.dart';
import '../application/mcp_commands.dart';
import '../application/mcp_policy_editor.dart';
import '../data/connected_target_client.dart';
import '../data/supabase_mcp_admin_repository.dart';
import '../data/supabase_action_confirmation_repository.dart';
import '../data/supabase_mcp_connection_repository.dart';
import '../domain/action_confirmation.dart';
import '../domain/mcp_access_status.dart';
import '../domain/mcp_admin.dart';
import '../domain/mcp_client.dart';
import '../domain/mcp_context.dart';
import '../domain/mcp_connection.dart';
import '../domain/mcp_usage.dart';

part 'mcp_providers.g.dart';

@Riverpod(keepAlive: true)
ActionConfirmationRepository actionConfirmationRepository(Ref ref) =>
    SupabaseActionConfirmationRepository(Supabase.instance.client);

/// #1625 — the active backend's own repositories, as one target bundle.
@Riverpod(keepAlive: true)
McpRepositories activeMcpRepositories(Ref ref) => McpRepositories(
  admin: ref.watch(mcpAdminRepositoryProvider),
  connections: ref.watch(mcpConnectionRepositoryProvider),
  confirmations: ref.watch(actionConfirmationRepositoryProvider),
  identity: ref.watch(identityBindingRepositoryProvider),
);

/// #1625 — one native client per verified installation + issuer + account
/// + purpose. The active backend borrows the app's session; a connected
/// installation runs through its own isolated record. A sign-in change
/// retires every client, with one outcome per target.
@Riverpod(keepAlive: true)
McpClientRegistry mcpClientRegistry(Ref ref) {
  final trace = ref.watch(traceLoggerProvider);
  final registry = McpClientRegistry(
    (key, target) => target.source.isEmpty
        ? ActiveMcpTargetClient(
            key,
            () => ref.read(activeMcpRepositoriesProvider),
            currentAccount: () => ref.read(authStateProvider).value,
          )
        : ConnectedMcpTargetClient(
            key,
            ref.read(connectedInstallationsProvider),
            target.source,
          ),
  );
  void report(Map<McpTargetKey, McpDisposeOutcome> outcomes) {
    final failed = outcomes.values
        .where((o) => o == McpDisposeOutcome.failed)
        .length;
    if (failed > 0) trace.warn('mcp', '$failed target clients not disposed');
  }

  // A sign-out or account change — not the first sign-in answer.
  ref.listen(authStateProvider, (previous, next) {
    if (previous != null &&
        previous.hasValue &&
        !next.isLoading &&
        previous.value != next.value) {
      registry.disposeAll().then(report);
    }
  });
  ref.onDispose(() => registry.close().then(report));
  return registry;
}

@Riverpod(keepAlive: true)
McpCommands mcpCommands(Ref ref) =>
    McpCommands(ref.watch(mcpClientRegistryProvider));

/// #1625 — the active backend as a verified target: the installation id
/// its own server answers for the signed-in account. Registered in the
/// registry before anything is asked of it.
@Riverpod(keepAlive: true)
Future<VerifiedMcpTarget> activeMcpTarget(Ref ref) async {
  final signedIn = ref.watch(authStateProvider.future);
  final identity = ref.watch(identityBindingRepositoryProvider);
  final registry = ref.watch(mcpClientRegistryProvider);
  final account = await signedIn;
  if (account == null) throw const McpTargetUnverified('');
  final status = await identity.status();
  if (ref.read(authStateProvider).value != account) {
    throw const McpContextSuperseded();
  }
  final target = VerifiedMcpTarget(
    installationId: status.installationId ?? '',
    issuer: status.issuer ?? '',
    account: account,
  );
  await registry.register(target);
  return target;
}

/// Tests and Demo: [installationId] as the verified installation of
/// whoever is signed in, registered like the real one.
Future<VerifiedMcpTarget> fixedMcpTarget(Ref ref, String installationId) async {
  final signedIn = ref.watch(authStateProvider.future);
  final registry = ref.watch(mcpClientRegistryProvider);
  final account = await signedIn;
  if (account == null) throw const McpTargetUnverified('');
  final target = VerifiedMcpTarget(
    installationId: installationId,
    issuer: '',
    account: account,
  );
  await registry.register(target);
  return target;
}

/// One confirmation, as the server answers it now.
@Riverpod(keepAlive: true)
ConfirmationAnswers confirmationAnswers(Ref ref) =>
    ConfirmationAnswers(ref.watch(mcpCommandsProvider));

/// #1625 — read through the active target's confirmation client; an
/// answer for another confirmation is refused, not shown, and one that
/// arrives after a switch or sign-out is discarded.
@riverpod
Future<ActionConfirmation> actionConfirmation(Ref ref, String id) async {
  final target = ref.watch(activeMcpTargetProvider.future);
  final commands = ref.watch(mcpCommandsProvider);
  final scope = (await target).instance;
  final c = await commands.read(
    scope,
    (r) => r.confirmations.get(id),
    purpose: McpClientPurpose.confirmation,
  );
  return requireProvenance(
    c,
    what: 'confirmation',
    expected: id,
    answered: c.id,
  ).withScope(scope);
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
Future<List<McpConnectionInfo>> myMcpConnections(Ref ref) async {
  final target = ref.watch(activeMcpTargetProvider.future);
  final commands = ref.watch(mcpCommandsProvider);
  final scope = (await target).instance;
  final list = await commands.read(scope, (r) => r.connections.connections());
  return [for (final c in list) c.withScope(scope)];
}

/// #1626/#1627 — owner policy and database eligibility review.
@Riverpod(keepAlive: true)
McpAdminRepository mcpAdminRepository(Ref ref) =>
    SupabaseMcpAdminRepository(Supabase.instance.client);

/// The owner's policy for one workspace, as the server holds it now.
/// #1625 — keyed by installation, account and workspace; an answer for
/// another workspace is refused, and one that arrives after the context
/// was switched, signed out of or revoked is discarded.
@riverpod
Future<McpPolicy> mcpPolicy(Ref ref, McpContextRef context) async {
  final commands = ref.watch(mcpCommandsProvider);
  final p = await commands.read(
    context,
    (r) => r.admin.policy(context.workspaceId),
  );
  return requireProvenance(
    p,
    what: 'workspace',
    expected: context.workspaceId,
    answered: p.workspaceId,
  ).withContext(context);
}

/// #1625 — the six separate facts for one person on one workspace.
@riverpod
Future<McpAccessStatus> mcpAccessStatus(Ref ref, McpContextRef context) async {
  final commands = ref.watch(mcpCommandsProvider);
  Future<T?> maybe<T>(Future<T> Function(McpRepositories r) q) =>
      commands.read(context, q).then<T?>((v) => v, onError: (Object e) {
        if (e is McpContextSuperseded) throw e;
        return null;
      });
  final results = await (
    maybe((r) => r.identity.status()),
    maybe((r) => r.identity.databaseCapabilities()),
    maybe((r) => r.admin.policy(context.workspaceId)),
    maybe((r) => r.connections.options()),
    maybe((r) => r.connections.connections()),
  ).wait;
  return McpAccessStatus.derive(
    context,
    identity: results.$1,
    capabilities: results.$2,
    policy: results.$3,
    options: results.$4,
    connections: results.$5,
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
    McpPolicyEditor(ref.watch(mcpCommandsProvider));

/// The pending eligibility requests on this database (administrators only).
/// #1625 — the installation's queue, whatever workspace is selected.
@riverpod
Future<List<EligibilityRequest>> eligibilityRequests(Ref ref) async {
  final target = ref.watch(activeMcpTargetProvider.future);
  final commands = ref.watch(mcpCommandsProvider);
  final scope = (await target).instance;
  final queue = await commands.read(scope, (r) => r.admin.eligibilityRequests());
  return [for (final q in queue) q.withScope(scope)];
}

@riverpod
EligibilityReview eligibilityReview(Ref ref) => EligibilityReview(
  ref.watch(mcpCommandsProvider),
  ref.watch(secondFactorRepositoryProvider),
);

@riverpod
AssistantAccess assistantAccess(Ref ref) => AssistantAccess(
  ref.watch(mcpCommandsProvider),
  ref.watch(identityBindingRepositoryProvider),
);
