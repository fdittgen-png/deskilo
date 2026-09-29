// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — the management/confirmation client registry, keyed by verified
// installation + issuer + account + purpose. Two installations can hold
// the same account UUID and the same workspace id: they are still two
// clients, two caches, two retry ledgers. Answers are gated with
// Completers, never wall-clock delays, so "old A finishes last" is a fact
// of the test, not a timing hope.
import 'dart:async';

import 'package:deskilo/core/demo/data/action_confirmation_repository.dart';
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/features/auth/domain/identity_binding.dart';
import 'package:deskilo/features/mcp/application/active_target_client.dart';
import 'package:deskilo/features/mcp/application/answer_confirmation.dart';
import 'package:deskilo/features/mcp/application/assistant_access.dart';
import 'package:deskilo/features/mcp/application/mcp_client_registry.dart';
import 'package:deskilo/features/mcp/application/mcp_commands.dart';
import 'package:deskilo/features/mcp/application/mcp_policy_editor.dart';
import 'package:deskilo/features/mcp/data/connected_target_client.dart';
import 'package:deskilo/features/mcp/domain/action_confirmation.dart';
import 'package:deskilo/features/mcp/domain/mcp_access_status.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/domain/mcp_client.dart';
import 'package:deskilo/features/mcp/domain/mcp_connection.dart';
import 'package:deskilo/features/mcp/domain/mcp_context.dart';
import 'package:deskilo/features/mcp/providers/mcp_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _instA = 'aaaaaaaa-0000-4000-8000-000000000001';
const _instB = 'bbbbbbbb-0000-4000-8000-000000000002';

/// The same local account UUID on both installations: a coincidence the
/// registry must never read as "the same person, same client".
const _account = '11111111-2222-4333-8444-555555555555';

McpPolicy _policy(String ws, int revision) => McpPolicy(
  workspaceId: ws,
  revision: revision,
  enabled: true,
  operations: const {'get_capabilities'},
  targetCeiling: 'own',
  featureEnabled: true,
  available: const ['get_capabilities'],
);

/// Every policy read waits for the test to release it.
class _GatedAdmin extends FakeMcpAdminRepository {
  _GatedAdmin(this.name);
  final String name;
  final reads = <Completer<McpPolicy>>[];
  final queueReads = <Completer<List<EligibilityRequest>>>[];
  Object? failNextSave;
  Completer<void>? saveGate;

  @override
  Future<McpPolicy> policy(String workspaceId) {
    final c = Completer<McpPolicy>();
    reads.add(c);
    return c.future;
  }

  @override
  Future<List<EligibilityRequest>> eligibilityRequests() {
    final c = Completer<List<EligibilityRequest>>();
    queueReads.add(c);
    return c.future;
  }

  @override
  Future<PolicySaveResult> savePolicy({
    required String workspaceId,
    required int expectedRevision,
    required String mutationId,
    required bool enabled,
    required Set<String> operations,
    required String targetCeiling,
    required Set<String> optionalFields,
  }) async {
    final gate = saveGate;
    if (gate != null) await gate.future;
    final failure = failNextSave;
    failNextSave = null;
    saves.add((
      expected: expectedRevision,
      mutationId: mutationId,
      enabled: enabled,
      operations: operations,
      ceiling: targetCeiling,
      optionalFields: optionalFields,
    ));
    if (failure != null) throw failure;
    return PolicySaveResult(
      PolicySaveStatus.saved,
      revision: expectedRevision + 1,
    );
  }
}

/// One target's fakes, and whether its client was disposed.
class _Target {
  _Target(String name)
    : admin = _GatedAdmin(name),
      connections = FakeMcpConnectionRepository(),
      confirmations = FakeActionConfirmationRepository(),
      identity = FakeIdentityBindingRepository();
  final _GatedAdmin admin;
  final FakeMcpConnectionRepository connections;
  final FakeActionConfirmationRepository confirmations;
  final FakeIdentityBindingRepository identity;

