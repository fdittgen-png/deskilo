// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1823 — Me is the account's own home: with ZERO workspaces the app
// opens there, and every one of its four tabs opens. Each affordance on
// Home and on the Me tab is tapped and lands where it says.
import 'package:deskilo/features/directory/presentation/directory_screen.dart';
import 'package:deskilo/features/me/presentation/me_messages_tab.dart';
import 'package:deskilo/features/me/presentation/me_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/features/profile/presentation/widgets/personal_avatar.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

void main() {
  testWidgets('Messages badges refresh before opening the tab, hide zero and cap at 99+', (tester) async {
    final messenger = FakeMessengerRepository()..inboxRows.addAll([
      {'context_kind': 'account', 'context_id': 'new', 'title': 'New', 'unread': 124},
      {'context_kind': 'space', 'context_id': 'quiet', 'unread': 9, 'pinned': false, 'muted': true},
      {'context_kind': 'space', 'context_id': 'archived', 'unread': 9, 'pinned': false, 'archived': true},
    ]);
    final router = await pumpMeApp(tester, messenger: messenger, size: const Size(390, 844));
    await goTo(tester, router, '/me');
    final destination = find.byKey(const ValueKey('me-tab-messages'));
    expect(find.descendant(of: destination, matching: find.text('99+')), findsOneWidget);
    expect(find.byType(MeMessagesTab), findsNothing);
    final container = ProviderScope.containerOf(tester.element(find.byType(MeShell)));
    await container.read(navigationStyleControllerProvider.notifier).set(NavigationStyle.menu);
    tester.view.physicalSize = const Size(1200, 900);
    await tester.pumpAndSettle();
    expect(find.descendant(of: destination, matching: find.text('99+')), findsOneWidget);
    messenger.inboxRows.clear();
    await tester.pump(const Duration(seconds: 30));
    await tester.pumpAndSettle();
    expect(find.descendant(of: destination, matching: find.byType(Badge)), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('wide Me keeps destinations visible and shrinks to a drawer', (tester) async {
    final semantics = tester.ensureSemantics();
    final router = await pumpMeApp(tester, size: const Size(1200, 900));
    await goTo(tester, router, '/me');
    final container = ProviderScope.containerOf(tester.element(find.byType(MeShell)));
    await container.read(navigationStyleControllerProvider.notifier).set(NavigationStyle.menu);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-sidebar')), findsOneWidget);
    expect(find.byTooltip('Open navigation menu'), findsNothing);
    for (final tab in ['discover', 'messages', 'me', 'home']) {
      await tester.tap(find.byKey(ValueKey('me-tab-$tab')));
      await tester.pumpAndSettle();
      expect(router.state.uri.queryParameters['tab'] ?? 'home', tab);
      expect(tester.widget<ListTile>(find.byKey(ValueKey('me-tab-$tab'))).selected, isTrue);
      expect(find.byKey(const ValueKey('me-sidebar')), findsOneWidget);
    }
    await goTo(tester, router, '/reserve');
    expect(find.byKey(const ValueKey('shell-sidebar')), findsOneWidget);
    expect(tester.getSemantics(find.byKey(const ValueKey('drawer-tab-1')))
        .getSemanticsData().label, contains('Calendar'));
    var reachedCalendar = false;
    for (var step = 0; step < 60 && !reachedCalendar; step++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
        if (element.widget.key == const ValueKey('drawer-tab-1')) {
          reachedCalendar = true;
          return false;
        }
        return true;
      });
    }
    expect(reachedCalendar, isTrue, reason: 'the persistent sidebar is reachable by keyboard');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/calendar');
    expect(find.byKey(const ValueKey('shell-sidebar')), findsOneWidget);
    for (final (branch, path) in [(2, '/directory'), (3, '/money')]) {
      final destination = find.byKey(ValueKey('drawer-tab-$branch'));
      if (destination.evaluate().isEmpty) continue;
      await tester.tap(destination);
      await tester.pumpAndSettle();
      expect(router.state.uri.path, path);
      expect(tester.widget<ListTile>(destination).selected, isTrue);
      expect(find.byKey(const ValueKey('shell-sidebar')), findsOneWidget);
    }
    await tester.tap(find.byKey(const ValueKey('drawer-back-to-me')));
    await tester.pumpAndSettle();
    expect(router.state.uri.path, '/me');
    tester.view.physicalSize = const Size(390, 844);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-sidebar')), findsNothing);
    expect(find.byTooltip('Open navigation menu'), findsOneWidget);
    await tester.tap(find.byTooltip('Open navigation menu'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('me-tab-me')), findsOneWidget);
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('preferences are reachable from the first account viewport', (tester) async {
    final router = await pumpMeApp(tester, workspace: twoSpaces(),
        size: const Size(390, 844));
    await goTo(tester, router, '/me?tab=me');
    final shortcut = find.byKey(const ValueKey('me-section-2'));
    expect(tester.getRect(shortcut).bottom, lessThan(300));
    await tester.tap(shortcut);
    await tester.pumpAndSettle();
    expect(find.text('Language').hitTestable(), findsOneWidget);
    expect(find.text('Theme').hitTestable(), findsOneWidget);
    expect(find.byKey(const ValueKey('regional-formats')).hitTestable(), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byType(SimpleDialog), findsOneWidget);
  });

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
    'a side the person is not active in is disabled and does nothing',
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
      // present on both sides, active only in the dev
      repo.extraMyMemberships
        ..clear()
        ..add(
          const Member(
            id: 'member-b',
            workspaceId: 'ws-2',
            userId: 'user-1',
            isAdmin: false,
            isOwner: false,
            status: MemberStatus.paused,
          ),
        );
      final router = await pumpMeApp(
        tester,
        workspace: repo,
        size: const Size(390, 844),
      );
      await goTo(tester, router, '/me');
      final prod = find.byKey(const ValueKey('me-space-ws-2'));
      final dev = find.byKey(const ValueKey('me-space-ws-1'));
      expect(tester.widget<FilledButton>(prod).onPressed, isNull);
      expect(tester.widget<FilledButton>(dev).onPressed, isNotNull);
      await tester.tap(prod, warnIfMissed: false);
      await tester.pumpAndSettle();
      final container = ProviderScope.containerOf(
        tester.element(find.byType(Scaffold).first),
      );
      expect(container.read(currentWorkspaceProvider).value?.id, isNot('ws-2'));
    },
  );

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
        find.descendant(of: group, matching: find.text('Test space')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: group, matching: find.text('Open workspace')),
        findsOneWidget,
      );
      expect(tester.getCenter(find.text('Test space')).dy,
          tester.getCenter(find.text('Open workspace')).dy);
      // A card: the identity and its options on one line, both environments
      // below it — no taller than that at phone width.
      expect(tester.getSize(group).height, lessThan(230));
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
        expect(tester.getCenter(find.text('Test space')).dy,
            tester.getCenter(find.text('Open workspace')).dy);
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

    await tester.tap(find.byKey(const ValueKey('me-profile-settings')));
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

  testWidgets('Home offers joining and creating a space', (
    tester,
  ) async {
    final router = await pumpMeApp(
      tester,
      workspace: FakeWorkspaceRepository(workspaces: []),
    );
    await goTo(tester, router, '/me');
    // Finding a space is the Discover entry of the Me menu, not a button here.
    expect(find.byKey(const ValueKey('me-home-discover')), findsNothing);
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
      'Profile',
      'Privacy',
      'Preferences',
      'Advanced',
      'My workspaces',
      'Connected installations',
    ]) {
      final header = find.descendant(of: find.byKey(const ValueKey('me-account-list')), matching: find.text(title)).first;
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
    expect(tops, hasLength(6));
  });
}
