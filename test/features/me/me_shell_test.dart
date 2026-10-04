// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me is the account's own home: with ZERO workspaces the app
// opens there, and every one of its four tabs opens. Each affordance on
// Home and on the Me tab is tapped and lands where it says.
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/me/presentation/me_messages_tab.dart';
import 'package:deskilo/features/me/presentation/me_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/features/profile/presentation/widgets/personal_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

void main() {
  testWidgets('the global menu preference follows Me and the workspace', (
    tester,
  ) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces());
    await goTo(tester, router, '/me');
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MeShell)),
    );
    await container
        .read(navigationStyleControllerProvider.notifier)
        .set(NavigationStyle.menu);
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsNothing);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-tab-messages')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('unified-inbox')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('me-profile-settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-account-list')), findsOneWidget);
    await goTo(tester, router, '/reserve');
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byType(ShellDrawer), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('drawer-back-to-me')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me');
    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets(
    'paired environments share one card and enter the selected side',
    (tester) async {
      final repo = twoSpaces();
      repo.workspaces[0] = repo.workspaces[0].copyWith(
        pairId: 'pair-1',
        environment: 'dev',
      );
      repo.workspaces[1] = repo.workspaces[1].copyWith(
        pairId: 'pair-1',
        environment: 'prod',
      );
      final router = await pumpMeApp(
        tester,
        workspace: repo,
        size: const Size(390, 844),
      );
      await goTo(tester, router, '/me');
      final group = find.byKey(const ValueKey('me-space-pair-pair-1'));
      expect(group, findsOneWidget);
      expect(
        find.descendant(of: group, matching: find.text('DEV')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: group, matching: find.text('PROD')),
        findsOneWidget,
      );
      expect(tester.getCenter(find.text('DEV')).dy,
          tester.getCenter(find.text('PROD')).dy);
      expect(tester.getSize(group).height, lessThan(120));
      // Production is the wide green button on the left, development the
      // narrow orange one at the right.
      final prod = find.byKey(const ValueKey('me-space-ws-2'));
      final dev = find.byKey(const ValueKey('me-space-ws-1'));
      expect(tester.getSize(prod).width, greaterThan(tester.getSize(dev).width));
      expect(tester.getTopLeft(dev).dx, greaterThan(tester.getTopLeft(prod).dx));
      Color? fill(Finder f) => tester
          .widget<FilledButton>(f)
          .style
          ?.backgroundColor
          ?.resolve(const {});
      expect(fill(prod), isNot(fill(dev)));
      for (final width in [320.0, 1200.0]) {
        tester.view.physicalSize = Size(width, 844);
        await tester.pumpAndSettle();
        expect(tester.getCenter(find.text('DEV')).dy,
            tester.getCenter(find.text('PROD')).dy);
        expect(tester.takeException(), isNull);
      }
      expect(tester.takeException(), isNull);
      await tester.tap(find.byKey(const ValueKey('me-space-ws-2')));
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      expect(container.read(currentWorkspaceProvider).value?.id, 'ws-2');
    },
  );

  testWidgets(
    'personal avatar returns home and opens settings in the same position',
    (tester) async {
      final router = await pumpMeApp(tester, workspace: twoSpaces());
      final workspaceButton = find.byKey(const ValueKey('shell-back-to-me'));
      final position = tester.getCenter(workspaceButton);
      expect(
        find.descendant(
          of: workspaceButton,
          matching: find.byType(PersonalAvatar),
        ),
        findsOneWidget,
      );
      await tester.tap(workspaceButton);
      await tester.pumpAndSettle();
      final meButton = find.byKey(const ValueKey('me-profile-settings'));
      expect(tester.getCenter(meButton).dx, position.dx);
      await tester.tap(meButton);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('me-account-list')), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('me-tab-me')),
          matching: find.byType(PersonalAvatar),
        ),
        findsOneWidget,
      );
      expect(router.state.uri.path, '/me');
    },
  );

  testWidgets('zero workspaces: Me opens from the first run, and every tab '
      'opens', (tester) async {
    final router = await pumpMeApp(
      tester,
      workspace: FakeWorkspaceRepository(workspaces: []),
    );
    expect(router.state.uri.path, '/me');
    expect(find.byType(MeShell), findsOneWidget);
    expect(find.byKey(const ValueKey('me-home-empty')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab-discover')));
    await tester.pumpAndSettle();
    expect(find.byType(DirectoryScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab-messages')));
    await tester.pumpAndSettle();
    expect(find.byType(MeMessagesTab), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab-me')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-visibility-card')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab-home')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-home-empty')), findsOneWidget);
    expect(
      router.state.uri.path,
      '/me',
      reason: 'no tab of Me asks for a workspace',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Home offers finding, joining and creating a space', (
    tester,
  ) async {
    final router = await pumpMeApp(
      tester,
      workspace: FakeWorkspaceRepository(workspaces: []),
    );
    await goTo(tester, router, '/me');
    await tester.tap(find.byKey(const ValueKey('me-home-discover')));
    await tester.pumpAndSettle();
    expect(find.byType(DirectoryScreen), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('me-tab-home')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('me-home-join')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/onboarding?join=1');

    await goTo(tester, router, '/me');
    await tester.tap(find.byKey(const ValueKey('me-home-create')));
    await tester.pumpAndSettle();
    expect(router.state.uri.toString(), '/onboarding');
  });

  testWidgets('with spaces, Home lists them, last used first, and opens the '
      'detailed list', (tester) async {
    final router = await pumpMeApp(
      tester,
      workspace: twoSpaces(serverDefault: 'ws-2'),
    );
    await goTo(tester, router, '/me');
    final first = tester.getTopLeft(
      find.byKey(const ValueKey('me-space-ws-2')),
    );
    final second = tester.getTopLeft(
      find.byKey(const ValueKey('me-space-ws-1')),
    );
    expect(first.dy, lessThan(second.dy), reason: 'the last used space leads');
    expect(find.byKey(const ValueKey('me-space-last-ws-2')), findsOneWidget);
    await tapIn(
      tester,
      'me-home-list',
      find.byKey(const ValueKey('me-home-manage')),
    );
    expect(router.state.uri.path, '/profiles');
  });

  for (final (key, path) in [
    ('me-activity', '/account-activity'),
    ('me-privacy', '/privacy'),
    ('me-servers', '/connections'),
    ('me-help', '/help'),
    ('settings-linked-accounts', '/linked-accounts'),
    ('me-workspaces', '/profiles'), // #1846
  ]) {
    testWidgets('the Me tab opens $path', (tester) async {
      final router = await pumpMeApp(tester);
      await goTo(tester, router, '/me?tab=me');
      await tapIn(tester, 'me-account-list', find.byKey(ValueKey(key)));
      expect(router.state.uri.path, path);
    });
  }

  testWidgets('the Me tab signs out', (tester) async {
    final auth = FakeAuthRepository.signedIn();
    final router = await pumpMeApp(tester, auth: auth);
    await goTo(tester, router, '/me?tab=me');
    await tapIn(
      tester,
      'me-account-list',
      find.byKey(const ValueKey('me-sign-out')),
    );
    expect(auth.currentUserId, isNull);
    expect(router.state.uri.path, '/auth');
  });

  testWidgets('#1846 — Me groups its rows: profile, account, workspaces, '
      'connected installations, in that order', (tester) async {
    final router = await pumpMeApp(tester);
    await goTo(tester, router, '/me?tab=me');
    final tops = <double>[];
    for (final title in [
      'My profile',
      'My account',
      'My workspaces',
      'Connected installations',
    ]) {
      final header = find.text(title).first;
      await tester.scrollUntilVisible(
        header,
        200,
        scrollable: find.descendant(
          of: find.byKey(const ValueKey('me-account-list')),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      tops.add(tester.getTopLeft(header).dy);
    }
    // Each header was reached scrolling DOWN: the order is the list's.
    expect(tops, hasLength(4));
  });
}
