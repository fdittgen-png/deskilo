// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — the characterized registry: what each target kind may invalidate.
// The all-scopes union is pinned by invalidation_mapping_golden_test.dart;
// this file pins the split (a workspace target never refreshes the
// account's providers, and the other way round), the composition rules and
// that the registry recovers after a refused lookup.
import 'package:deskilo/app/realtime_invalidations.dart';
import 'package:deskilo/core/realtime/invalidation_map.dart';
import 'package:deskilo/core/realtime/invalidation_registry.dart';
import 'package:deskilo/core/realtime/realtime_sync.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;
import 'package:flutter_test/flutter_test.dart';

const _workspace = {InvalidationScope.workspace};
const _account = {InvalidationScope.account};

Set<String> _names(Iterable<ProviderOrFamily> providers) => {
  for (final p in providers) '${p.name ?? p}',
};

void main() {
  final registry = realtimeInvalidationRegistry;

  // The providers that span workspaces. Everything else is one workspace's.
  const accountProviders = {
    'myMembershipsProvider',
    'myWorkspacesProvider',
    'defaultWorkspaceIdProvider',
    'conversationsProvider',
    'conversationMessagesProvider',
    'conversationParticipantsProvider',
  };

  test('every table the channel binds is contributed by some feature', () {
    for (final table in realtimeTables) {
      expect(registry.tables, contains(table), reason: table);
    }
    expect(registry.tables, contains(kProfilePresenceSignal));
  });

  test('a workspace target never reaches an account provider', () {
    for (final table in registry.tables) {
      final reached = _names(
        registry.lookup(table, scopes: _workspace).providers,
      );
      expect(reached.intersection(accountProviders), isEmpty, reason: table);
    }
  });

  test('an account target reaches exactly the account providers', () {
    final reached = {
      for (final table in registry.tables)
        ..._names(registry.lookup(table, scopes: _account).providers),
    };
    expect(reached, accountProviders);
  });

  test('the two targets together are the union the channel applies today', () {
    for (final table in registry.tables) {
      final both = _names([
        ...registry.lookup(table, scopes: _workspace).providers,
        ...registry.lookup(table, scopes: _account).providers,
      ]);
      expect(_names(invalidationFor(table).providers), both, reason: table);
    }
  });

  test('a refused contribution takes its plan-cache bust with it', () {
    // `members` busts the plan cache through the plan feature (workspace
    // scope); the account target must not trigger that bust.
    expect(
      registry.lookup('members', scopes: _workspace).bustsPlanCache,
      isTrue,
    );
    expect(
      registry.lookup('members', scopes: _account).bustsPlanCache,
      isFalse,
    );
  });

  test('an unknown table, or no target at all, invalidates nothing', () {
    expect(registry.lookup('no_such_table').providers, isEmpty);
    expect(registry.lookup('members', scopes: const {}).providers, isEmpty);
  });

  test('a refused lookup leaves the registry unchanged (recovery)', () {
    final before = _names(registry.lookup('members').providers);
    registry
      ..lookup('members', scopes: const {})
      ..lookup('members', scopes: _account);
    expect(_names(registry.lookup('members').providers), before);
    expect(before, contains('myMembershipsProvider'));
    expect(before, contains('workspaceMembersProvider'));
  });

  test(
    'contributions compose: a provider named twice is invalidated once, '
    'a bust from any contributor stands, order of features is irrelevant',
    () {
      InvalidationRegistry build(List<InvalidationContribution> c) =>
          InvalidationRegistry(c);
      final a = InvalidationContribution(
        const ['t'],
        [myMembershipsProvider],
        scope: InvalidationScope.account,
      );
      final b = InvalidationContribution(
        const ['t', 'u'],
        [myMembershipsProvider, myMemberProvider],
        bustsPlanCache: true,
      );
      for (final r in [
        build([a, b]),
        build([b, a]),
      ]) {
        final t = r.lookup('t');
        expect(t.providers.length, 2);
        expect(_names(t.providers), {
          'myMembershipsProvider',
          'myMemberProvider',
        });
        expect(t.bustsPlanCache, isTrue);
        expect(_names(r.lookup('u').providers), {
          'myMembershipsProvider',
          'myMemberProvider',
        });
        expect(r.lookup('t', scopes: _account).bustsPlanCache, isFalse);
      }
    },
  );
}
