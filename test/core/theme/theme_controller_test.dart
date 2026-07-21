// SPDX-License-Identifier: 0BSD
import 'package:deskilo/core/theme/theme_controller.dart';
import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// In-memory [ThemeStore] so tests never touch SharedPreferences.
class InMemoryThemeStore implements ThemeStore {
  InMemoryThemeStore({this.mode});

  String? mode;
  int writes = 0;

  @override
  Future<String?> read() async => mode;

  @override
  Future<void> write(String? mode) async {
    this.mode = mode;
    writes++;
  }
}

ProviderContainer containerWith(ThemeStore store) {
  final container = ProviderContainer(
    overrides: [themeStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('an empty store resolves to null — follow the system brightness',
      () async {
    final container = containerWith(InMemoryThemeStore());

    expect(await container.read(themeControllerProvider.future), isNull);
  });

  test('a stored mode resolves to that ThemeMode', () async {
    expect(
      await containerWith(InMemoryThemeStore(mode: 'dark'))
          .read(themeControllerProvider.future),
      ThemeMode.dark,
    );
    expect(
      await containerWith(InMemoryThemeStore(mode: 'light'))
          .read(themeControllerProvider.future),
      ThemeMode.light,
    );
  });

  test('an unknown stored value falls back to system (null)', () async {
    final container = containerWith(InMemoryThemeStore(mode: 'sepia'));

    expect(await container.read(themeControllerProvider.future), isNull);
  });

  test('set(mode) applies immediately and persists the mode', () async {
    final store = InMemoryThemeStore();
    final container = containerWith(store);
    await container.read(themeControllerProvider.future);

    await container
        .read(themeControllerProvider.notifier)
        .set(ThemeMode.dark);

    expect(container.read(themeControllerProvider).value, ThemeMode.dark);
    expect(store.mode, 'dark');
    expect(store.writes, 1);
  });

  test('set(null) clears the override back to system default', () async {
    final store = InMemoryThemeStore(mode: 'light');
    final container = containerWith(store);
    expect(
      await container.read(themeControllerProvider.future),
      ThemeMode.light,
    );

    await container.read(themeControllerProvider.notifier).set(null);

    expect(container.read(themeControllerProvider).value, isNull);
    expect(store.mode, isNull);
  });

  test('set(ThemeMode.system) is normalized to the null override', () async {
    final store = InMemoryThemeStore(mode: 'dark');
    final container = containerWith(store);
    await container.read(themeControllerProvider.future);

    await container
        .read(themeControllerProvider.notifier)
        .set(ThemeMode.system);

    expect(container.read(themeControllerProvider).value, isNull);
    expect(store.mode, isNull);
  });

  group('PrefsThemeStore round-trip', () {
    test('writes, reads and removes under the theme_mode_override key',
        () async {
      SharedPreferences.setMockInitialValues({});
      final store = PrefsThemeStore();

      expect(await store.read(), isNull);

      await store.write('dark');
      expect(await store.read(), 'dark');
      expect(
        (await SharedPreferences.getInstance())
            .getString('theme_mode_override'),
        'dark',
      );

      await store.write(null);
      expect(await store.read(), isNull);
    });
  });
}
