// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 — Settings → Assistant setup, driven through its buttons. Opening
// the screen sends nothing. "Turn on" writes mcpAccess for the workspace the
// list was read for, and is offered only to a holder of manageConfiguration.
// "Use the recommended set" shows exactly what it adds and removes, sends
// nothing on cancel, and on Apply saves the recommended operations with
// the own-records ceiling; a concurrent change is reported, not overwritten.
// "Ask for access" sends the request and the step then waits on a
// database administrator. The connector URL is the backend's own function.
// The strings exist in five languages (French rendered here).
import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/core/demo/data/instance_repository.dart';
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/mcp/mcp_operations.dart';
import 'package:deskilo/features/auth/domain/identity_binding.dart';
import 'package:deskilo/features/mcp/application/assistant_setup.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/presentation/assistant_setup_screen.dart';
import 'package:deskilo/features/workspace/domain/instance_responsibles.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _ws = 'ws-1';

McpPolicy _policy({
  bool feature = true,
  bool enabled = false,
  Set<String> ops = const {},
  String ceiling = 'own',
}) => McpPolicy(
  workspaceId: _ws,
  revision: 4,
  enabled: enabled,
  operations: ops,
  targetCeiling: ceiling,
  featureEnabled: feature,
  available: mcpOperations.keys.toList(),
);

FakeIdentityBindingRepository _identity({
  IdentityBindingState state = IdentityBindingState.verified,
  McpEligibility eligibility = McpEligibility.notRequested,
  bool runtime = true,
}) =>
    FakeIdentityBindingRepository(initial: IdentityBindingStatus(state: state))
      ..capabilities = DatabaseCapabilities(
        eligibility: eligibility,
        runtimeEnabled: runtime,
      );

const _all = {
  WorkspacePermission.manageIntegrations,
  WorkspacePermission.manageConfiguration,
};

