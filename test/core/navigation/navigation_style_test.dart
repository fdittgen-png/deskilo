// SPDX-License-Identifier: 0BSD
//
// #969 — the navigation preference: persisted per device, applied to
// the shell instantly, and never a choice on the web.
import 'package:deskilo/app/shell/shell_drawer.dart';
import 'package:deskilo/core/navigation/navigation_style.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class InMemoryNavigationStyleStore implements NavigationStyleStore {
  InMemoryNavigationStyleStore({this.style});
  String? style;
  @override
  Future<String?> read() async => style;
  @override
  Future<void> write(String? style) async => this.style = style;
}

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
}
