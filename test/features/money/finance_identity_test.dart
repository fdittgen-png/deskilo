// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4218 — one identity per host. Every finance row carries
// `installationId:workspaceId` (the server answers those rows without the
// stored network id), so a link, a focus request and a payment's request id
// that must match a row use that form on both sides. A stored id that differs
// (a restore into another installation) then cannot make them disagree.
import 'package:deskilo/core/backend/operation_context.dart'
    show WorkspaceTarget;
import 'package:deskilo/features/money/presentation/widgets/my_finances_link_card.dart';
import 'package:deskilo/features/money/providers/finance_overview_provider.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// The workspace row's stored id, not the form the finance rows carry.
const _diverged = WorkspaceTarget(
  networkId: 'stored-before-the-restore',
  installationId: 'inst-a',
  workspaceId: 'ws-1',
);

void main() {
  test('the identity finance keys on is the installation and the workspace, '
      'whatever the stored id says', () {
    expect(_diverged.financeKey, 'inst-a:ws-1');
    expect(
      WorkspaceTarget.local(
        installationId: 'inst-a',
        workspaceId: 'ws-1',
      ).financeKey,
      _diverged.financeKey,
      reason: 'a row the finance reads and the workspace on screen agree',
    );
    expect(_diverged.financeKey, isNot(_diverged.networkId));
  });

  test('two hosts holding the same local workspace id have two identities', () {
    expect(
      WorkspaceTarget.local(
        installationId: 'inst-a',
        workspaceId: 'ws-1',
      ).financeKey,
      isNot(
        WorkspaceTarget.local(
          installationId: 'inst-b',
          workspaceId: 'ws-1',
        ).financeKey,
      ),
    );
  });

  testWidgets('the Money screen\'s link to My finances names the business by '
      'the form its rows carry, not by a stored id that differs', (
    tester,
  ) async {
    String? pushed;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const Scaffold(
            body: MyFinancesLinkCard(
              workspaceId: 'ws-1',
              workspaceName: 'Atelier',
            ),
          ),
        ),
        GoRoute(
          path: '/account-activity',
          builder: (context, state) {
            pushed = state.uri.toString();
            return const SizedBox();
          },
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [financeCurrentTargetProvider.overrideWithValue(_diverged)],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.byKey(const ValueKey('money-my-finances-open')));
    await tester.pumpAndSettle();
    expect(
      Uri.parse(pushed!).queryParameters['workspace'],
      'inst-a:ws-1',
      reason: 'the list is narrowed by the key its rows carry',
    );
  });
}
