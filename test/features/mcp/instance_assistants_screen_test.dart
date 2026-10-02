// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1827 B — the instance operator's console for the installation's
// assistants. Everyone else is told the page is not theirs; without a
// second factor nothing can be changed and the page says how to get one;
// with it, the operator makes an administrator, approves an assistant's
// client and turns the runtime on (after confirming what it means).
import 'package:deskilo/core/demo/data/mcp_admin_repository.dart';
import 'package:deskilo/features/mcp/domain/instance_operator.dart';
import 'package:deskilo/features/mcp/presentation/instance_assistants_screen.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

InstanceMcpOverview _overview({
  bool secondFactor = true,
  bool enabled = false,
  List<String> blockers = const [],
}) => InstanceMcpOverview(
  enabled: enabled,
  blockers: blockers,
  secondFactor: secondFactor,
  administrators: const [],
  candidates: const [
    InstanceMember(userId: 'u-flo', name: 'Florian', me: true),
    InstanceMember(userId: 'u-ana', name: 'Ana'),
  ],
  clients: const [
    InstanceClient(clientId: 'c-claude', name: 'Claude', status: 'active'),
    InstanceClient(clientId: 'c-code', name: 'Claude Code', status: 'waiting'),
  ],
);

Finder _key(String k) => find.byKey(ValueKey(k));

Future<FakeMcpAdminRepository> _pump(
  WidgetTester tester,
  InstanceMcpOverview? overview,
) async {
  tester.view.physicalSize = const Size(800, 2400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final admin = FakeMcpAdminRepository()..instance = overview;
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(mcpAdmin: admin),
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InstanceAssistantsScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return admin;
}

void main() {
  testWidgets('not the instance operator: told so, nothing to switch', (
    tester,
  ) async {
    await _pump(tester, null);
    expect(_key('instance-not-operator'), findsOneWidget);
    expect(_key('instance-turn-on'), findsNothing);
  });

  testWidgets('without the second factor nothing changes, and the page says '
      'how to confirm it', (tester) async {
    final admin = await _pump(tester, _overview(secondFactor: false));
    expect(_key('instance-second-factor-needed'), findsOneWidget);
    expect(_key('instance-second-factor'), findsOneWidget);
    final make = tester.widget<OutlinedButton>(
      _key('instance-make-admin-u-ana'),
    );
    expect(make.onPressed, isNull);
    expect(admin.instanceCalls, isEmpty);
  });

  testWidgets('with it: make an administrator, approve a waiting client', (
    tester,
  ) async {
    final admin = await _pump(tester, _overview());
    expect(find.text('Florian (you)'), findsOneWidget);
    await tester.tap(_key('instance-make-admin-u-flo'));
    await tester.pumpAndSettle();
    await tester.tap(_key('instance-approve-c-code'));
    await tester.pumpAndSettle();
    expect(admin.instanceCalls, ['grant:u-flo', 'client:c-code:true']);
    expect(_key('instance-client-c-claude-active'), findsOneWidget);
  });

  testWidgets('blocked runtime names what is missing and cannot be turned on', (
    tester,
  ) async {
    await _pump(tester, _overview(blockers: ['no_database_administrator']));
    expect(find.textContaining('a database administrator'), findsOneWidget);
    expect(
      tester.widget<FilledButton>(_key('instance-turn-on')).onPressed,
      isNull,
    );
  });

  testWidgets('a ready runtime is turned on only after confirming it means '
      'every workspace', (tester) async {
    final admin = await _pump(tester, _overview());
    await tester.tap(_key('instance-turn-on'));
    await tester.pumpAndSettle();
    expect(admin.instanceCalls, isEmpty, reason: 'nothing before confirming');
    await tester.tap(_key('instance-turn-on-confirm'));
    await tester.pumpAndSettle();
    expect(admin.instanceCalls, ['runtime:true']);
  });
}
