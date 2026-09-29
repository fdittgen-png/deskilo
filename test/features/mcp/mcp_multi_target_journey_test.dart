// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1632 — the assembled multi-target journey on the native side, through
// the production registry, commands, policy provider, policy editor and
// confirmation answers, each target reached by its own pinned Supabase
// SDK client over a recording wire. Two installations deliberately share
// the canonical issuer, the local account UUID and a workspace UUID (A on
// D1 is D on D2): the installation is the only thing that tells them
// apart. The journey interleaves A, B and D with answers released in
// reverse, drops A's save reply, switches to B and retries in A's own
// context, answers an A confirmation while B is on screen, refuses a
// mislabelled answer, and never falls back to another target when D1 is
// down or revoked.
//
// The journey is an oracle: it returns the invariants it saw broken. It
// must return none for the real code, and it must NAME the defect when
// the registry forgets the installation in its client key, reuses one
// authenticated client for every target, or the provenance guard is
// bypassed — the controlled faults #1632 requires, injected here as
// registry subclasses and an unguarded read, never as a switch in lib/.
//
// What this does not prove: a real provider token, a real second
// installation, a browser. Those remain open items of #1632.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/features/mcp/application/answer_confirmation.dart';
import 'package:deskilo/features/mcp/application/mcp_client_registry.dart';
import 'package:deskilo/features/mcp/application/mcp_commands.dart';
import 'package:deskilo/features/mcp/application/mcp_policy_editor.dart';
import 'package:deskilo/features/mcp/data/connected_target_client.dart';
import 'package:deskilo/features/mcp/domain/action_confirmation.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/domain/mcp_client.dart';
import 'package:deskilo/features/mcp/domain/mcp_context.dart';
import 'package:deskilo/features/mcp/providers/mcp_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const _d1 = 'd1d1d1d1-0000-4000-8000-000000001632';
const _d2 = 'd2d2d2d2-0000-4000-8000-000000001632';
const _d3 = 'd3d3d3d3-0000-4000-8000-000000001632';

/// One canonical authority, one local account UUID on both databases.
const _issuer = 'https://id.deskilo.test/auth/v1';
const _account = '11111111-1632-4000-8000-000000000001';

/// A on D1 and D on D2 carry the same UUID.
const _wsA = 'aaaaaaaa-1632-4000-8000-00000000000a';
const _wsB = 'bbbbbbbb-1632-4000-8000-00000000000b';

/// One installation's database, as the wire sees it.
class _Server {
  _Server(this.name, this.revisions);

  final String name;

  /// The policy revision this database holds per workspace: the answer
  /// tells which database produced it.
  final Map<String, int> revisions;
  final calls = <(String rpc, Map<String, dynamic> body)>[];
  final applied = <String, String>{}; // mutation id -> workspace
  final _gates = <Completer<void>>[];
  bool gated = false;
  bool down = false;
  int dropSaves = 0;
  String? mislabelAs;

  int count(String rpc) => calls.where((c) => c.$1 == rpc).length;

  /// Releases held answers, newest first.
  void releaseAll() {
    for (final g in _gates.reversed.toList()) {
      g.complete();
    }
    _gates.clear();
  }

