// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 — the setup checklist is read from the server's answers. Each step
// has one state, one actor and whether the person looking may act; a
// missing answer is `unavailable`, never `done`; permission to open the
// screen grants no action by itself (turning the feature on still needs
// manageConfiguration). The recommended set is a member's own records
// plus the two booking reads, never a financial, membership or validation
// operation, and never an operation the server does not implement.
import 'package:deskilo/core/mcp/mcp_endpoint.dart';
import 'package:deskilo/core/mcp/mcp_operations.dart';
import 'package:deskilo/features/auth/domain/identity_binding.dart';
import 'package:deskilo/features/mcp/application/assistant_setup.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/domain/mcp_connection.dart';
import 'package:flutter_test/flutter_test.dart';

const _ws = 'ws-1';

McpPolicy _policy({
  bool feature = true,
  bool enabled = true,
  Set<String> ops = const {'get_capabilities'},
  String workspace = _ws,
}) => McpPolicy(
  workspaceId: workspace,
  revision: 3,
  enabled: enabled,
  operations: ops,
  targetCeiling: 'own',
  featureEnabled: feature,
  available: mcpOperations.keys.toList(),
);

McpConnectionInfo _connection(String workspace) => McpConnectionInfo(
  clientId: 'claude',
  clientName: 'Claude',
  workspaces: [
    ConsentWorkspace(id: workspace, name: 'W', operations: const []),
  ],
);

AssistantSetup _derive({
  IdentityBindingState? identity = IdentityBindingState.verified,
  McpEligibility? eligibility = McpEligibility.eligible,
  bool runtime = true,
  McpPolicy? policy,
  bool noPolicy = false,
  List<McpConnectionInfo>? connections = const [],
  bool featureOn = true,
  bool canConfigure = true,
  bool canManageIntegrations = true,
}) => AssistantSetup.derive(
  workspaceId: _ws,
  identity: identity == null ? null : IdentityBindingStatus(state: identity),
  capabilities: eligibility == null
      ? null
      : DatabaseCapabilities(eligibility: eligibility, runtimeEnabled: runtime),
  policy: noPolicy ? null : (policy ?? _policy(feature: featureOn)),
  connections: connections,
  featureOn: featureOn,
  canConfigure: canConfigure,
  canManageIntegrations: canManageIntegrations,
);

String _states(AssistantSetup s) =>
    [for (final i in s.items) '${i.step.name}:${i.state.name}'].join(' ');

