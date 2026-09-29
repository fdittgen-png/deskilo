// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1625 — a database decision on a connected installation is checked
// against THAT installation's second factor, through its own registry
// client and session. The active backend at aal2 never vouches for it; a
// target at aal1 is refused, typed (`secondFactorRequired`), and nothing
// is sent to its decision RPC. Enrolment and the code go to the same
// target. Two layers: fake clients at the application seam, then the
// pinned Supabase SDK over HTTP fixtures — the real adapters, the real
// per-origin session record, restore and refresh — including a refresh
// that is still out when its target is revoked.
import 'dart:async';
import 'dart:convert';

import 'package:deskilo/core/backend/backend_settings.dart';
import 'package:deskilo/core/backend/connected_installations.dart';
import 'package:deskilo/core/demo/data/action_confirmation_repository.dart';
import 'package:deskilo/core/demo/data/identity_binding_repository.dart';
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_connection_repository.dart';
import 'package:deskilo/features/mcp/application/eligibility_review.dart';
import 'package:deskilo/features/mcp/application/mcp_client_registry.dart';
import 'package:deskilo/features/mcp/application/mcp_commands.dart';
import 'package:deskilo/features/mcp/data/connected_target_client.dart';
import 'package:deskilo/features/mcp/domain/mcp_admin.dart';
import 'package:deskilo/features/mcp/domain/mcp_client.dart';
import 'package:deskilo/features/mcp/domain/mcp_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/backend/installation_auth_storage_test.dart'
    show MemorySecrets;

const _instA = 'aaaaaaaa-0000-4000-8000-00000000000a';
const _instB = 'bbbbbbbb-0000-4000-8000-00000000000b';
const _instC = 'cccccccc-0000-4000-8000-00000000000c';

const _request = EligibilityRequest(
  requestId: 'r-1',
  userId: '99999999-0000-4000-8000-000000000001',
  email: 'ada@deskilo.test',
  revision: 3,
);

class _Target {
  final admin = FakeMcpAdminRepository();
  final factor = FakeSecondFactorRepository();

  McpRepositories get repositories => McpRepositories(
    admin: admin,
    connections: FakeMcpConnectionRepository(),
    confirmations: FakeActionConfirmationRepository(),
    identity: FakeIdentityBindingRepository(),
    secondFactor: factor,
  );
}

class _Client implements McpTargetClient {
  _Client(this.key, this.target);
  @override
  final McpTargetKey key;
  final _Target target;

  @override
  Future<T> run<T>(Future<T> Function(McpRepositories) action) =>
      action(target.repositories);

  @override
  Future<void> dispose() async {}
}

// --- HTTP fixtures -------------------------------------------------------

Map<String, Object?> _user(String id) => {
  'id': id,
  'aud': 'authenticated',
  'role': 'authenticated',
  'created_at': '2026-09-28T00:00:00Z',
  'app_metadata': <String, Object?>{},
  'user_metadata': <String, Object?>{},
  'factors': [
    {
      'id': 'f-$id',
      'factor_type': 'totp',
      'status': 'verified',
      'created_at': '2026-09-28T00:00:00Z',
      'updated_at': '2026-09-28T00:00:00Z',
    },
  ],
};

/// A session whose token carries [aal]; the refresh token names it too,
/// so a refresh answers the level the session had (as Auth does).
Map<String, Object?> _session(String id, String aal) {
  final claims = base64Url.encode(
    utf8.encode(
      jsonEncode({
        'sub': id,
        'aal': aal,
        'exp': 4102444800 /* fixed year 2100: the SDK checks real expiry */,
      }),
    ),
  );
  return {
    'access_token': 'e30.$claims.signature',
    'refresh_token': '$id|$aal',
    'expires_in': 3600,
    'token_type': 'bearer',
    'user': _user(id),
  };
}

/// Two installations, each its own origin, account and session level.
class _Wire {
  _Wire(this.homeToken);
  final String homeToken;
  final installations = {'b.example': _instB, 'c.example': _instC};
  final decisions = <String, List<Map<String, dynamic>>>{};
  final bearers = <String, Set<String>>{};

  /// Holds the next refresh on this host until the test releases it.
  final refreshGates = <String, Completer<void>>{};