  Future<http.Response> handle(http.Request request) async {
    final rpc = request.url.pathSegments.last;
    final sent = request.body.isEmpty ? null : jsonDecode(request.body);
    final body = sent is Map<String, dynamic> ? sent : <String, dynamic>{};
    calls.add((rpc, body));
    if (down) throw http.ClientException('connection refused', request.url);
    if (gated) {
      final gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    }
    final Object answer;
    switch (rpc) {
      case 'mcp_policy_status':
        final ws = '${body['p_workspace_id']}';
        answer = {
          'workspace_id': mislabelAs ?? ws,
          'revision': revisions[ws] ?? 0,
          'enabled': true,
          'operations': ['get_capabilities'],
          'target_ceiling': 'own',
          'feature_enabled': true,
          'available_operations': ['get_capabilities'],
        };
      case 'save_mcp_policy':
        final id = '${body['p_mutation_id']}';
        final replay = applied.containsKey(id);
        applied[id] = '${body['p_workspace_id']}';
        if (!replay && dropSaves > 0) {
          dropSaves--;
          throw http.ClientException('reply lost after commit', request.url);
        }
        answer = {'status': replay ? 'replayed' : 'saved', 'revision': 4};
      case 'mcp_confirm_action':
        answer = {'status': 'acknowledged'};
      default:
        answer = <String, Object?>{};
    }
    return http.Response(
      jsonEncode(answer),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

/// A registry client for one target: its own SDK client, its own wire.
class _WireClient implements McpTargetClient {
  _WireClient(this.key, _Server server)
    : _repositories = supabaseMcpRepositories(
        SupabaseClient(
          'https://${server.name}.test',
          'sb_publishable_${server.name}',
          authOptions: const AuthClientOptions(autoRefreshToken: false),
          httpClient: MockClient(server.handle),
        ),
      );

  @override
  final McpTargetKey key;
  final McpRepositories _repositories;

  @override
  Future<T> run<T>(Future<T> Function(McpRepositories r) action) =>
      action(_repositories);

  @override
  Future<void> dispose() async {}
}

/// FAULT: the client cache forgets the installation.
class _InstallationBlindRegistry extends McpClientRegistry {
  _InstallationBlindRegistry(super.create);
  final _cache = <(String, String, McpClientPurpose), McpTargetClient>{};

  @override
  McpTargetClient resolve(McpTargetKey key) => _cache.putIfAbsent((
    key.issuer,
    key.account,
    key.purpose,
  ), () => super.resolve(key));
}

/// FAULT: one authenticated client reused for every target.
class _GlobalClientRegistry extends McpClientRegistry {
  _GlobalClientRegistry(super.create);
  McpTargetClient? _only;

  @override
  McpTargetClient resolve(McpTargetKey key) => _only ??= super.resolve(key);
}

typedef _RegistryFactory = McpClientRegistry Function(
  McpTargetClientFactory create,
);

/// Runs the journey and returns every invariant it saw broken.
Future<List<String>> _journey(
  _RegistryFactory makeRegistry, {
  bool bypassProvenance = false,
}) async {
  final broken = <String>[];
  final d1 = _Server('d1', {_wsA: 3, _wsB: 5});
  final d2 = _Server('d2', {_wsA: 7});
  final servers = {_d1: d1, _d2: d2};
  final registry = makeRegistry(
    (k, t) => _WireClient(k, servers[t.installationId]!),
  );
  final commands = McpCommands(registry);
  final container = ProviderContainer(
    overrides: [mcpCommandsProvider.overrideWithValue(commands)],
    retry: (_, _) => null,
  );
  final subs = <ProviderSubscription<Object?>>[];
  addTearDown(() {
    for (final sub in subs) {
      sub.close();
    }
    container.dispose();
  });
  final t1 = VerifiedMcpTarget(
    installationId: _d1,
    issuer: _issuer,
    account: _account,
    source: 'https://d1.test',
  );
  final t2 = VerifiedMcpTarget(
    installationId: _d2,
    issuer: _issuer,
    account: _account,
    source: 'https://d2.test',
  );
  await registry.register(t1);
  await registry.register(t2);
  final a = t1.workspace(_wsA), b = t1.workspace(_wsB), d = t2.workspace(_wsA);

  Future<McpPolicy> policy(McpContextRef ctx) async {
    if (bypassProvenance) {
      final p = await commands.read(
        ctx,
        (r) => r.admin.policy(ctx.workspaceId),
      );
      return p.withContext(ctx);
    }
    // The provider the policy screen watches; its listener stays until
    // the end of the test, as a screen's would while it is shown.
    // Each call is a fresh read (a pull to refresh), never a cached one.
    container.invalidate(mcpPolicyProvider(ctx));
    subs.add(container.listen(mcpPolicyProvider(ctx), (_, _) {}));
    return container.read(mcpPolicyProvider(ctx).future);
  }

  // 1. A, B and D interleaved; the answers come back in reverse.
  d1.gated = d2.gated = true;
  final pending = [policy(a), policy(b), policy(d)];
  await pumpEventQueue();
  d2.releaseAll();
  d1.releaseAll();
  d1.gated = d2.gated = false;
  final got = await Future.wait(pending);
  for (final (i, want, ctx) in [(0, 3, a), (1, 5, b), (2, 7, d)]) {
    if (got[i].revision != want || got[i].workspaceId != ctx.workspaceId) {
      broken.add(
        '${['A', 'B', 'D'][i]} was answered by the wrong database '
        '(revision ${got[i].revision}, expected $want)',
      );
    }
  }
  if (d1.count('mcp_policy_status') != 2 ||
      d2.count('mcp_policy_status') != 1) {
    broken.add(
      'reads reached the wrong wire: D1 ${d1.count('mcp_policy_status')}, '
      'D2 ${d2.count('mcp_policy_status')}',
    );
  }

  // 2. A's save loses its reply; the screen moves to B; the retry is A's.
  final draft = McpPolicyDraft.from(got[0])..enabled = false;
  final editor = McpPolicyEditor(commands);
  d1.dropSaves = 1;
  try {
    await editor.save(draft);
    broken.add('the lost reply was reported as a result');
  } on http.ClientException {
    // the transport failure reaches the caller
  }
  await policy(b); // the person is looking at B now
  final retried = await editor.save(draft);
  final saves = [
    ...d1.calls.where((c) => c.$1 == 'save_mcp_policy'),
    ...d2.calls.where((c) => c.$1 == 'save_mcp_policy'),
  ];
  if (retried.status != PolicySaveStatus.replayed ||
      saves.length != 2 ||
      d2.count('save_mcp_policy') != 0 ||
      saves.any(
        (s) =>
            s.$2['p_workspace_id'] != _wsA ||
            s.$2['p_mutation_id'] != draft.mutationId,
      ) ||
      d1.applied.length != 1) {
    broken.add(
      'the retry left A\'s context: $saves on D1 and '
      '${d2.count('save_mcp_policy')} on D2',
    );
  }

  // 3. An A confirmation answered while B is on screen; a double tap.
  final answers = ConfirmationAnswers(commands);
  const confirmation = ActionConfirmation(
    id: 'c-a',
    status: ConfirmationStatus.pending,
  );
  d1.gated = true;
  final screenB = policy(b);
  final taps = [
    answers.answer(confirmation.withScope(t1.instance), accept: true),
    answers.answer(confirmation.withScope(t1.instance), accept: true),
  ];
  await pumpEventQueue();
  d1.releaseAll();
  d1.gated = false;
  await Future.wait([screenB, ...taps]);
  if (d1.count('mcp_confirm_action') != 1 ||
      d2.count('mcp_confirm_action') != 0) {
    broken.add(
      'the A confirmation was sent ${d1.count('mcp_confirm_action')} '
      'time(s) to D1 and ${d2.count('mcp_confirm_action')} to D2',
    );
  }

  // 4. D2 answers for another workspace: never published as D's.
  d2.mislabelAs = _wsB;
  try {
    final wrong = await policy(d);
    broken.add(
      'a mislabelled answer (${wrong.workspaceId}) was published as D',
    );
  } on McpProvenanceMismatch {
    // refused, typed
  }
  d2.mislabelAs = null;

  // 5. D1 is down: A fails, and nothing falls back to D2.
  final d2Before = d2.calls.length;
  d1.down = true;
  try {
    await policy(a);
    broken.add('A answered while its database was down');
  } on http.ClientException {
    // A's own failure
  }
  d1.down = false;
  try {
    await commands.read(
      const McpContextRef(
        installationId: _d3,
        account: _account,
        workspaceId: _wsA,
      ),
      (r) => r.admin.policy(_wsA),
    );
    broken.add('an unverified installation was reached');
  } on McpTargetUnverified {
    // nothing sent
  }
  if (d2.calls.length != d2Before) broken.add('a D1 failure fell back to D2');

  // 6. Revoking D1 discards its late answer and leaves D2 working.
  d1.gated = true;
  final late = policy(a);
  await pumpEventQueue();
  await registry.revokeTarget(_d1);
  d1.releaseAll();
  d1.gated = false;
  try {
    await late;
    broken.add('a late D1 answer was published after the revoke');
  } on McpContextSuperseded {
    // discarded
  }
  if ((await policy(d)).revision != 7) broken.add('revoking D1 disturbed D2');
  return broken;
}

void main() {
  test('the assembled journey holds on the real registry, commands and '
      'SDK wire', () async {
    expect(await _journey(McpClientRegistry.new), isEmpty);
  });

  group('controlled faults are named by the journey', () {
    test('a client cache that forgets the installation', () async {
      expect(
        await _journey(_InstallationBlindRegistry.new),
        contains(startsWith('D was answered by the wrong database')),
      );
    });

    test('one authenticated client reused for every target', () async {
      expect(
        await _journey(_GlobalClientRegistry.new),
        contains(startsWith('D was answered by the wrong database')),
      );
    });

    test(
      'the provenance guard bypassed lets a mislabelled answer through',
      () async {
        expect(
          await _journey(McpClientRegistry.new, bypassProvenance: true),
          contains(startsWith('a mislabelled answer')),
        );
      },
    );
  });
}