  McpRepositories get repositories => McpRepositories(
    admin: admin,
    connections: connections,
    confirmations: confirmations,
    identity: identity,
  );
}

class _Client implements McpTargetClient {
  _Client(this.key, this.target);
  @override
  final McpTargetKey key;
  final _Target target;
  bool disposed = false;

  @override
  Future<T> run<T>(Future<T> Function(McpRepositories) action) =>
      action(target.repositories);

  @override
  Future<void> dispose() async => disposed = true;
}

class _World {
  final targets = {_instA: _Target('A'), _instB: _Target('B')};
  final created = <_Client>[];
  late final registry = McpClientRegistry((key, t) {
    final c = _Client(key, targets[t.installationId]!);
    created.add(c);
    return c;
  });
  late final commands = McpCommands(registry);

  final a = VerifiedMcpTarget(
    installationId: _instA,
    issuer: 'https://id.a.test',
    account: _account,
  );
  final b = VerifiedMcpTarget(
    installationId: _instB,
    issuer: 'https://id.b.test',
    account: _account,
  );

  Future<void> registerBoth() async {
    await registry.register(a);
    await registry.register(b);
  }

  ProviderContainer container() {
    final c = ProviderContainer(
      overrides: [
        mcpClientRegistryProvider.overrideWithValue(registry),
        mcpCommandsProvider.overrideWithValue(commands),
      ],
      retry: (_, _) => null,
    );
    addTearDown(c.dispose);
    return c;
  }
}

/// The active target the UI has selected, switchable by the test.
class _Selected extends Notifier<VerifiedMcpTarget> {
  _Selected(this.initial);
  final VerifiedMcpTarget initial;
  @override
  VerifiedMcpTarget build() => initial;
  void select(VerifiedMcpTarget t) => state = t;
}

