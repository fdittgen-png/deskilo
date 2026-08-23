// SPDX-License-Identifier: 0BSD
//
// #606 — the help-hint dismissal store and its provider: dismiss hides
// (and persists eagerly), restore brings everything back, and unknown
// ids in the stored set are tolerated so removed hints never crash a
// device that dismissed them long ago.
import 'package:deskilo/core/help/help_hint_providers.dart';
import 'package:deskilo/core/storage/help_hint_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container(HelpHintStore store) {
  final container = ProviderContainer(overrides: [
    helpHintStoreProvider.overrideWithValue(store),
  ]);
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the provider loads the persisted set on build', () async {
    final store = InMemoryHelpHintStore()..dismissed = {'reserve'};
    final container = _container(store);

    final loaded = await container.read(dismissedHelpHintsProvider.future);
    expect(loaded, {'reserve'});
  });

  test('dismiss adds the id and persists eagerly', () async {
    final store = InMemoryHelpHintStore();
    final container = _container(store);
    await container.read(dismissedHelpHintsProvider.future);

    await container
        .read(dismissedHelpHintsProvider.notifier)
        .dismiss('plan');

    expect(container.read(dismissedHelpHintsProvider).value, {'plan'});
    // The next session's build reads it back.
    expect(store.dismissed, {'plan'});
  });

  test('restoreAll clears the set — every hint returns', () async {
    final store = InMemoryHelpHintStore()
      ..dismissed = {'reserve', 'plan', 'money'};
    final container = _container(store);
    await container.read(dismissedHelpHintsProvider.future);

    await container.read(dismissedHelpHintsProvider.notifier).restoreAll();

    expect(container.read(dismissedHelpHintsProvider).value, isEmpty);
    expect(store.dismissed, isEmpty);
  });

  test('unknown ids in the stored set are tolerated and preserved',
      () async {
    // A hint that no longer exists (or was written by a newer version).
    final store = InMemoryHelpHintStore()..dismissed = {'gone_hint'};
    final container = _container(store);

    final loaded = await container.read(dismissedHelpHintsProvider.future);
    expect(loaded, {'gone_hint'});

    // Dismissing a real hint keeps the unknown entry untouched.
    await container
        .read(dismissedHelpHintsProvider.notifier)
        .dismiss('reserve');
    expect(store.dismissed, {'gone_hint', 'reserve'});
  });
}
