// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb, visibleForTesting;
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

/// The device's stored choice, or null when it never chose — the default
/// then depends on who uses it and on what ([defaultNavigationStyle]).
@visibleForTesting
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

/// #2414 — whether this device is a phone: Android or iOS with a screen
/// whose shorter side is under 600 logical pixels (a tablet is not).
@Riverpod(keepAlive: true)
bool deviceIsPhone(Ref ref) {
  if (kIsWeb) return false;
  if (defaultTargetPlatform != TargetPlatform.android &&
      defaultTargetPlatform != TargetPlatform.iOS) {
    return false;
  }
  final views = PlatformDispatcher.instance.views;
  if (views.isEmpty) return true;
  final view = views.first;
  return (view.physicalSize / view.devicePixelRatio).shortestSide < 600;
}

/// #2414 — what a device that never chose gets: the menu, except for a
/// member who holds only the everyday permissions on a phone, who gets
/// the bar and its thumb-reach.
NavigationStyle defaultNavigationStyle({
  required bool isPhone,
  required bool everydayOnly,
}) =>
    isPhone && everydayOnly ? NavigationStyle.classic : NavigationStyle.menu;

/// The user's navigation choice, or null for the default
/// ([defaultNavigationStyle]); changed in Me and in a space's Settings.
/// Applied instantly — the shell watches it.
@Riverpod(keepAlive: true)
class NavigationStyleController extends _$NavigationStyleController {
  @override
  Future<NavigationStyle?> build() async =>
      NavigationStyle.fromWire(await ref.watch(navigationStyleStoreProvider).read());

  /// [style] null removes the stored choice: back to the default.
  Future<void> set(NavigationStyle? style) async {
    await ref.read(navigationStyleStoreProvider).write(style?.wire);
    state = AsyncData(
      NavigationStyle.fromWire(await ref.read(navigationStyleStoreProvider).read()),
    );
  }
}

/// What the shell actually shows: the menu on the web, always; on native
/// the stored choice, else [fallback] (the device's default).
bool shellUsesMenu({
  required bool platformIsWeb,
  NavigationStyle? override,
  NavigationStyle fallback = NavigationStyle.classic,
}) =>
    platformIsWeb || (override ?? fallback) == NavigationStyle.menu;
