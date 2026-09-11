// SPDX-License-Identifier: 0BSD
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../storage/prefs_stores.dart';

part 'navigation_style.g.dart';

/// How the shell navigates (#969): the classic bottom bar with the
/// round Reserve button, or the hamburger menu the web uses.
enum NavigationStyle {
  classic('classic'),
  menu('menu');

  const NavigationStyle(this.wire);

  /// The stored spelling.
  final String wire;

  static NavigationStyle? fromWire(String? wire) => switch (wire) {
        'classic' => NavigationStyle.classic,
        'menu' => NavigationStyle.menu,
        _ => null,
      };
}

/// Persists the navigation override. Same seam shape as `ThemeStore`,
/// so widget tests never touch platform channels.
abstract class NavigationStyleStore {
  /// The stored style, or null for "the platform's default".
  Future<String?> read();

  /// Persists [style]; null removes the override.
  Future<void> write(String? style);
}

class PrefsNavigationStyleStore extends PrefsStringStore
    implements NavigationStyleStore {
  const PrefsNavigationStyleStore() : super('navigation_style');
}

@Riverpod(keepAlive: true)
NavigationStyleStore navigationStyleStore(Ref ref) =>
    const PrefsNavigationStyleStore();

/// The platform the app runs on: the web has the menu and ONLY the
/// menu — a browser window has the width a phone lacks and none of the
/// thumb-reach the bar was built for — so the choice never appears
/// there. Tests override it to run "as the web".
@Riverpod(keepAlive: true)
bool platformIsWeb(Ref ref) => kIsWeb;

/// The user's navigation override; null means "what this platform gets
/// by default" (the bar on native, the menu on the web). Applied
/// instantly — the shell watches it.
@Riverpod(keepAlive: true)
class NavigationStyleController extends _$NavigationStyleController {
  @override
  Future<NavigationStyle?> build() async =>
      NavigationStyle.fromWire(await ref.watch(navigationStyleStoreProvider).read());

  Future<void> set(NavigationStyle? style) async {
    state = AsyncData(style);
    await ref.read(navigationStyleStoreProvider).write(style?.wire);
  }
}

/// What the shell actually shows: the menu on the web, always; on native
/// the bar unless the user asked for the menu.
bool shellUsesMenu({required bool platformIsWeb, NavigationStyle? override}) =>
    platformIsWeb || override == NavigationStyle.menu;
