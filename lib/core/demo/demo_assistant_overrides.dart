// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3962 — the assistants of the reference business. The Demo's person is
// eligible and bound on its fictional installation, one assistant is
// connected with the operations it may use, and it has left three requests:
// one waiting for its person, one confirmed, one declined. Confirming the
// waiting one decides the event the assistant asked about, as the person
// would have; revoking the connection closes what still waits. Only the
// outward edge is the Demo's: the screens are the real ones, and nothing
// leaves the device.
import 'package:flutter_riverpod/misc.dart' show Override;

import '../../features/auth/domain/identity_binding.dart';
import '../../features/auth/providers/auth_providers.dart';
import '../../features/events/domain/workspace_event.dart';
import '../../features/mcp/domain/action_confirmation.dart';
import '../../features/mcp/domain/mcp_admin.dart';
import '../../features/mcp/domain/mcp_connection.dart';
import '../../features/mcp/providers/assistant_setup_providers.dart';
import '../../features/mcp/providers/mcp_providers.dart';
import 'data/action_confirmation_repository.dart';
import 'data/identity_binding_repository.dart';
import 'data/mcp_admin_repository.dart';
import 'data/mcp_connection_repository.dart';
import 'data/mcp_onboarding_repository.dart';
import 'demo_fixture.dart';
import 'demo_space_routing.dart' show kDemoInstallationId;

/// The operations the Demo's assistant may use.
const _operations = [
  'list_my_reservations',
  'get_availability',
  'create_reservation',
  'respond_to_validation',
  'get_my_statement',
];

/// The Demo's assistant, as the connection page lists it.
const _assistantId = 'demo-assistant';

/// What an assistant of one Demo session holds: the fakes behind the four
/// repositories, kept for the session so a switch of persona reaches the
/// same requests.
class _DemoAssistants {
  _DemoAssistants._(DemoFixture fixture) {
    final now = fixture.seededAt;
    final workspace = fixture.workspaces.workspaces.firstWhere(
      (w) => w.id == 'ws-1',
    );
    identity.capabilities = DatabaseCapabilities(
      eligibility: McpEligibility.eligible,
      runtimeEnabled: true,
      eligibleUntil: now.add(const Duration(days: 365)),
    );
    connections
      ..consent = ConsentOptions(
        eligible: true,
        workspaces: [
          ConsentWorkspace(
            id: workspace.id,
            name: workspace.name,
            operations: _operations,
          ),
        ],
      )
      ..live.add(
        McpConnectionInfo(
          clientId: _assistantId,
          clientName: 'Demo assistant',
          connectedAt: now.subtract(const Duration(days: 9)),
          workspaces: [
            ConsentWorkspace(
              id: workspace.id,
              name: workspace.name,
              operations: _operations,
            ),
          ],
        ),
      )
      ..onEnded = (clientId) {
        for (final id in [...confirmations.confirmations.keys]) {
          final c = confirmations.confirmations[id]!;
          if (c.status.answerable) {
            confirmations.confirmations[id] = _copy(
              c,
              ConfirmationStatus.revoked,
            );
          }
        }
      };
    admin.current = McpPolicy(
      workspaceId: workspace.id,
      revision: 1,
      enabled: true,
      operations: _operations.toSet(),
      targetCeiling: 'own',
      featureEnabled: true,
      available: _operations,
    );
    ActionConfirmation request(
      String id,
      ConfirmationStatus status,
      String event,
      String type,
    ) => ActionConfirmation(
      id: id,
      status: status,
      operation: 'respond_to_validation',
      workspaceName: workspace.name,
      clientName: 'Demo assistant',
      arguments: {'event_id': event, 'accept': true},
      target: {'kind': 'event', 'type': type},
      expiresAt: now.add(const Duration(days: 2)),
    );
    confirmations
      ..confirmations['demo-confirm-room'] = request(
        'demo-confirm-room',
        ConfirmationStatus.pending,
        'demo-room-request-event',
        'space_reservation',
      )
      ..confirmations['demo-confirm-quota'] = request(
        'demo-confirm-quota',
        ConfirmationStatus.acknowledged,
        'demo-quota-done',
        'quota',
      )
      ..confirmations['demo-confirm-expense'] = request(
        'demo-confirm-expense',
        ConfirmationStatus.declined,
        'demo-expense-refused',
        'expense',
      )
      ..onAnswered = (c, {required accept}) async {
        // Confirming approves what the assistant asked to approve; declining
        // leaves the request it was about to whoever validates it.
        final id = c.arguments['event_id'] as String?;
        final pending = fixture.events.events.any(
          (e) => e.id == id && e.status == EventStatus.pending,
        );
        if (accept && pending && id != null) {
          await fixture.events.respond(id, accept: true);
        }
      };
  }

  static final Expando<_DemoAssistants> _perSession =
      Expando<_DemoAssistants>();

  /// The assistants of the session [fixture].
  static _DemoAssistants of(DemoFixture fixture) =>
      _perSession[fixture] ??= _DemoAssistants._(fixture);

  final identity = FakeIdentityBindingRepository(
    initial: IdentityBindingStatus(
      state: IdentityBindingState.verified,
      installationId: kDemoInstallationId,
      issuer: 'demo',
      boundAt: DateTime.utc(2026),
    ),
  );
  final connections = FakeMcpConnectionRepository(
    installationId: kDemoInstallationId,
  );
  final confirmations = FakeActionConfirmationRepository();
  final admin = FakeMcpAdminRepository();
  final onboarding = FakeMcpOnboardingRepository();

  static ActionConfirmation _copy(
    ActionConfirmation c,
    ConfirmationStatus status,
  ) => ActionConfirmation(
    id: c.id,
    status: status,
    operation: c.operation,
    workspaceName: c.workspaceName,
    clientName: c.clientName,
    arguments: c.arguments,
    target: c.target,
    expiresAt: c.expiresAt,
  );
}

/// The four repositories of the assistants, the Demo's own.
List<Override> demoAssistantOverrides(DemoFixture fixture) {
  final held = _DemoAssistants.of(fixture);
  return [
    identityBindingRepositoryProvider.overrideWithValue(held.identity),
    actionConfirmationRepositoryProvider.overrideWithValue(held.confirmations),
    mcpConnectionRepositoryProvider.overrideWithValue(held.connections),
    mcpAdminRepositoryProvider.overrideWithValue(held.admin),
    mcpOnboardingRepositoryProvider.overrideWithValue(held.onboarding),
  ];
}
