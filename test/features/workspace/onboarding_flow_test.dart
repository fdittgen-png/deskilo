// SPDX-License-Identifier: 0BSD
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/shell/shell_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';

Future<FakeWorkspaceRepository> pumpWithoutWorkspace(
  WidgetTester tester,
) async {
  final repo = FakeWorkspaceRepository();
  await tester.pumpWidget(
    ProviderScope(
      overrides: standardTestOverrides(workspace: repo),
      child: const DeskiloApp(),
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  testWidgets('signed-in user without workspace lands on onboarding',
      (tester) async {
    await pumpWithoutWorkspace(tester);

    expect(find.text('Welcome to DesKilo'), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
  });

  testWidgets('creating a workspace leads into the shell', (tester) async {
    final repo = await pumpWithoutWorkspace(tester);

    await tester.enterText(
      find.byType(TextFormField).first,
      'Kraftwerk Coworking',
    );
    await tester.tap(find.text('Create workspace'));
    await tester.pumpAndSettle();

    expect(repo.workspaces, hasLength(1));
    expect(repo.workspaces.single.name, 'Kraftwerk Coworking');
    expect(repo.workspaces.single.countryCode, 'DE');
    expect(repo.workspaces.single.currencyCode, 'EUR');
    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets('joining with a valid invite code leads into the shell',
      (tester) async {
    await pumpWithoutWorkspace(tester);

    await tester.tap(find.text('Join a workspace'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'GOODCODE22');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets(
      'pasting the WHOLE invitation message joins too — the ID is '
      'extracted automatically (0049 smart paste)', (tester) async {
    await pumpWithoutWorkspace(tester);

    await tester.tap(find.text('Join a workspace'));
    await tester.pumpAndSettle();
    const message = 'Hi! You are invited to join "Pezenas" on DesKilo.\n'
        '3. Choose "Join a workspace" and enter the workspace ID:\n'
        'GOODCODE22\n'
        '(or scan the invite QR — deskilo://join?role=user&code=GOODCODE22)\n'
        'See you soon!';
    await tester.enterText(find.byType(TextFormField).first, message);
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets('joining with an invalid code shows the error and stays',
      (tester) async {
    await pumpWithoutWorkspace(tester);

    await tester.tap(find.text('Join a workspace'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'BADCODE99');
    await tester.tap(find.text('Join'));
    await tester.pumpAndSettle();

    expect(
      find.text('Something went wrong. Please try again.'),
      findsOneWidget,
    );
    expect(find.byType(ShellBottomBar), findsNothing);
  });

  testWidgets('member with a workspace never sees onboarding',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ShellBottomBar), findsOneWidget);
    expect(find.text('Welcome to DesKilo'), findsNothing);
  });

  // ── QR join (#572) ─────────────────────────────────────────────────

  testWidgets(
      'the scan screen SURVIVES the no-workspace redirect: scanning an '
      'invite URL joins and lands in the shell', (tester) async {
    // The regression: /scan-join was evicted back to onboarding by the
    // "no workspace → onboarding" redirect — its only audience is
    // exactly the user with zero workspaces.
    final repo = FakeWorkspaceRepository();
    final scanner = FakeQrScanner();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(workspace: repo, qrScan: scanner),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join a workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan QR code'));
    await tester.pumpAndSettle();

    // The camera screen is REACHED, not bounced back to the join form.
    expect(find.byKey(const ValueKey('scan-join-camera')), findsOneWidget);

    scanner.emit('deskilo://join?role=user&code=GOODCODE22');
    await tester.pumpAndSettle();

    expect(find.byType(ShellBottomBar), findsOneWidget);
  });

  testWidgets('an unrelated QR is ignored and the scanner stays open',
      (tester) async {
    final scanner = FakeQrScanner();
    await tester.pumpWidget(
      ProviderScope(
        overrides: standardTestOverrides(
          workspace: FakeWorkspaceRepository(),
          qrScan: scanner,
        ),
        child: const DeskiloApp(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Join a workspace'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Scan QR code'));
    await tester.pumpAndSettle();

    scanner.emit('https://example.com/not-an-invite');
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('scan-join-camera')), findsOneWidget);
    expect(find.byType(ShellBottomBar), findsNothing);
  });
}
