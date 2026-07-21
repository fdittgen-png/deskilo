// SPDX-License-Identifier: 0BSD
import 'dart:ui';

import 'package:deskilo/core/locale/locale_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory [LocaleStore] so tests never touch SharedPreferences.
class InMemoryLocaleStore implements LocaleStore {
  InMemoryLocaleStore({this.code});

  String? code;
  int writes = 0;

  @override
  Future<String?> read() async => code;

  @override
  Future<void> write(String? languageCode) async {
    code = languageCode;
    writes++;
  }
}

ProviderContainer containerWith(LocaleStore store) {
  final container = ProviderContainer(
    overrides: [localeStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('an empty store resolves to null — follow the system locale',
      () async {
    final container = containerWith(InMemoryLocaleStore());

    expect(await container.read(localeControllerProvider.future), isNull);
  });

  test('a stored language code resolves to that locale', () async {
    final container = containerWith(InMemoryLocaleStore(code: 'fr'));

    expect(
      await container.read(localeControllerProvider.future),
      const Locale('fr'),
    );
  });

  test('set(locale) applies immediately and persists the code', () async {
    final store = InMemoryLocaleStore();
    final container = containerWith(store);
    await container.read(localeControllerProvider.future);

    await container
        .read(localeControllerProvider.notifier)
        .set(const Locale('de'));

    expect(
      container.read(localeControllerProvider).value,
      const Locale('de'),
    );
    expect(store.code, 'de');
    expect(store.writes, 1);
  });

  test('set(null) clears the override back to system default', () async {
    final store = InMemoryLocaleStore(code: 'it');
    final container = containerWith(store);
    expect(
      await container.read(localeControllerProvider.future),
      const Locale('it'),
    );

    await container.read(localeControllerProvider.notifier).set(null);

    expect(container.read(localeControllerProvider).value, isNull);
    expect(store.code, isNull);
  });
}
