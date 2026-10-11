// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #969 — the navigation preference: persisted per device, applied to
// the shell instantly, and never a choice on the web.
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_pref_stores.dart';


void main() {
  test('the web has the menu and only the menu; native follows the choice',
      () {
    expect(shellUsesMenu(platformIsWeb: true), isTrue);
    expect(shellUsesMenu(platformIsWeb: true, override: NavigationStyle.classic),
        isTrue, reason: 'a stored native choice never reaches the web');
    expect(shellUsesMenu(platformIsWeb: false), isFalse);
    expect(shellUsesMenu(platformIsWeb: false, override: NavigationStyle.menu),
        isTrue);
    expect(
        shellUsesMenu(platformIsWeb: false, override: NavigationStyle.classic),
        isFalse);
  });

  test('the controller reads the stored spelling, persists a change, and '
      'the shell switch follows it', () async {
    final store = InMemoryNavigationStyleStore(style: 'menu');
    final container = ProviderContainer(overrides: [
      navigationStyleStoreProvider.overrideWithValue(store),
      platformIsWebProvider.overrideWithValue(false),
    ]);
    addTearDown(container.dispose);
    expect(await container.read(navigationStyleControllerProvider.future),
        NavigationStyle.menu);
    expect(container.read(webShellProvider), isTrue);

    await container
        .read(navigationStyleControllerProvider.notifier)
        .set(NavigationStyle.classic);
    expect(store.style, 'classic');
    expect(container.read(webShellProvider), isFalse);

    await container.read(navigationStyleControllerProvider.notifier).set(null);
    expect(store.style, isNull, reason: 'null clears the override');
    expect(NavigationStyle.fromWire('nonsense'), isNull);
  });

  // #2414 — the default when the device never chose.
  test('the menu by default, except a member with everyday permissions only '
      'on a phone', () {
    expect(defaultNavigationStyle(isPhone: true, everydayOnly: true),
        NavigationStyle.classic);
    expect(defaultNavigationStyle(isPhone: true, everydayOnly: false),
        NavigationStyle.menu);
    expect(defaultNavigationStyle(isPhone: false, everydayOnly: true),
        NavigationStyle.menu);
    expect(shellUsesMenu(platformIsWeb: false, fallback: NavigationStyle.menu),
        isTrue);
    expect(
        shellUsesMenu(
            platformIsWeb: false,
            override: NavigationStyle.classic,
            fallback: NavigationStyle.menu),
        isFalse,
        reason: 'a stored choice wins over the default');
  });

  group('#2414 — the shell follows the device default', () {
    Future<bool> shell({
      required bool phone,
      Member? member,
      Set<WorkspacePermission> permissions = const {},
      List<Member> memberships = const [],
    }) async {
      final container = ProviderContainer(overrides: [
        navigationStyleStoreProvider
            .overrideWithValue(InMemoryNavigationStyleStore()),
        platformIsWebProvider.overrideWithValue(false),
        deviceIsPhoneProvider.overrideWithValue(phone),
        myMemberProvider.overrideWith((ref) async => member),
        myPermissionsProvider.overrideWithValue(permissions),
        myMembershipsProvider.overrideWith((ref) async => memberships),
      ]);
      addTearDown(container.dispose);
      await container.read(navigationStyleControllerProvider.future);
      await container.read(myMemberProvider.future);
      await container.read(myMembershipsProvider.future);
      return container.read(webShellProvider);
    }

    Member who({bool admin = false, bool owner = false}) => Member(
          id: 'm',
          workspaceId: 'ws',
          userId: 'u',
          isAdmin: admin,
          isOwner: owner,
          status: MemberStatus.active,
        );

    test('a member on a phone gets the bar', () async {
      expect(
          await shell(
              phone: true,
              member: who(),
              permissions: {WorkspacePermission.makeReservations}),
          isFalse);
    });

    test('an administrator on a phone gets the menu', () async {
      expect(
          await shell(
              phone: true,
              member: who(admin: true),
              permissions: {
                WorkspacePermission.makeReservations,
                WorkspacePermission.manageMembers,
              }),
          isTrue);
    });

    test('a member on a tablet gets the menu', () async {
      expect(
          await shell(
              phone: false,
              member: who(),
              permissions: {WorkspacePermission.makeReservations}),
          isTrue);
    });

    test('in Me: the bar for someone who runs no space, the menu for an '
        'owner', () async {
      expect(await shell(phone: true, memberships: [who()]), isFalse);
      expect(await shell(phone: true, memberships: [who(owner: true)]), isTrue);
    });
  });
}
