// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The personal shell (the `personalShell` flag on): Me is five route-owned
// destinations — the bar on a phone, a rail from 840, a sidebar from 1200,
// the navigation menu when the bar has no room — each branch keeping its
// stack across a switch and a reselect; every legacy personal address keeps
// its meaning at its new one (NAV-02), and off, every new address leads back
// to the legacy screen. A personal-only account with no space at all opens
// its account, help and sign-out (NAV-01). The layer wears the personal
// tokens under the shell; a space keeps its own.
import 'dart:io';

import 'package:deskilo/app/shell/shell_screen.dart';
import 'package:deskilo/core/theme/personal_theme.dart';
import 'package:deskilo/features/directory/presentation/account_messenger_screen.dart';
import 'package:deskilo/features/me/presentation/me_personal_shell.dart';
import 'package:deskilo/features/me/presentation/me_shell.dart';
import 'package:deskilo/features/me/providers/personal_shell_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';
import 'me_app.dart';

const _phone = Size(390, 844);

Future<GoRouter> _pumpOn(
  WidgetTester tester, {
  FakeWorkspaceRepository? workspace,
  FakeMessengerRepository? messenger,
  Size size = _phone,
}) =>
    pumpMeApp(
      tester,
      workspace: workspace ?? FakeWorkspaceRepository(workspaces: []),
      messenger: messenger,
      size: size,
      extraOverrides: [personalShellEnabledProvider.overrideWithValue(true)],
    );

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.tap(finder);
  await tester.pumpAndSettle();
}

Future<void> _resize(WidgetTester tester, Size size) async {
  tester.view.physicalSize = size;
  await tester.pumpAndSettle();
}

Finder _key(String key) => find.byKey(ValueKey(key));