  http.Client call() => MockClient((request) async {
    final host = request.url.host;
    final account = '$host-user';
    final bearer = request.headers['authorization'] ?? '';
    expect(bearer, isNot('Bearer $homeToken'), reason: 'home bearer leaked');
    bearers.putIfAbsent(host, () => {}).add(bearer);
    Object? body;
    switch (request.url.path) {
      case '/auth/v1/token':
        if (request.url.queryParameters['grant_type'] == 'refresh_token') {
          await refreshGates.remove(host)?.future;
          final token =
              (jsonDecode(request.body) as Map)['refresh_token'] as String;
          body = _session(account, token.split('|').last);
        } else {
          body = _session(account, 'aal1');
        }
      case '/auth/v1/user':
        body = _user(account);
      case '/rest/v1/installation_identity':
        body = {'installation_id': installations[host]};
      case '/rest/v1/rpc/my_financial_activity':
        body = <Object>[];
      case final p when p.endsWith('/challenge'):
        body = {'id': 'ch-$host', 'type': 'totp', 'expires_at': 4102444800};
      case final p when p.endsWith('/verify'):
        final code = (jsonDecode(request.body) as Map)['code'];
        if (code != '123456') {
          return http.Response(
            jsonEncode({'code': 'mfa_verification_failed', 'msg': 'no'}),
            422,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }
        body = _session(account, 'aal2');
      case '/rest/v1/rpc/decide_mcp_eligibility':
        decisions
            .putIfAbsent(host, () => [])
            .add(jsonDecode(request.body) as Map<String, dynamic>);
        body = {'status': 'approved'};
      default:
        throw StateError('unexpected ${request.url}');
    }
    return http.Response(
      jsonEncode(body),
      200,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  });
}

void main() {
  group('application seam', () {
    late Map<String, _Target> targets;
    late McpClientRegistry registry;
    late EligibilityReview review;
    final a = VerifiedMcpTarget(
      installationId: _instA,
      issuer: 'https://id.a.test',
      account: 'same-account',
    );
    final b = VerifiedMcpTarget(
      installationId: _instB,
      issuer: 'https://id.b.test',
      account: 'same-account',
      source: 'https://b.test',
    );

    setUp(() async {
      targets = {_instA: _Target(), _instB: _Target()};
      registry = McpClientRegistry(
        (key, t) => _Client(key, targets[t.installationId]!),
      );
      await registry.register(a);
      await registry.register(b);
      // The screen administers the ACTIVE installation, A.
      review = EligibilityReview(McpCommands(registry), instance: a.instance);
    });

    test('a decision on B is checked against B, not the active A at aal2; '
        'enrolment and the code go to B', () async {
      final ta = targets[_instA]!, tb = targets[_instB]!;
      ta.factor.aal2 = true;
      final onB = _request.withScope(b.instance);

      expect(
        await review.decide(onB, approve: true),
        EligibilityDecisionStatus.secondFactorRequired,
      );
      expect(tb.admin.decisions, isEmpty, reason: 'nothing sent at aal1');
      expect(ta.admin.decisions, isEmpty, reason: 'never decided on A');
      expect((await review.secondFactor(b.instance)).aal2, isFalse);

      await review.enroll(b.instance);
      await review.verify('factor-1', '123456', b.instance);
      expect((tb.factor.enrollments, tb.factor.aal2), (1, true));
      expect(ta.factor.enrollments, 0);

      expect(
        await review.decide(onB, approve: true),
        EligibilityDecisionStatus.decided,
      );
      expect(tb.admin.decisions.single.userId, _request.userId);
      expect(ta.admin.decisions, isEmpty);
    });

    test('B at aal2 decides without A\'s factor; A at aal1 stays refused '
        'on A', () async {
      final ta = targets[_instA]!, tb = targets[_instB]!;
      tb.factor.aal2 = true;
      expect(
        await review.decide(_request.withScope(b.instance), approve: false),
        EligibilityDecisionStatus.decided,
      );
      expect(
        await review.decide(_request.withScope(a.instance), approve: false),
        EligibilityDecisionStatus.secondFactorRequired,
      );
      expect(tb.admin.decisions.single.approve, isFalse);
      expect(ta.admin.decisions, isEmpty);
      expect((await review.secondFactor()).aal2, isFalse, reason: 'A');
    });

    test('a scope with no verified target is refused before anything is '
        'sent', () async {
      const unknown = McpInstanceRef(
        installationId: _instC,
        account: 'same-account',
      );
      await expectLater(
        () => review.decide(_request.withScope(unknown), approve: true),
        throwsA(isA<McpTargetUnverified>()),
      );
      await expectLater(
        () => review.secondFactor(unknown),
        throwsA(isA<McpTargetUnverified>()),
      );
      for (final t in targets.values) {
        expect(t.admin.decisions, isEmpty);
      }
    });
  });

  group('real SDK over HTTP fixtures', () {
    late SupabaseClient home;
    late _Wire wire;
    late ConnectedInstallations connections;
    late McpClientRegistry registry;

    setUp(() async {
      home = SupabaseClient(
        'https://home.example',
        'sb_publishable_home',
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      // The HOME session is at aal2: it must vouch for nothing elsewhere.
      await home.auth.setInitialSession(
        jsonEncode(_session('home-user', 'aal2')),
      );
      wire = _Wire(home.auth.currentSession!.accessToken);
      connections = ConnectedInstallations(
        home,
        MemorySecrets(),
        transport: wire.call,
      );
      for (final host in ['b', 'c']) {
        await connections.connect(
          BackendEndpoint(
            'https://$host.example',
            'sb_publishable_${host}_target',
          ),
          'ada@$host.example',
          'password',
        );
      }
      registry = McpClientRegistry(
        (key, t) => ConnectedMcpTargetClient(key, connections, t.source),
      );
    });

    VerifiedMcpTarget target(String host, String installation) =>
        VerifiedMcpTarget(
          installationId: installation,
          issuer: '',
          account: '$host.example-user',
          source: 'https://$host.example',
        );

    test('B\'s own session is checked and verified, and B\'s bearer '
        'decides; the home aal2 session is untouched', () async {
      final homeToken = home.auth.currentSession!.accessToken;
      final b = target('b', _instB);
      await registry.register(b);
      final review = EligibilityReview(McpCommands(registry));
      final onB = _request.withScope(b.instance);

      expect(
        await review.decide(onB, approve: true),
        EligibilityDecisionStatus.secondFactorRequired,
      );
      expect(wire.decisions, isEmpty, reason: 'nothing sent at aal1');

      await expectLater(
        review.verify('f-b.example-user', '000000', b.instance),
        throwsA(isA<AuthException>()),
      );
      expect(
        await review.decide(onB, approve: true),
        EligibilityDecisionStatus.secondFactorRequired,
        reason: 'a wrong code leaves B at aal1',
      );

      await review.verify('f-b.example-user', '123456', b.instance);
      expect(
        await review.decide(onB, approve: true),
        EligibilityDecisionStatus.decided,
      );
      final sent = wire.decisions['b.example']!.single;
      expect(sent['p_subject'], _request.userId);
      expect(sent['p_expected_revision'], 3);
      expect(wire.decisions.keys, ['b.example']);
      expect(home.auth.currentSession!.accessToken, homeToken);
    });

    test('a refresh still out when its target is revoked: the late answer '
        'is discarded, the other target answers', () async {
      final b = target('b', _instB), c = target('c', _instC);
      await registry.register(b);
      await registry.register(c);
      final review = EligibilityReview(McpCommands(registry));
      for (final t in [b, c]) {
        await review.verify('f-x', '123456', t.instance);
      }
      final gate = wire.refreshGates['c.example'] = Completer<void>();
      final late = review.decide(_request.withScope(c.instance), approve: true);
      final other = review.decide(
        _request.withScope(b.instance),
        approve: true,
      );
      expect(await other, EligibilityDecisionStatus.decided);
      await registry.revokeTarget(_instC);
      gate.complete();
      await expectLater(late, throwsA(isA<McpContextSuperseded>()));
      expect(wire.decisions['b.example'], hasLength(1));
      expect(
        wire.bearers['b.example']!.intersection(wire.bearers['c.example']!),
        isEmpty,
        reason: 'each installation is reached with its own session only',
      );
    });
  });
}
