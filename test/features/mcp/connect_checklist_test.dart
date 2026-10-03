// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — the Connect an assistant checklist: each row names who acts and
// the one action that moves it, a missing answer is never done, and the
// single-operator installation whose own request waits (the production
// case of 2026-10-03) points the operator at the installation console
// instead of waiting forever. The snippets each assistant needs are built
// from the same connector URL, encoded exactly as each client reads them.
import 'dart:convert';

import 'package:deskilo/core/mcp/mcp_endpoint.dart';
import 'package:deskilo/features/auth/domain/database_capabilities.dart';
import 'package:deskilo/features/mcp/application/connect_checklist.dart';
import 'package:deskilo/features/mcp/domain/mcp_access_status.dart';
import 'package:deskilo/features/mcp/domain/mcp_context.dart';
import 'package:flutter_test/flutter_test.dart';

final _now = DateTime.utc(2026, 10, 3, 12);
const _ctx = McpContextRef(
  installationId: 'inst-1',
  account: 'acc-1',
  workspaceId: 'ws-1',
);

McpAccessStatus _status({
  McpGoogleState google = McpGoogleState.ready,
  McpIdentityState identity = McpIdentityState.verified,
  McpEligibilityState eligibility = McpEligibilityState.approved,
  McpExposureState exposure = McpExposureState.exposed,
  McpRoleState role = McpRoleState.allowed,
  McpConsentState consent = McpConsentState.missing,
}) => McpAccessStatus(
  context: _ctx,
  google: google,
  identity: identity,
  eligibility: eligibility,
  exposure: exposure,
  role: role,
  consent: consent,
  backend: McpBackendState.available,
);

DatabaseCapabilities _caps({
  McpEligibility eligibility = McpEligibility.eligible,
  bool runtime = true,
  DateTime? until,
}) => DatabaseCapabilities(
  eligibility: eligibility,
  runtimeEnabled: runtime,
  eligibleUntil: until ?? _now.add(const Duration(days: 80)),
);

ConnectChecklist _derive(
  McpAccessStatus s, {
  DatabaseCapabilities? caps,
  bool operator = false,
  bool manages = false,
}) => ConnectChecklist.derive(
  status: s,
  capabilities: caps ?? _caps(),
  now: _now,
  isOperator: operator,
  canManageIntegrations: manages,
);