void main() {
  group('keys and clients', () {
    test('the same account UUID and workspace on two installations are two '
        'clients, and revoking A leaves B untouched', () async {
      final w = _World();
      await w.registerBoth();
      final ctxA = w.a.workspace('ws-1');
      final ctxB = w.b.workspace('ws-1');
      expect(ctxA == ctxB, isFalse);
      final keyA = w.registry.keyFor(ctxA, McpClientPurpose.management);
      final keyB = w.registry.keyFor(ctxB, McpClientPurpose.management);
      expect(keyA == keyB, isFalse);
      final clientA = w.registry.resolve(keyA);
      final clientB = w.registry.resolve(keyB);
      expect(identical(clientA, clientB), isFalse);
      expect(
        identical(
          w.registry.resolve(
            w.registry.keyFor(ctxA, McpClientPurpose.confirmation),
          ),
          clientA,
        ),
        isFalse,
        reason: 'confirmation is its own client, with its own lifetime',
      );

      final outcomes = await w.registry.revokeTarget(_instA);
      expect(outcomes.keys.map((k) => k.installationId).toSet(), {_instA});
      expect(outcomes.values.toSet(), {McpDisposeOutcome.disposed});
      expect((clientA as _Client).disposed, isTrue);
      expect((clientB as _Client).disposed, isFalse);
      expect(identical(w.registry.resolve(keyB), clientB), isTrue);
      expect(
        () => w.registry.keyFor(ctxA, McpClientPurpose.management),
        throwsA(isA<McpTargetUnverified>()),
      );
    });

    test('an unverified scope, or another issuer, sends nothing', () async {
      final w = _World();
      await w.registry.register(w.a);
      expect(
        () => w.registry.keyFor(w.b.instance, McpClientPurpose.management),
        throwsA(isA<McpTargetUnverified>()),
      );
      const forged = McpTargetKey(
        installationId: _instA,
        issuer: 'https://evil.test',
        account: _account,
        purpose: McpClientPurpose.management,
      );
      expect(
        () => w.registry.resolve(forged),
        throwsA(isA<McpTargetUnverified>()),
      );
      expect(w.created, isEmpty);
      expect(
        () => VerifiedMcpTarget(
          installationId: 'not-a-uuid',
          issuer: '',
          account: _account,
        ),
        throwsA(isA<McpTargetUnverified>()),
      );
    });

    test('logout disposes every target and reports each one', () async {
      final w = _World();
      await w.registerBoth();
      w.registry.resolve(
        w.registry.keyFor(w.a.instance, McpClientPurpose.management),
      );
      w.registry.resolve(
        w.registry.keyFor(w.b.instance, McpClientPurpose.confirmation),
      );
      final outcomes = await w.registry.disposeAll();
      expect(outcomes, hasLength(2));
      expect(w.created.every((c) => c.disposed), isTrue);
    });

    test('the active backend client refuses once another account is signed '
        'in', () async {
      var signedIn = _account;
      final t = _Target('A');
      final client = ActiveMcpTargetClient(
        w0.a.key(McpClientPurpose.management),
        () => t.repositories,
        currentAccount: () => signedIn,
      );
      expect(await client.run((r) async => 'ok'), 'ok');
      signedIn = 'someone-else';
      await expectLater(
        client.run((r) async => 'late'),
        throwsA(isA<McpTargetChanged>()),
      );
    });
  });

  test(
    'a connected installation runs only through its own isolated record',
    () async {
      final connected = _RecordingInstallations();
      final registry = McpClientRegistry(
        (key, t) => ConnectedMcpTargetClient(key, connected, t.source),
      );
      final a = VerifiedMcpTarget(
        installationId: _instA,
        issuer: '',
        account: _account,
        source: 'https://a.test',
      );
      final b = VerifiedMcpTarget(
        installationId: _instB,
        issuer: '',
        account: _account,
        source: 'https://b.test',
      );
      await registry.register(a);
      await registry.register(b);
      final commands = McpCommands(registry);
      await commands.read(a.instance, (r) async => r.admin);
      await commands.read(b.instance, (r) async => r.admin);
      expect(connected.used, ['https://a.test', 'https://b.test']);
    },
  );

  group('provider races', () {
    test('old A finishing last after a switch never shows under B', () async {
      final w = _World();
      await w.registerBoth();
      final c = w.container();
      final ctxA = w.a.workspace('ws-1');
      final ctxB = w.b.workspace('ws-1');

      final subA = c.listen(mcpPolicyProvider(ctxA), (_, _) {});
      final futureA = c.read(mcpPolicyProvider(ctxA).future);
      // The UI switches to B while A is still out.
      subA.close();
      final subB = c.listen(mcpPolicyProvider(ctxB), (_, _) {});
      addTearDown(subB.close);
      final futureB = c.read(mcpPolicyProvider(ctxB).future);

      w.targets[_instB]!.admin.reads.single.complete(_policy('ws-1', 3));
      expect((await futureB).revision, 3);
      w.targets[_instA]!.admin.reads.single.complete(_policy('ws-1', 7));
      await futureA.then((_) {}, onError: (_) {});
      await pumpEventQueue();

      final shown = c.read(mcpPolicyProvider(ctxB)).value!;
      expect(shown.revision, 3, reason: 'A (revision 7) finished last');
      expect(shown.context, ctxB);
    });

    test('a late answer after sign-out is discarded, typed', () async {
      final w = _World();
      await w.registerBoth();
      final c = w.container();
      final ctxA = w.a.workspace('ws-1');
      final sub = c.listen(mcpPolicyProvider(ctxA), (_, _) {});
      addTearDown(sub.close);
      final pending = c.read(mcpPolicyProvider(ctxA).future);

      await w.registry.disposeAll();
      w.targets[_instA]!.admin.reads.single.complete(_policy('ws-1', 7));

      await expectLater(pending, throwsA(isA<McpContextSuperseded>()));
      expect(c.read(mcpPolicyProvider(ctxA)).hasValue, isFalse);
    });

    test(
      'revoking A while its read is out discards it; B still answers',
      () async {
        final w = _World();
        await w.registerBoth();
        final c = w.container();
        final ctxA = w.a.workspace('ws-1');
        final ctxB = w.b.workspace('ws-1');
        final subs = [
          c.listen(mcpPolicyProvider(ctxA), (_, _) {}),
          c.listen(mcpPolicyProvider(ctxB), (_, _) {}),
        ];
        addTearDown(() {
          for (final s in subs) {
            s.close();
          }
        });
        final a = c.read(mcpPolicyProvider(ctxA).future);
        final b = c.read(mcpPolicyProvider(ctxB).future);
        await w.registry.revokeTarget(_instA);
        w.targets[_instB]!.admin.reads.single.complete(_policy('ws-1', 3));
        w.targets[_instA]!.admin.reads.single.complete(_policy('ws-1', 7));
        expect((await b).revision, 3);
        await expectLater(a, throwsA(isA<McpContextSuperseded>()));
      },
    );

    test('the admin queue follows the installation, and a switched-away '
        'queue finishing last is not shown', () async {
      final w = _World();
      await w.registerBoth();
      final selected = NotifierProvider<_Selected, VerifiedMcpTarget>(
        () => _Selected(w.a),
      );
      final c = ProviderContainer(
        overrides: [
          mcpClientRegistryProvider.overrideWithValue(w.registry),
          mcpCommandsProvider.overrideWithValue(w.commands),
          activeMcpTargetProvider.overrideWith(
            (ref) async => ref.watch(selected),
          ),
        ],
        retry: (_, _) => null,
      );
      addTearDown(c.dispose);
      final sub = c.listen(eligibilityRequestsProvider, (_, _) {});
      addTearDown(sub.close);
      await pumpEventQueue();
      expect(w.targets[_instA]!.admin.queueReads, hasLength(1));

      c.read(selected.notifier).select(w.b);
      final current = c.read(eligibilityRequestsProvider.future);
      await pumpEventQueue();
      const req = EligibilityRequest(
        requestId: 'r',
        userId: 'u',
        email: 'b@deskilo.test',
        revision: 1,
      );
      w.targets[_instB]!.admin.queueReads.single.complete([req]);
      w.targets[_instA]!.admin.queueReads.single.complete([
        const EligibilityRequest(
          requestId: 'r',
          userId: 'u',
          email: 'a@deskilo.test',
          revision: 9,
        ),
      ]);
      final shown = await current;
      await pumpEventQueue();
      expect(
        c.read(eligibilityRequestsProvider).value!.single.email,
        'b@deskilo.test',
      );
      expect(shown.single.scope, w.b.instance);
    });
  });

  group('commands keep their captured intent', () {
    McpPolicy scoped(_World w, VerifiedMcpTarget t) =>
        _policy('ws-1', 4).withContext(t.workspace('ws-1'));

    test('a retry after switching to B is the same A request: same id, '
        'payload and client', () async {
      final w = _World();
      await w.registerBoth();
      final editor = McpPolicyEditor(w.commands);
      final draft = McpPolicyDraft.from(scoped(w, w.a))
        ..operations.add('create_reservation');
      final adminA = w.targets[_instA]!.admin
        ..failNextSave = StateError('lost');
      await expectLater(editor.save(draft), throwsStateError);

      // The UI now shows B; its own new intent is a different request.
      final draftB = McpPolicyDraft.from(scoped(w, w.b));
      await editor.save(draft);
      await editor.save(draftB);

      expect(adminA.saves, hasLength(2));
      expect(adminA.saves.map((s) => s.mutationId).toSet(), {draft.mutationId});
      expect(adminA.saves.last.operations, {
        'get_capabilities',
        'create_reservation',
      });
      final adminB = w.targets[_instB]!.admin;
      expect(adminB.saves.single.mutationId, draftB.mutationId);
      expect(draftB.mutationId, isNot(draft.mutationId));
    });

    test('a double submit sends once; a draft changed after a failure is a '
        'new intent', () async {
      final w = _World();
      await w.registerBoth();
      final editor = McpPolicyEditor(w.commands);
      final admin = w.targets[_instA]!.admin..saveGate = Completer<void>();
      final draft = McpPolicyDraft.from(scoped(w, w.a));
      final first = editor.save(draft);
      final second = editor.save(draft);
      admin.saveGate!.complete();
      admin.saveGate = null;
      await Future.wait([first, second]);
      expect(admin.saves, hasLength(1));

      final before = draft.mutationId;
      admin.failNextSave = StateError('lost');
      draft.targetCeiling = 'workspace';
      await expectLater(editor.save(draft), throwsStateError);
      draft.enabled = false;
      await editor.save(draft);
      expect(admin.saves[1].mutationId, isNot(before));
      expect(admin.saves[2].mutationId, isNot(admin.saves[1].mutationId));
    });

    test('a confirmation is answered on the installation it was read from, '
        'once per intent', () async {
      final w = _World();
      await w.registerBoth();
      final confA = w.targets[_instA]!.confirmations
        ..confirmations['c-1'] = const ActionConfirmation(
          id: 'c-1',
          status: ConfirmationStatus.pending,
        );
      final confB = w.targets[_instB]!.confirmations
        ..confirmations['c-1'] = const ActionConfirmation(
          id: 'c-1',
          status: ConfirmationStatus.pending,
        );
      final shown = (await w.commands.read(
        w.a.instance,
        (r) => r.confirmations.get('c-1'),
        purpose: McpClientPurpose.confirmation,
      )).withScope(w.a.instance);
      final answers = ConfirmationAnswers(w.commands);
      final results = await Future.wait([
        answers.answer(shown, accept: true),
        answers.answer(shown, accept: true),
      ]);
      expect(results.toSet(), {ConfirmationStatus.acknowledged});
      expect(confA.answers, hasLength(1));
      expect(confB.answers, isEmpty);
    });
  });

  group('disconnects', () {
    McpConnectionInfo connection(
      VerifiedMcpTarget t,
    ) => const McpConnectionInfo(
      clientId: 'claude',
      clientName: 'Assistant',
      workspaces: [
        ConsentWorkspace(id: 'wa', name: 'Kraftwerk', operations: ['check_in']),
        ConsentWorkspace(id: 'wb', name: 'Atelier', operations: ['check_in']),
      ],
    ).withScope(t.instance);

    test(
      'a workspace-scope disconnect ends one consent on one installation',
      () async {
        final w = _World();
        await w.registerBoth();
        final access = AssistantAccess(
          w.commands,
          FakeIdentityBindingRepository(),
        );
        final result = await access.removeWorkspace(connection(w.a), 'wa');
        expect(w.targets[_instA]!.connections.calls, ['revokeScope:claude:wa']);
        expect(w.targets[_instB]!.connections.calls, isEmpty);
        expect(result.scope, McpDisconnectScope.workspace);
        expect(result.ends(w.a.workspace('wa')), isTrue);
        expect(result.ends(w.a.workspace('wb')), isFalse);
        expect(
          result.ends(w.b.workspace('wa')),
          isFalse,
          reason: 'the same workspace id on B is another context',
        );
      },
    );

    test('a database-level disconnect ends every workspace of that assistant '
        'there, and nothing on B', () async {
      final w = _World();
      await w.registerBoth();
      final access = AssistantAccess(
        w.commands,
        FakeIdentityBindingRepository(),
      );
      final result = await access.disconnect(connection(w.a));
      expect(w.targets[_instA]!.connections.calls, ['disconnect:claude']);
      expect(w.targets[_instB]!.connections.calls, isEmpty);
      expect(result.scope, McpDisconnectScope.database);
      expect(result.workspaces, {'wa', 'wb'});
    });
  });

  group('status dimensions', () {
    test(
      'one identity and one eligibility, independent workspace facts',
      () async {
        final w = _World();
        final identity =
            FakeIdentityBindingRepository(
                initial: IdentityBindingStatus(
                  state: IdentityBindingState.verified,
                  installationId: _instA,
                  issuer: 'https://id.a.test',
                  boundAt: DateTime.utc(2026),
                ),
              )
              ..capabilities = DatabaseCapabilities(
                eligibility: McpEligibility.eligible,
                eligibleUntil: DateTime.utc(2027),
              );
        const one = ConsentWorkspace(
          id: 'ws-1',
          name: 'One',
          operations: ['check_in'],
        );
        final connections =
            FakeMcpConnectionRepository(
                consent: const ConsentOptions(
                  eligible: true,
                  workspaces: [one],
                ),
              )
              ..live.add(
                const McpConnectionInfo(
                  clientId: 'claude',
                  clientName: 'Assistant',
                  workspaces: [one],
                ),
              );
        final repos = McpRepositories(
          // A member reads no owner policy: exposure comes from the offer.
          admin: _NoPolicy(),
          connections: connections,
          confirmations: FakeActionConfirmationRepository(),
          identity: identity,
        );
        final registry = McpClientRegistry(
          (key, _) => _StaticClient(key, repos),
        );
        await registry.register(w.a);
        final c = ProviderContainer(
          overrides: [
            mcpClientRegistryProvider.overrideWithValue(registry),
            mcpCommandsProvider.overrideWithValue(McpCommands(registry)),
          ],
          retry: (_, _) => null,
        );
        addTearDown(c.dispose);
        Future<McpAccessStatus> status(String ws) {
          final p = mcpAccessStatusProvider(w.a.workspace(ws));
          final sub = c.listen(p, (_, _) {});
          addTearDown(sub.close);
          return c.read(p.future);
        }

        final first = await status('ws-1');
        final second = await status('ws-2');
        expect(first.identity, McpIdentityState.verified);
        expect(second.identity, first.identity);
        expect(first.eligibility, McpEligibilityState.approved);
        expect(second.eligibility, first.eligibility);
        expect(first.exposure, McpExposureState.exposed);
        expect(first.next, McpNextStep.ready);
        expect(second.consent, McpConsentState.missing);
        expect(
          second.next,
          isNot(
            anyOf(McpNextStep.requestEligibility, McpNextStep.awaitEligibility),
          ),
          reason: 'a new workspace never asks for another signup or review',
        );
      },
    );

    test('unknown answers stay unavailable, never permissive', () {
      final s = McpAccessStatus.derive(
        _w0Ctx,
        identity: null,
        capabilities: DatabaseCapabilities.unavailable,
        policy: null,
        options: null,
        connections: null,
      );
      expect(s.backend, McpBackendState.unavailable);
      expect(s.exposure, McpExposureState.unavailable);
      expect(s.consent, McpConsentState.unavailable);
      expect(s.next, McpNextStep.unavailable);
      final pending = McpAccessStatus.derive(
        _w0Ctx,
        identity: const IdentityBindingStatus(
          state: IdentityBindingState.unlinked,
        ),
        capabilities: const DatabaseCapabilities(
          eligibility: McpEligibility.requested,
        ),
        policy: null,
        options: null,
        connections: const [],
      );
      expect(pending.eligibility, McpEligibilityState.pending);
      expect(pending.next, McpNextStep.linkIdentity);
    });
  });
}

final w0 = _World();
final _w0Ctx = w0.a.workspace('ws-0');

class _RecordingInstallations extends FakeConnectedInstallations {
  final used = <String>[];
  @override
  Future<T> use<T>(String source, Future<T> Function(SupabaseClient) action) {
    used.add(source);
    return action(
      SupabaseClient(
        source,
        'sb_publishable_test',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      ),
    );
  }
}

class _NoPolicy extends FakeMcpAdminRepository {
  @override
  Future<McpPolicy> policy(String workspaceId) =>
      Future.error(StateError('owners only'));
}

class _StaticClient implements McpTargetClient {
  _StaticClient(this.key, this.repositories);
  @override
  final McpTargetKey key;
  final McpRepositories repositories;
  @override
  Future<T> run<T>(Future<T> Function(McpRepositories) action) =>
      action(repositories);
  @override
  Future<void> dispose() async {}
}
