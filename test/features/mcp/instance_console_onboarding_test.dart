// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2145 — what the operator configures in the app beyond #1827 B: each
// assistant client names its family and where its answers go (0359), and
// one switch allows desktop and command-line assistants. Without the
// second factor the switch cannot move.
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/core/demo/data/mcp_onboarding_repository.dart';
import 'package:deskilo/features/mcp/domain/instance_operator.dart';
import 'package:deskilo/features/mcp/presentation/instance_assistants_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

InstanceMcpOverview _overview({
  bool secondFactor = true,
  bool loopback = false,
}) => InstanceMcpOverview(
  enabled: true,
  blockers: const [],
  secondFactor: secondFactor,
  administrators: const [],
  candidates: const [],
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
);

Finder _key(String k) => find.byKey(ValueKey(k));

Future<FakeMcpOnboardingRepository> _pump(
  WidgetTester tester,
  InstanceMcpOverview overview,
) async {
  tester.view.physicalSize = const Size(800, 2800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final onboarding = FakeMcpOnboardingRepository();
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
}