Future<void> _pump(
  WidgetTester tester, {
  required FakeIdentityBindingRepository identity,
  required FakeMcpAdminRepository admin,
  FakeInstanceRepository? instance,
  FakeWorkspaceRepository? workspace,
  Set<WorkspacePermission> permissions = _all,
  bool featureOn = true,
  String backendUrl = '',
  Locale locale = const Locale('en'),
}) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final router = GoRouter(
    routes: [
      GoRoute(path: '/', builder: (_, _) => const AssistantSetupScreen()),
      GoRoute(
        path: '/settings/assistants',
        builder: (_, _) => const Text('policy', key: ValueKey('policy-page')),
      ),
      GoRoute(
        path: '/linked-accounts',
        builder: (_, _) => const Text('linked', key: ValueKey('linked-page')),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          identityBinding: identity,
          mcpAdmin: admin,
          workspace: workspace ?? FakeWorkspaceRepository.withWorkspace(),
          instance: instance,
        ),
        myPermissionsProvider.overrideWithValue(permissions),
        enabledFeaturesSyncProvider.overrideWithValue(
          featureOn ? const {WorkspaceFeature.mcpAccess} : const {},
        ),
        bootedBackendUrlProvider.overrideWithValue(backendUrl),
      ],
      retry: (_, _) => null,
      child: MaterialApp.router(
        routerConfig: router,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Finder _key(String k) => find.byKey(ValueKey(k));

Future<void> _tap(WidgetTester tester, String key) async {
  await tester.ensureVisible(_key(key));
  await tester.tap(_key(key));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('opening the screen sends nothing; each step shows its state', (
    tester,
  ) async {
    final admin = FakeMcpAdminRepository(policy: _policy());
    final repo = FakeWorkspaceRepository.withWorkspace();
    await _pump(tester, identity: _identity(), admin: admin, workspace: repo);
    for (final k in [
      'assistant-setup-identity-done',
      'assistant-setup-workspace-done',
      'assistant-setup-policy-todo',
      'assistant-setup-eligibility-todo',
      'assistant-setup-installation-done',
      'assistant-setup-connect-blocked',
      'assistant-setup-next-policy',
    ]) {
      expect(_key(k), findsOneWidget, reason: k);
    }
    expect(admin.saves, isEmpty);
    expect(repo.flagWrites, isEmpty);
  });

  testWidgets('Turn on writes mcpAccess for this workspace', (tester) async {
    final repo = FakeWorkspaceRepository.withWorkspace();
    await _pump(
      tester,
      identity: _identity(),
      admin: FakeMcpAdminRepository(policy: _policy(feature: false)),
      workspace: repo,
      featureOn: false,
    );
    expect(_key('assistant-setup-workspace-todo'), findsOneWidget);
    expect(_key('assistant-setup-policy-blocked'), findsOneWidget);
    expect(_key('assistant-setup-recommended'), findsNothing);
    await _tap(tester, 'assistant-setup-turn-on');
    expect(repo.flagWrites, hasLength(1));
    expect(repo.flagWrites.single[WorkspaceFeature.mcpAccess.dbKey], isTrue);
  });

  testWidgets('without manageConfiguration the step waits on a configurer '
      'and offers no button', (tester) async {
    await _pump(
      tester,
      identity: _identity(),
      admin: FakeMcpAdminRepository(policy: _policy(feature: false)),
      permissions: const {WorkspacePermission.manageIntegrations},
      featureOn: false,
    );
    expect(_key('assistant-setup-workspace-waiting'), findsOneWidget);
    expect(_key('assistant-setup-turn-on'), findsNothing);
    expect(
      find.textContaining('manages this workspace\'s configuration'),
      findsWidgets,
    );
  });

  testWidgets('the recommended set: preview, cancel sends nothing, apply '
      'saves exactly the set with the own-records ceiling', (tester) async {
    final admin = FakeMcpAdminRepository(
      policy: _policy(
        ops: const {'list_pending_validations'},
        ceiling: 'workspace',
      ),
    );
    await _pump(tester, identity: _identity(), admin: admin);
    await _tap(tester, 'assistant-setup-recommended');
    expect(_key('assistant-setup-preview'), findsOneWidget);
    expect(_key('assistant-setup-preview-add-check_in'), findsOneWidget);
    expect(
      _key('assistant-setup-preview-remove-list_pending_validations'),
      findsOneWidget,
    );
    expect(_key('assistant-setup-preview-own'), findsOneWidget);
    await _tap(tester, 'assistant-setup-preview-cancel');
    expect(admin.saves, isEmpty);

    await _tap(tester, 'assistant-setup-recommended');
    await _tap(tester, 'assistant-setup-preview-apply');
    final save = admin.saves.single;
    expect(save.operations, recommendedMcpOperations(mcpOperations.keys));
    expect(save.enabled, isTrue);
    expect(save.ceiling, 'own');
    expect(save.expected, 4);
    expect(find.text('Saved.'), findsOneWidget);
    expect(_key('assistant-setup-policy-done'), findsOneWidget);
  });

  testWidgets('a concurrent change is reported, not overwritten', (
    tester,
  ) async {
    final admin = FakeMcpAdminRepository(policy: _policy())
      ..nextSave = PolicySaveStatus.stale;
    await _pump(tester, identity: _identity(), admin: admin);
    await _tap(tester, 'assistant-setup-recommended');
    await _tap(tester, 'assistant-setup-preview-apply');
    expect(admin.saves, hasLength(1));
    expect(
      find.text(
        'Someone changed the offer meanwhile. Review it and try again.',
      ),
      findsOneWidget,
    );
    expect(_key('assistant-setup-policy-todo'), findsOneWidget);
  });

  testWidgets('a policy already exactly the set: no change, no Apply', (
    tester,
  ) async {
    final admin = FakeMcpAdminRepository(
      policy: _policy(
        enabled: true,
        ops: recommendedMcpOperations(mcpOperations.keys),
      ),
    );
    await _pump(tester, identity: _identity(), admin: admin);
    expect(_key('assistant-setup-policy-done'), findsOneWidget);
    expect(_key('assistant-setup-recommended'), findsOneWidget);
    await _tap(tester, 'assistant-setup-recommended');
    expect(_key('assistant-setup-preview-unchanged'), findsOneWidget);
    expect(_key('assistant-setup-preview-apply'), findsNothing);
  });

  testWidgets('Customise opens the existing policy screen', (tester) async {
    await _pump(
      tester,
      identity: _identity(),
      admin: FakeMcpAdminRepository(policy: _policy()),
    );
    await _tap(tester, 'assistant-setup-customise');
    expect(_key('policy-page'), findsOneWidget);
  });

  testWidgets('Ask for access sends the request; the step then waits on a '
      'database administrator', (tester) async {
    final identity = _identity();
    await _pump(
      tester,
      identity: identity,
      admin: FakeMcpAdminRepository(
        policy: _policy(enabled: true, ops: {'check_in'}),
      ),
    );
    await _tap(tester, 'assistant-setup-request');
    expect(identity.capabilities.eligibility, McpEligibility.requested);
    expect(_key('assistant-setup-eligibility-waiting'), findsOneWidget);
    expect(_key('assistant-setup-request'), findsNothing);
  });

  testWidgets('an unlinked identity is confirmed in place', (tester) async {
    final identity = _identity(
      state: IdentityBindingState.unlinked,
      eligibility: McpEligibility.noIdentity,
    )..finalizeAnswer =
        const IdentityBindingStatus(state: IdentityBindingState.verified);
    await _pump(
      tester,
      identity: identity,
      admin: FakeMcpAdminRepository(policy: _policy()),
    );
    expect(_key('assistant-setup-eligibility-blocked'), findsOneWidget);
    expect(_key('assistant-setup-request'), findsNothing);
    await _tap(tester, 'assistant-setup-link-identity');
    expect(identity.finalizeCalls, 1);
    expect(_key('linked-page'), findsNothing);
  });

  testWidgets('runtime off: the installation waits on the instance owner, '
      'with no action here', (tester) async {
    await _pump(
      tester,
      identity: _identity(eligibility: McpEligibility.eligible, runtime: false),
      admin: FakeMcpAdminRepository(
        policy: _policy(enabled: true, ops: {'check_in'}),
      ),
    );
    expect(_key('assistant-setup-installation-waiting'), findsOneWidget);
    expect(_key('assistant-setup-next-installation'), findsOneWidget);
    expect(
      find.textContaining('the instance owner or a delegate'),
      findsWidgets,
    );
  });

  testWidgets('runtime off: the step names who answers for the database, '
      'by name only — never their address', (tester) async {
    await _pump(
      tester,
      identity: _identity(eligibility: McpEligibility.eligible, runtime: false),
      admin: FakeMcpAdminRepository(
        policy: _policy(enabled: true, ops: {'check_in'}),
      ),
      instance: FakeInstanceRepository(
        state: const InstanceResponsibles(
          owners: [
            InstanceResponsible(name: 'Ines', email: 'ines@example.org'),
          ],
          delegates: [
            InstanceResponsible(name: 'Dario', email: 'dario@example.org'),
          ],
        ),
      ),
    );
    expect(_key('assistant-setup-instance-names'), findsOneWidget);
    expect(
      find.text('Answering for this database: Ines, Dario.'),
      findsOneWidget,
    );
    expect(find.textContaining('@example.org'), findsNothing);
  });

  testWidgets('an operator looking is told it is theirs to do', (tester) async {
    await _pump(
      tester,
      identity: _identity(eligibility: McpEligibility.eligible, runtime: false),
      admin: FakeMcpAdminRepository(
        policy: _policy(enabled: true, ops: {'check_in'}),
      ),
      instance: FakeInstanceRepository(
        state: const InstanceResponsibles(you: InstanceRole.delegate),
      ),
    );
    expect(_key('assistant-setup-instance-you'), findsOneWidget);
  });

  testWidgets('nobody recorded yet: said plainly', (tester) async {
    await _pump(
      tester,
      identity: _identity(eligibility: McpEligibility.eligible, runtime: false),
      admin: FakeMcpAdminRepository(
        policy: _policy(enabled: true, ops: {'check_in'}),
      ),
      instance: FakeInstanceRepository(state: const InstanceResponsibles()),
    );
    expect(_key('assistant-setup-instance-nobody'), findsOneWidget);
  });

  testWidgets('connect: the backend\'s connector URL to copy', (tester) async {
    await _pump(
      tester,
      identity: _identity(eligibility: McpEligibility.eligible),
      admin: FakeMcpAdminRepository(
        policy: _policy(enabled: true, ops: {'check_in'}),
      ),
      backendUrl: 'https://abc.supabase.co',
    );
    expect(_key('assistant-setup-connect-todo'), findsOneWidget);
    expect(
      find.text('https://abc.supabase.co/functions/v1/deskilo-mcp'),
      findsOneWidget,
    );
    expect(_key('assistant-setup-copy-url'), findsOneWidget);
  });

  testWidgets('without a backend there is no URL to copy', (tester) async {
    await _pump(
      tester,
      identity: _identity(eligibility: McpEligibility.eligible),
      admin: FakeMcpAdminRepository(
        policy: _policy(enabled: true, ops: {'check_in'}),
      ),
    );
    expect(_key('assistant-setup-no-connector'), findsOneWidget);
    expect(_key('assistant-setup-copy-url'), findsNothing);
  });

  testWidgets('a server that predates the answers reads unknown, never done', (
    tester,
  ) async {
    await _pump(
      tester,
      identity: FakeIdentityBindingRepository(
        initial: const IdentityBindingStatus(
          state: IdentityBindingState.unavailable,
        ),
      ),
      admin: FakeMcpAdminRepository(policy: _policy()),
    );
    expect(_key('assistant-setup-identity-unavailable'), findsOneWidget);
    expect(_key('assistant-setup-eligibility-unavailable'), findsOneWidget);
    expect(_key('assistant-setup-installation-unavailable'), findsOneWidget);
    expect(_key('assistant-setup-next-identity'), findsOneWidget);
  });

  testWidgets('French: the steps read in the workspace language', (
    tester,
  ) async {
    await _pump(
      tester,
      identity: _identity(),
      admin: FakeMcpAdminRepository(policy: _policy()),
      locale: const Locale('fr'),
    );
    expect(find.text('Configuration des assistants'), findsOneWidget);
    expect(
      find.text('Choisir ce que les assistants peuvent faire'),
      findsOneWidget,
    );
    expect(find.text('Utiliser la sélection recommandée'), findsOneWidget);
  });
}
