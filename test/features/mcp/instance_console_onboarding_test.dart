// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — what the operator configures in the app beyond #1827 B: each
// assistant client names its family and where its answers go (0356), and
// one switch allows desktop and command-line assistants. Without the
// second factor the switch cannot move.
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_onboarding_repository.dart';
import 'package:deskilo/features/mcp/domain/instance_operator.dart';
import 'package:deskilo/features/mcp/domain/mcp_onboarding.dart';
import 'package:deskilo/features/mcp/presentation/instance_assistants_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/mock_providers.dart';

InstanceMcpOverview _overview({
  bool secondFactor = true,
  bool loopback = false,
  bool enabled = true,
  EndpointProbe probe = EndpointProbe.missing,
  bool grantAvailable = false,
  bool google = true,
  List<InstanceEligibleUser> eligible = const [],
}) => InstanceMcpOverview(
  enabled: enabled,
  blockers: const [],
  secondFactor: secondFactor,
  administrators: const [],
  candidates: const [InstanceMember(userId: 'u-flo', name: 'Flo', me: true)],
  clients: const [
    InstanceClient(
      clientId: 'c-claude',
      name: 'Claude',
      status: 'active',
      family: 'claude',
      redirectHosts: ['claude.ai'],
    ),
    InstanceClient(
      clientId: 'c-code',
      name: 'Claude Code',
      status: 'waiting',
      family: 'loopback',
      redirectHosts: ['localhost', '127.0.0.1'],
    ),
  ],
  allowLoopbackClients: loopback,
  endpoint: const McpEndpointInfo(
    resource: 'https://abc.supabase.co/functions/v1/deskilo-mcp',
    source: McpEndpointSource.derived,
  ),
  endpointProbe: probe,
  operatorGrantAvailable: grantAvailable,
  googleSession: google,
  eligibleUsers: eligible,
);

Finder _key(String k) => find.byKey(ValueKey(k));

Future<FakeMcpOnboardingRepository> _pump(
  WidgetTester tester,
  InstanceMcpOverview overview, {
  FakeMcpOnboardingRepository? onboarding,
}) async {
  tester.view.physicalSize = const Size(800, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  onboarding ??= FakeMcpOnboardingRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(
        mcpAdmin: FakeMcpAdminRepository()..instance = overview,
        mcpOnboarding: onboarding,
      ),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InstanceAssistantsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return onboarding;
}

void main() {
  testWidgets('each client names its family and where its answers go', (
    tester,
  ) async {
    await _pump(tester, _overview());
    expect(find.text('Approved · Claude · claude.ai'), findsOneWidget);
    expect(
      find.text(
        'Waiting for approval · Desktop or command-line assistant · '
        'localhost, 127.0.0.1',
      ),
      findsOneWidget,
    );
  });

  testWidgets('the operator allows desktop and command-line assistants', (
    tester,
  ) async {
    final onboarding = await _pump(tester, _overview());
    await tester.ensureVisible(_key('instance-loopback-off'));
    await tester.tap(_key('instance-loopback-off'));
    await tester.pumpAndSettle();
    expect(onboarding.calls, contains('setLoopbackClients:true'));
  });

  testWidgets('without the second factor the switch does not move', (
    tester,
  ) async {
    final onboarding = await _pump(tester, _overview(secondFactor: false));
    final tile = tester.widget<SwitchListTile>(_key('instance-loopback-off'));
    expect(tile.onChanged, isNull);
    expect(onboarding.calls, isEmpty);
  });

  testWidgets('a waiting assistant reaches the operator as a notice, which '
      'can be marked read', (tester) async {
    final onboarding = FakeMcpOnboardingRepository(
      inbox: const InstanceNotices(
        unread: 1,
        notices: [
          InstanceNotice(
            id: 'n1',
            kind: 'mcp_client_waiting',
            subject: 'Claude Code',
          ),
        ],
      ),
    );
    await _pump(tester, _overview(), onboarding: onboarding);
    expect(
      find.text('Claude Code is waiting for your approval.'),
      findsOneWidget,
    );
    await tester.tap(_key('instance-notices-read'));
    await tester.pumpAndSettle();
    expect(onboarding.calls, contains('markNoticeRead:all'));
  });

  testWidgets('Turn on waits for a fresh check of the deployed endpoint; '
      'the check asks, then reads the settled probe', (tester) async {
    final onboarding = await _pump(tester, _overview(enabled: false));
    expect(_key('instance-turn-on-needs-probe'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('instance-turn-on')).onPressed,
      isNull,
    );
    await tester.ensureVisible(_key('instance-probe'));
    await tester.tap(_key('instance-probe'));
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(
      onboarding.calls,
      containsAllInOrder(['probeEndpoint', 'checkEndpoint']),
    );
  });

  testWidgets('a fresh, deployed probe lets the operator turn assistants on', (
    tester,
  ) async {
    await _pump(
      tester,
      _overview(
        enabled: false,
        probe: const EndpointProbe(
          state: EndpointProbeState.deployed,
          fresh: true,
        ),
      ),
    );
    expect(_key('instance-turn-on-needs-probe'), findsNothing);
    expect(
      tester.widget<FilledButton>(_key('instance-turn-on')).onPressed,
      isNotNull,
    );
  });

  testWidgets('with nobody else to decide, the operator approves their own '
      'access with a reason and a length', (tester) async {
    final onboarding = await _pump(tester, _overview(grantAvailable: true));
    await tester.ensureVisible(_key('instance-grant-u-flo'));
    await tester.tap(_key('instance-grant-u-flo'));
    await tester.pumpAndSettle();
    final confirm = _key('instance-grant-confirm');
    expect(tester.widget<FilledButton>(confirm).onPressed, isNull);
    await tester.enterText(_key('instance-grant-reason'), 'pilot');
    await tester.pumpAndSettle();
    await tester.tap(confirm);
    await tester.pumpAndSettle();
    expect(onboarding.calls, contains('grantEligibility:u-flo:30:pilot'));
  });

  testWidgets('a refused grant says why in plain words', (tester) async {
    final onboarding = FakeMcpOnboardingRepository()
      ..grantError = const PostgrestException(
        message:
            'another database administrator decides assistant access '
            'here',
      );
    await _pump(
      tester,
      _overview(grantAvailable: true),
      onboarding: onboarding,
    );
    await tester.ensureVisible(_key('instance-grant-u-flo'));
    await tester.tap(_key('instance-grant-u-flo'));
    await tester.pumpAndSettle();
    await tester.enterText(_key('instance-grant-reason'), 'pilot');
    await tester.pumpAndSettle();
    await tester.tap(_key('instance-grant-confirm'));
    await tester.pumpAndSettle();
    expect(
      find.text('A database administrator decides access here; ask them.'),
      findsOneWidget,
    );
  });

  testWidgets('without a Google session the grant cannot be made; a '
      'self-grant is shown as such', (tester) async {
    await _pump(
      tester,
      _overview(
        grantAvailable: true,
        google: false,
        eligible: [
          InstanceEligibleUser(
            userId: 'u-ana',
            name: 'Ana',
            expiresAt: DateTime.utc(2026, 11, 2),
            grantedByOperator: true,
            selfGrant: true,
          ),
        ],
      ),
    );
    expect(_key('instance-grant-google'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(_key('instance-grant-u-flo')).onPressed,
      isNull,
    );
    expect(find.textContaining('Self-approved by operator'), findsOneWidget);
  });
}