void main() {
  test('everything answered and done but the connection: connect is the '
      'next step, and the person may take it', () {
    final s = _derive();
    expect(
      _states(s),
      'identity:done workspace:done policy:done eligibility:done '
      'installation:done connect:todo',
    );
    expect(s.next?.step, AssistantSetupStep.connect);
    expect(s.next?.canAct, isTrue);
  });

  test('a connection that names this workspace completes the list', () {
    final s = _derive(connections: [_connection(_ws)]);
    expect(s.next, isNull);
  });

  test('a connection for ANOTHER workspace does not complete this one', () {
    final s = _derive(connections: [_connection('ws-2')]);
    expect(s.item(AssistantSetupStep.connect).state, AssistantSetupState.todo);
  });

  test('an unlinked identity: link is to do, and asking for access waits '
      'behind it (blocked, not offered)', () {
    final s = _derive(
      identity: IdentityBindingState.unlinked,
      eligibility: McpEligibility.noIdentity,
    );
    expect(s.next?.step, AssistantSetupStep.identity);
    expect(s.item(AssistantSetupStep.identity).canAct, isTrue);
    final ask = s.item(AssistantSetupStep.eligibility);
    expect(ask.state, AssistantSetupState.blocked);
    expect(ask.canAct, isFalse);
  });

  test('feature off: a configurer may turn it on; the policy waits behind '
      'it and cannot be applied yet', () {
    final s = _derive(featureOn: false);
    final ws = s.item(AssistantSetupStep.workspace);
    expect(ws.state, AssistantSetupState.todo);
    expect(ws.canAct, isTrue);
    final policy = s.item(AssistantSetupStep.policy);
    expect(policy.state, AssistantSetupState.blocked);
    expect(policy.canAct, isFalse);
  });

  test('feature off and no right to switch it: the screen grants nothing; '
      'the step waits on whoever manages integrations (#2145, 0360)', () {
    final s = _derive(featureOn: false, canConfigure: false);
    final ws = s.item(AssistantSetupStep.workspace);
    expect(ws.state, AssistantSetupState.waiting);
    expect(ws.actor, AssistantSetupActor.integrations);
    expect(ws.canAct, isFalse);
  });

  test('nothing offered yet: the integrations manager may apply a policy', () {
    final s = _derive(policy: _policy(enabled: false, ops: const {}));
    final policy = s.item(AssistantSetupStep.policy);
    expect(policy.state, AssistantSetupState.todo);
    expect(policy.canAct, isTrue);
  });

  test('a pending request waits on a database administrator', () {
    final s = _derive(eligibility: McpEligibility.requested);
    final ask = s.item(AssistantSetupStep.eligibility);
    expect(ask.state, AssistantSetupState.waiting);
    expect(ask.actor, AssistantSetupActor.databaseAdministrator);
    expect(ask.canAct, isFalse);
    expect(
      s.item(AssistantSetupStep.connect).state,
      AssistantSetupState.blocked,
    );
  });

  test('an expired approval is to do again', () {
    final s = _derive(eligibility: McpEligibility.expired);
    expect(
      s.item(AssistantSetupStep.eligibility).state,
      AssistantSetupState.todo,
    );
  });

  test('runtime off: the installation waits on the instance owner or a '
      'delegate, and nobody here can act on it', () {
    final s = _derive(runtime: false);
    final inst = s.item(AssistantSetupStep.installation);
    expect(inst.state, AssistantSetupState.waiting);
    expect(inst.actor, AssistantSetupActor.instanceOperator);
    expect(inst.canAct, isFalse);
    expect(
      s.item(AssistantSetupStep.connect).state,
      AssistantSetupState.blocked,
    );
  });

  test('missing answers are unavailable, never done', () {
    final s = _derive(
      identity: null,
      eligibility: null,
      noPolicy: true,
      connections: null,
    );
    for (final step in [
      AssistantSetupStep.identity,
      AssistantSetupStep.policy,
      AssistantSetupStep.eligibility,
      AssistantSetupStep.installation,
      AssistantSetupStep.connect,
    ]) {
      expect(
        s.item(step).state,
        AssistantSetupState.unavailable,
        reason: step.name,
      );
    }
    expect(s.next?.state, AssistantSetupState.unavailable);
  });

  test('capabilities the server could not read: the installation step is '
      'unavailable, not waiting', () {
    final s = _derive(eligibility: McpEligibility.unavailable);
    expect(
      s.item(AssistantSetupStep.installation).state,
      AssistantSetupState.unavailable,
    );
  });

  test('a policy answered for another workspace is not this one\'s', () {
    final s = _derive(policy: _policy(workspace: 'ws-2'));
    expect(
      s.item(AssistantSetupStep.policy).state,
      AssistantSetupState.unavailable,
    );
  });

  group('recommended set', () {
    test('own records and the two booking reads, nothing else', () {
      expect(recommendedMcpOperations(mcpOperations.keys), {
        'get_capabilities',
        'get_availability',
        'list_my_reservations',
        'get_my_statement',
        'list_my_invoices',
        'create_reservation',
        'update_reservation',
        'check_in',
        'check_out',
        'cancel_reservation',
        'request_reservation_deletion',
      });
    });

    test('never an operation the server does not implement', () {
      expect(recommendedMcpOperations(const ['get_capabilities', 'check_in']), {
        'get_capabilities',
        'check_in',
      });
      expect(recommendedMcpOperations(const ['not_an_operation']), isEmpty);
    });
  });

  group('connector URL', () {
    test('the backend\'s own MCP function', () {
      expect(
        '${mcpConnectorUri('https://abc.supabase.co')}',
        'https://abc.supabase.co/functions/v1/deskilo-mcp',
      );
      expect(
        '${mcpConnectorUri('https://db.example.org/base/')}',
        'https://db.example.org/base/functions/v1/deskilo-mcp',
      );
    });

    test('none without a usable backend URL', () {
      expect(mcpConnectorUri(''), isNull);
      expect(mcpConnectorUri('not a url'), isNull);
      expect(mcpConnectorUri('ftp://x.example'), isNull);
    });
  });
}