void main() {
  group('the checklist', () {
    test('everything in place leaves only the connector to add', () {
      final list = _derive(_status());
      expect(
        [for (final i in list.items) i.state],
        [...List.filled(5, ConnectState.done), ConnectState.todo],
      );
      expect(list.next!.step, ConnectStep.connect);
      expect(list.next!.action, ConnectAction.addConnector);
      expect(_derive(_status(consent: McpConsentState.current)).next, isNull);
    });

    test('Google first: each Google state names its own action', () {
      final link = _derive(_status(google: McpGoogleState.linkGoogle));
      expect(link.item(ConnectStep.google).action, ConnectAction.linkGoogle);
      expect(link.item(ConnectStep.identity).state, ConnectState.blocked);
      final sign = _derive(_status(google: McpGoogleState.signInWithGoogle));
      expect(
        sign.item(ConnectStep.google).action,
        ConnectAction.signInWithGoogle,
      );
      expect(
        _derive(_status(google: McpGoogleState.unavailable))
            .item(ConnectStep.google)
            .state,
        ConnectState.unavailable,
      );
    });

    test('an unlinked identity is the person\'s own step', () {
      final list = _derive(_status(identity: McpIdentityState.unlinked));
      final row = list.item(ConnectStep.identity);
      expect(
        (row.state, row.actor, row.action),
        (ConnectState.todo, ConnectActor.you, ConnectAction.confirmIdentity),
      );
      expect(list.item(ConnectStep.access).state, ConnectState.blocked);
      expect(list.item(ConnectStep.connect).state, ConnectState.blocked);
    });

    test('access not asked or lapsed: you ask for it', () {
      for (final e in [
        McpEligibilityState.notRequested,
        McpEligibilityState.revoked,
      ]) {
        final row = _derive(_status(eligibility: e)).item(ConnectStep.access);
        expect(
          (row.state, row.action),
          (ConnectState.todo, ConnectAction.requestAccess),
        );
      }
    });

    test('a pending request waits on a database administrator; the '
        'operator is sent to the installation console, a member is not', () {
      final member = _derive(_status(eligibility: McpEligibilityState.pending))
          .item(ConnectStep.access);
      expect(
        (member.state, member.actor, member.action),
        (
          ConnectState.waiting,
          ConnectActor.databaseAdministrator,
          ConnectAction.none,
        ),
      );
      // Production, 2026-10-03: the only person is the operator, their own
      // request pending, the runtime off. Both rows lead to the console.
      final single = _derive(
        _status(eligibility: McpEligibilityState.pending),
        caps: _caps(eligibility: McpEligibility.requested, runtime: false),
        operator: true,
      );
      expect(
        single.item(ConnectStep.access).action,
        ConnectAction.openInstallation,
      );
      final server = single.item(ConnectStep.server);
      expect(
        (server.state, server.actor, server.action),
        (ConnectState.todo, ConnectActor.you, ConnectAction.openInstallation),
      );
    });

    test('runtime off: a member is told who, and can copy a request', () {
      final row = _derive(
        _status(),
        caps: _caps(runtime: false),
      ).item(ConnectStep.server);
      expect(
        (row.state, row.actor, row.action),
        (
          ConnectState.waiting,
          ConnectActor.operator,
          ConnectAction.askOperator,
        ),
      );
    });

    test('no answer about the server is unknown, never done', () {
      final list = ConnectChecklist.derive(
        status: _status(),
        capabilities: null,
        now: _now,
      );
      expect(list.item(ConnectStep.server).state, ConnectState.unavailable);
      expect(list.item(ConnectStep.connect).state, ConnectState.blocked);
    });

    test('nothing offered: the integrations manager acts, others wait', () {
      final mine = _derive(
        _status(exposure: McpExposureState.disabled),
        manages: true,
      ).item(ConnectStep.workspace);
      expect(
        (mine.state, mine.actor, mine.action),
        (ConnectState.todo, ConnectActor.you, ConnectAction.openSetup),
      );
      final theirs = _derive(_status(exposure: McpExposureState.disabled))
          .item(ConnectStep.workspace);
      expect(
        (theirs.state, theirs.actor, theirs.action),
        (ConnectState.waiting, ConnectActor.workspaceAdmin, ConnectAction.none),
      );
      final denied = _derive(_status(role: McpRoleState.denied))
          .item(ConnectStep.workspace);
      expect(denied.roleDenied, isTrue);
      expect(denied.state, ConnectState.waiting);
    });

    test('a member learns the offer only once approved', () {
      final row = _derive(
        _status(
          eligibility: McpEligibilityState.notRequested,
          exposure: McpExposureState.unavailable,
          role: McpRoleState.unavailable,
        ),
      ).item(ConnectStep.workspace);
      expect(row.state, ConnectState.blocked);
    });

    test('the approval says how long it lasts, and warns near its end', () {
      final far = _derive(_status());
      expect(far.item(ConnectStep.access).expiresInDays, 80);
      expect(far.accessExpiresSoon, isFalse);
      final near = _derive(
        _status(),
        caps: _caps(until: _now.add(const Duration(days: 9, hours: 3))),
      );
      expect(near.item(ConnectStep.access).expiresInDays, 9);
      expect(near.accessExpiresSoon, isTrue);
      // A pending request has no end date to announce.
      expect(
        _derive(_status(eligibility: McpEligibilityState.pending))
            .item(ConnectStep.access)
            .expiresInDays,
        isNull,
      );
    });
  });

  group('every workspace of the installation decides for itself', () {
    test('a workspace with assistants off waits on its own admin, and '
        'its integrations manager is sent to the setup page', () {
      final member = ConnectChecklist.derive(
        status: _status(),
        capabilities: _caps(),
        now: _now,
        workspaceOn: false,
      ).item(ConnectStep.workspace);
      expect(
        (member.state, member.actor, member.action),
        (ConnectState.waiting, ConnectActor.workspaceAdmin, ConnectAction.none),
      );
      final admin = ConnectChecklist.derive(
        status: _status(),
        capabilities: _caps(),
        now: _now,
        workspaceOn: false,
        canManageIntegrations: true,
      ).item(ConnectStep.workspace);
      expect(
        (admin.state, admin.action),
        (ConnectState.todo, ConnectAction.openSetup),
      );
      // Nothing in the checklist asks the operator for a workspace: the
      // installation is switched on once, for every workspace.
      expect(
        ConnectChecklist.derive(
          status: _status(),
          capabilities: _caps(),
          now: _now,
          workspaceOn: false,
        ).items.where((i) => i.actor == ConnectActor.operator),
        everyElement(
          isA<ConnectItem>().having((i) => i.step, 'step', ConnectStep.server),
        ),
      );
    });

    test('approved, but the workspace is not in the consent offer: nothing '
        'for this role, never "unknown"', () {
      final row = _derive(
        _status(
          exposure: McpExposureState.unavailable,
          role: McpRoleState.denied,
        ),
      ).item(ConnectStep.workspace);
      expect((row.state, row.roleDenied), (ConnectState.waiting, true));
    });

    test('one row per workspace, each in its own state and with its own '
        'action', () {
      final rows = deriveWorkspaceRows(
        workspaces: const [
          (id: 'a', name: 'Atelier', mcpOn: true),
          (id: 'b', name: 'Bureau', mcpOn: false),
          (id: 'c', name: 'Cave', mcpOn: true),
          (id: 'd', name: 'Dock', mcpOn: true),
        ],
        offered: const {'a': 3, 'c': 0},
        connected: const {'d'},
        currentId: 'a',
        canManageCurrent: true,
      );
      expect(
        [for (final r in rows) (r.id, r.state, r.action, r.current)],
        [
          ('a', WorkspaceAssistantState.ready, WorkspaceRowAction.none, true),
          (
            'b',
            WorkspaceAssistantState.off,
            WorkspaceRowAction.switchTo,
            false,
          ),
          (
            'c',
            WorkspaceAssistantState.notOffered,
            WorkspaceRowAction.switchTo,
            false,
          ),
          (
            'd',
            WorkspaceAssistantState.connected,
            WorkspaceRowAction.none,
            false,
          ),
        ],
      );
      // The selected workspace, off: its manager opens setup, a member
      // has nothing to press.
      final off = [(id: 'b', name: 'Bureau', mcpOn: false)];
      expect(
        deriveWorkspaceRows(
          workspaces: off,
          offered: null,
          connected: null,
          currentId: 'b',
          canManageCurrent: true,
        ).single.action,
        WorkspaceRowAction.openSetup,
      );
      expect(
        deriveWorkspaceRows(
          workspaces: off,
          offered: null,
          connected: null,
          currentId: 'b',
        ).single.action,
        WorkspaceRowAction.none,
      );
      // Not approved yet: what is offered is not known, never "ready".
      expect(
        deriveWorkspaceRows(
          workspaces: const [(id: 'a', name: 'Atelier', mcpOn: true)],
          offered: null,
          connected: const {},
        ).single.state,
        WorkspaceAssistantState.unknown,
      );
    });
  });

  group('what each assistant is given', () {
    final url = Uri.parse('https://abc.supabase.co/functions/v1/deskilo-mcp');

    test('Claude Code: one command over Streamable HTTP', () {
      expect(
        claudeCodeAddCommand(url),
        'claude mcp add --transport http deskilo '
        'https://abc.supabase.co/functions/v1/deskilo-mcp',
      );
    });

    test('Cursor: base64 JSON in config, percent-encoded', () {
      final link = cursorInstallUri(url);
      expect(link.scheme, 'cursor');
      expect(
        link.toString(),
        startsWith(
          'cursor://anysphere.cursor-deeplink/mcp/install?name=DesKilo&config=',
        ),
      );
      final config = link.queryParameters['config']!;
      expect(jsonDecode(utf8.decode(base64.decode(config))), {'url': '$url'});
      // The raw query never carries a bare '+', '/' or '=' of the base64.
      final raw = link.query.split('config=').last;
      expect(raw, isNot(matches(RegExp(r'[+/=]'))));
    });

    test('VS Code: the server entry as URL-encoded JSON', () {
      final link = vscodeInstallUri(url);
      expect(link.toString(), startsWith('vscode:mcp/install?'));
      final json = Uri.decodeComponent(
        link.toString().substring('vscode:mcp/install?'.length),
      );
      expect(jsonDecode(json), {
        'name': 'deskilo',
        'type': 'http',
        'url': '$url',
      });
      expect(link.toString(), isNot(contains('"')));
    });

    test('Other clients: an mcpServers entry and the mcp-remote bridge', () {
      expect(jsonDecode(genericMcpConfig(url)), {
        'mcpServers': {
          'deskilo': {'type': 'http', 'url': '$url'},
        },
      });
      expect(mcpRemoteCommand(url), 'npx -y mcp-remote $url');
    });
  });
}
