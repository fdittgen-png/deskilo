// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3906 — an accounting target's sign-in comes back to the app's page and
// is completed there, once, by the signed-in person: the address loses the
// code and the state at once, a person who is not signed in signs in first
// and comes back with them intact, and each outcome is said.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/accounting_connection_repository.dart';
import 'package:deskilo/core/demo/data/book_period_repository.dart';
import 'package:deskilo/features/money/domain/accounting_connection.dart';
import 'package:deskilo/features/money/providers/accounting_connection_providers.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

final _today = DateTime(2026, 11, 13);

const _back =
    '/accounting/connected?code=C0DE&state=33333333-3333-4333-8333-333333333333.s3cr3t&tenant=42';

FakeAccountingConnectionRepository _repo() =>
    FakeAccountingConnectionRepository(
      books: FakeBookPeriodRepository(today: _today),
      today: _today,
    );

Future<GoRouter> _pump(
  WidgetTester tester,
  FakeAccountingConnectionRepository repo, {
  FakeAuthRepository? auth,
  bool connectors = true,
}) async {
  tester.view.physicalSize = const Size(800, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...standardTestOverrides(
          auth: auth,
          workspace: FakeWorkspaceRepository.withWorkspace(
            featureFlags: {
              for (final f in WorkspaceFeature.values) f.dbKey: true,
              WorkspaceFeature.accountingConnectors.dbKey: connectors,
            },
          ),
        ),
        accountingConnectionRepositoryProvider.overrideWithValue(repo),
      ],
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return GoRouter.of(tester.element(find.byType(Scaffold).first));
}

void main() {
  test('only the return address with a state is a sign-in return; it never '
      'prints what it carries', () {
    final back = SignInReturn.fromUri(Uri.parse(_back))!;
    expect(back.code, 'C0DE');
    expect(back.tenant, '42');
    expect('$back', isNot(contains('C0DE')));
    expect('$back', isNot(contains('s3cr3t')));
    expect(SignInReturn.fromUri(Uri.parse('/accounting/connected')), isNull);
    expect(SignInReturn.fromUri(Uri.parse('/money?state=x')), isNull);
  });

  for (final (outcome, key) in [
    (SignInCompletion.connected, 'accounting-sign-in-connected'),
    (SignInCompletion.refused, 'accounting-sign-in-refused'),
    (SignInCompletion.expired, 'accounting-sign-in-expired'),
    (SignInCompletion.failed, 'accounting-sign-in-failed'),
  ]) {
    testWidgets(
      'the page completes the sign-in once and says: ${outcome.name}',
      (tester) async {
        final repo = _repo()..completion = outcome;
        final router = await _pump(tester, repo);
        router.go(_back);
        await tester.pumpAndSettle();
        expect(
          router.state.uri.toString(),
          '/accounting/connected',
          reason: 'the code and the state leave the address at once',
        );
        expect(repo.completed, hasLength(1));
        expect(repo.completed.single.code, 'C0DE');
        expect(repo.completed.single.tenant, '42');
        expect(find.byKey(ValueKey(key)), findsOneWidget);
      },
    );
  }

  testWidgets('opened again, the page completes nothing and says the link '
      'is spent', (tester) async {
    final repo = _repo();
    final router = await _pump(tester, repo);
    router.go('/accounting/connected');
    await tester.pumpAndSettle();
    expect(repo.completed, isEmpty);
    expect(
      find.byKey(const ValueKey('accounting-sign-in-expired')),
      findsOneWidget,
    );
  });

  testWidgets('a person who is not signed in signs in first and comes back '
      'with the code and the state intact', (tester) async {
    final repo = _repo();
    final router = await _pump(tester, repo, auth: FakeAuthRepository());
    router.go(_back);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/auth');
    expect(router.state.uri.toString(), isNot(contains('C0DE')));
    expect(repo.completed, isEmpty);

    await tester.enterText(find.byType(TextFormField).at(0), 'flo@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'secret12345');
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/accounting/connected');
    expect(repo.completed.single.code, 'C0DE');
    expect(
      find.byKey(const ValueKey('accounting-sign-in-connected')),
      findsOneWidget,
    );
  });

  testWidgets('with the connectors off the page does not open, and nothing '
      'is completed', (tester) async {
    final repo = _repo();
    final router = await _pump(tester, repo, connectors: false);
    router.go(_back);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, isNot('/accounting/connected'));
    expect(repo.completed, isEmpty);
  });
}
