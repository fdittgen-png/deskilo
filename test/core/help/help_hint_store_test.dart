// SPDX-License-Identifier: 0BSD
//
// #606 — the help-hint dismissal store and its provider: dismiss hides
// (and persists eagerly), restore brings everything back, and unknown
// ids in the stored set are tolerated so removed hints never crash a
// device that dismissed them long ago.
// #610 — the carousel positions: the last-shown tip index persists per
// surface, a fresh visit opens on the NEXT tip (rotating), and stored
// indices from a longer, older tip list fold back with a modulo.
import 'package:deskilo/core/help/help_hint.dart';
import 'package:deskilo/core/help/help_hint_providers.dart';
import 'package:deskilo/core/storage/help_hint_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

ProviderContainer _container(HelpHintStore store) {
  final container = ProviderContainer(
    overrides: [helpHintStoreProvider.overrideWithValue(store)],
  );
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

    await container.read(dismissedHelpHintsProvider.notifier).dismiss('plan');

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

  test('unknown ids in the stored set are tolerated and preserved', () async {
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

  test(
    'positions load from the store and setPosition persists eagerly',
    () async {
      final store = InMemoryHelpHintStore()..positions = {'reserve': 2};
      final container = _container(store);

      final loaded = await container.read(helpHintPositionsProvider.future);
      expect(loaded, {'reserve': 2});

      await container
          .read(helpHintPositionsProvider.notifier)
          .setPosition('plan', 1);
      expect(container.read(helpHintPositionsProvider).value, {
        'reserve': 2,
        'plan': 1,
      });
      // The next session's build reads it back — that is the rotation's
      // whole memory.
      expect(store.positions, {'reserve': 2, 'plan': 1});
    },
  );

  test('each visit opens on the tip after the stored one, rotating', () {
    // Never visited: start at tip 1.
    expect(HelpHint.initialTipIndex(null, 4), 0);
    // Normal advance.
    expect(HelpHint.initialTipIndex(0, 4), 1);
    expect(HelpHint.initialTipIndex(2, 4), 3);
    // Past the end: rotate back to 0.
    expect(HelpHint.initialTipIndex(3, 4), 0);
  });

  test('stored indices from a shrunken or corrupt tip list fold back', () {
    // An older version had 7 tips; this one has 4.
    expect(HelpHint.initialTipIndex(6, 4), 3);
    expect(HelpHint.initialTipIndex(7, 4), 0);
    // Garbage negative values never crash and stay in range.
    expect(HelpHint.initialTipIndex(-3, 4), 2);
    // Degenerate tip counts never divide by zero.
    expect(HelpHint.initialTipIndex(2, 0), 0);
  });

  test('the prefs wire format round-trips through readPositions', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const {});
    const store = PrefsHelpHintStore();

    await store.writePositions({'reserve': 3, 'plan': 0});
    expect(await store.readPositions(), {'reserve': 3, 'plan': 0});

    // Clearing every position removes the key — fresh-install state.
    await store.writePositions(const {});
    expect(await store.readPositions(), isEmpty);
  });

  test('malformed stored position entries are skipped, not fatal', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const {
      'help_hint_positions': <String>[
        'reserve:2',
        'no-separator',
        'plan:not-a-number',
        ':3',
      ],
    });
    const store = PrefsHelpHintStore();
    expect(await store.readPositions(), {'reserve': 2});
  });
}