void main() {
  testWidgets('a phone has the five destinations in a bar; a switch restores '
      'a branch\'s stack and a reselect keeps it', (tester) async {
    final router = await _pumpOn(tester);
    expect(router.state.uri.path, '/me');
    expect(_key('me-shell'), findsOneWidget);
    expect(_key('me-bar'), findsOneWidget);
    expect(find.byType(MeShell), findsNothing, reason: 'the legacy shell is off');
    for (final tab in MeTab.destinations) {
      await _tap(tester, _key(tab.destinationKey));
      expect(router.state.uri.path, tab.path, reason: tab.wire);
      expect(_key(tab.destinationKey), findsOneWidget);
    }
    expect(_key('finances-tabs'), findsOneWidget,
        reason: 'My data opens on the finances');
    // A page over the Messages branch: its own header, no competing bar.
    await goTo(tester, router, '/me/messages/new?source=&name=');
    expect(find.byType(AccountMessengerScreen), findsOneWidget);
    expect(_key('me-bar'), findsNothing);
    expect(_key('me-scope-badge'), findsNothing);
    await goTo(tester, router, '/me');
    expect(_key('me-bar'), findsOneWidget);
    await _tap(tester, _key('me-tab-messages'));
    expect(router.state.uri.path, '/me/messages/new',
        reason: 'the switch restores the branch\'s stack');
    await goTo(tester, router, '/me/discover');
    await _tap(tester, _key('me-tab-discover'));
    expect(router.state.uri.path, '/me/discover',
        reason: 'a reselect keeps the branch where it is');
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy tab links open their destinations; an unknown tab is '
      'Overview', (tester) async {
    final router = await _pumpOn(tester);
    expect(await goTo(tester, router, '/me?tab=discover'), '/me/discover');
    expect(await goTo(tester, router, '/me?tab=messages'), '/me/messages');
    expect(await goTo(tester, router, '/me?tab=me'), '/me/account');
    expect(_key('me-account-list'), findsOneWidget);
    expect(await goTo(tester, router, '/me?tab=home'), '/me');
    expect(await goTo(tester, router, '/me?tab=nowhere'), '/me');
    expect(_key('me-home-empty'), findsOneWidget);
  });

  testWidgets('NAV-02: legacy personal routes keep their exact target and '
      'parameters at their new addresses', (tester) async {
    final router = await _pumpOn(tester, workspace: twoSpaces());
    expect(await goTo(tester, router, '/account-activity?workspace=ws-1'),
        '/me/data?view=finances&workspace=ws-1');
    expect(_key('finances-tabs'), findsOneWidget);
    expect(
      await goTo(tester, router,
          '/account-messages?source=https%3A%2F%2Fa.example&recipient=u-2&name=Jane'),
      '/me/messages/u-2?source=https%3A%2F%2Fa.example&name=Jane',
    );
    expect(await goTo(tester, router, '/account-messages?source=x'),
        '/me/messages/new?source=x');
    expect(find.byType(AccountMessengerScreen), findsOneWidget);
    expect(await goTo(tester, router, '/profiles'), '/me/spaces');
    expect(_key('profiles-add'), findsOneWidget);
    expect(await goTo(tester, router, '/connections'), '/me/account/connections');
    expect(await goTo(tester, router, '/me/messages/thread'), '/me',
        reason: 'the named messenger pages match before :ref and fall back '
            'without their argument');
  });

  testWidgets('the shell off: every personal-shell address leads to the '
      'legacy screen that holds the same thing', (tester) async {
    final router =
        await pumpMeApp(tester, workspace: twoSpaces(), size: _phone);
    expect(await goTo(tester, router, '/me/spaces'), '/me');
    expect(find.byType(MeShell), findsOneWidget);
    expect(await goTo(tester, router, '/me/discover'), '/me?tab=discover');
    expect(await goTo(tester, router, '/me/messages'), '/me?tab=messages');
    expect(await goTo(tester, router, '/me/account'), '/me?tab=me');
    expect(_key('me-account-list'), findsOneWidget);
    expect(await goTo(tester, router, '/me/account/connections'), '/connections');
    expect(await goTo(tester, router, '/me/messages/new?source=s'),
        '/account-messages?source=s');
    expect(await goTo(tester, router, '/me/messages/u-2?source=s&name=n'),
        '/account-messages?source=s&name=n&recipient=u-2');
    expect(await goTo(tester, router, '/me/data?view=finances&workspace=ws-1'),
        '/account-activity?workspace=ws-1');
    expect(await goTo(tester, router, '/me/data'), '/account-activity');
    expect(find.byType(MePersonalShell), findsNothing);
  });

  testWidgets('NAV-01: a personal-only account with no space opens its '
      'account, help and sign-out', (tester) async {
    final router = await _pumpOn(tester);
    expect(await goTo(tester, router, '/me/account'), '/me/account');
    expect(_key('me-account-list'), findsOneWidget);
    expect(_key('me-sign-out'), findsOneWidget);
    expect(_key('me-privacy'), findsOneWidget);
    await tapIn(tester, 'me-account-list', _key('me-help'));
    expect(router.state.uri.path, '/me/account',
        reason: 'help opens outside; the page stays');
    expect(tester.takeException(), isNull);
    final source =
        File('lib/features/me/presentation/me_account_tab.dart').readAsStringSync();
    for (final forbidden in [
      'workspace_providers.dart',
      'workspace_feature.dart',
      'currentWorkspaceProvider',
    ]) {
      expect(source, isNot(contains(forbidden)),
          reason: 'the account tab needs no workspace: $forbidden');
    }
  });

  testWidgets('the account utility opens from the one avatar and Back '
      'returns to the branch', (tester) async {
    final router = await _pumpOn(tester);
    await goTo(tester, router, '/me/discover');
    await _tap(tester, _key('me-profile-settings'));
    expect(router.state.uri.path, '/me/account');
    expect(_key('me-account-list'), findsOneWidget);
    expect(_key('me-scope-badge'), findsNothing,
        reason: 'a page over a branch brings its own header');
    await _tap(tester, find.byType(BackButton));
    expect(router.state.uri.path, '/me');
    expect(_key('me-scope-badge'), findsOneWidget);
  });

  testWidgets('a wide window keeps a sidebar, a medium one a rail, a phone '
      'the bar', (tester) async {
    final router = await _pumpOn(tester, size: const Size(1300, 900));
    expect(_key('me-sidebar'), findsOneWidget);
    expect(_key('me-bar'), findsNothing);
    expect(_key('me-scope-badge'), findsNWidgets(2),
        reason: 'the header and the sidebar name the Personal scope');
    await _tap(tester, _key('me-tab-discover'));
    expect(router.state.uri.path, '/me/discover');
    expect(tester.widget<ListTile>(_key('me-tab-discover')).selected, isTrue);
    expect(_key('me-utility-help'), findsOneWidget);
    expect(_key('me-tab-me'), findsOneWidget);
    await _resize(tester, const Size(1000, 900));
    expect(_key('me-sidebar'), findsNothing);
    expect(_key('me-rail'), findsOneWidget);
    expect(_key('me-bar'), findsNothing);
    await _tap(tester, _key('me-tab-messages'));
    expect(router.state.uri.path, '/me/messages');
    expect(tester.getSize(_key('me-rail')).width,
        PersonalShellMetrics.railWidth);
    await _resize(tester, _phone);
    expect(_key('me-rail'), findsNothing);
    expect(_key('me-bar'), findsOneWidget);
    expect(router.state.uri.path, '/me/messages',
        reason: 'a resize changes the chrome, never the destination');
    expect(tester.takeException(), isNull);
  });

  testWidgets('a short window has no bar: the destinations are in the '
      'navigation menu', (tester) async {
    final router = await _pumpOn(tester, size: const Size(800, 400));
    expect(_key('me-bar'), findsNothing);
    expect(_key('me-rail'), findsNothing);
    await _tap(tester, find.byTooltip('Open navigation menu'));
    expect(_key('me-drawer'), findsOneWidget);
    for (final tab in MeTab.destinations) {
      expect(_key(tab.destinationKey), findsOneWidget, reason: tab.wire);
    }
    await _tap(tester, _key('me-tab-data'));
    expect(router.state.uri.path, '/me/data');
    expect(_key('me-drawer'), findsNothing);
  });

  testWidgets('the Messages badge counts unread before the branch is opened',
      (tester) async {
    final messenger = FakeMessengerRepository()
      ..inboxRows.add({
        'context_kind': 'account',
        'context_id': 'new',
        'title': 'New',
        'unread': 124,
      });
    await _pumpOn(tester, messenger: messenger);
    expect(
      find.descendant(of: _key('me-tab-messages'), matching: find.text('99+')),
      findsOneWidget,
    );
  });

  testWidgets('My data switches its view through the route', (tester) async {
    final router = await _pumpOn(tester);
    expect(await goTo(tester, router, '/me/data'), '/me/data');
    expect(_key('finances-tabs'), findsOneWidget);
    await _tap(tester, _key('me-data-view-reservations'));
    expect(router.state.uri.toString(), '/me/data?view=reservations');
    expect(_key('me-data-visits-empty'), findsOneWidget);
    await _tap(tester, _key('me-data-view-profile'));
    expect(router.state.uri.toString(), '/me/data?view=profile');
    expect(_key('settings-photo'), findsOneWidget);
    expect(await goTo(tester, router, '/me/data?view=finances'),
        '/me/data?view=finances');
    expect(_key('finances-tabs'), findsOneWidget);
  });

  testWidgets('the layer wears the personal tokens under the shell; a space '
      'keeps its own', (tester) async {
    final router = await _pumpOn(tester, workspace: twoSpaces());
    await goTo(tester, router, '/me');
    final me = tester.element(find.byType(MePersonalShell));
    expect(Theme.of(me).colorScheme.primary, PersonalTheme.light.primary);
    expect(Theme.of(me).scaffoldBackgroundColor, PersonalTheme.light.canvas);
    expect(PersonalTheme.of(me), PersonalTheme.light);
    await goTo(tester, router, '/reserve');
    final space = tester.element(find.byType(ShellScreen));
    expect(Theme.of(space).colorScheme.primary,
        isNot(PersonalTheme.light.primary));
    expect(Theme.of(space).extension<PersonalTheme>(), isNull);
  });
}
