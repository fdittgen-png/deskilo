// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2495 — the characterized invalidation registry. core/realtime owns the
// shape (what a contribution is, how contributions compose, how a lookup is
// narrowed to one target); each feature declares the providers of ITS OWN
// that cache a table, and lib/app composes the declarations. No feature is
// imported here.
import 'package:flutter_riverpod/misc.dart' show ProviderOrFamily;

import 'invalidation_map.dart';

/// Which kind of target a cached provider belongs to. A workspace target's
/// change feed must refresh only that workspace's providers; the facts that
/// span workspaces (the person's workspace list, memberships, default
/// workspace, the messenger) belong to the account target. The split lets
/// the personal and the workspace target of #2564 each apply only their own.
enum InvalidationScope { workspace, account }

/// What one feature says about one or more tables: the providers it owns
/// that render rows of them.
class InvalidationContribution {
  const InvalidationContribution(
    this.tables,
    this.providers, {
    this.scope = InvalidationScope.workspace,
    this.bustsPlanCache = false,
  });

  /// The tables whose change refreshes [providers].
  final List<String> tables;

  /// Providers of the declaring feature.
  final List<ProviderOrFamily> providers;

  final InvalidationScope scope;

  /// See [TableInvalidation.bustsPlanCache].
  final bool bustsPlanCache;
}

/// The composed contributions. Immutable; the same input composes the same
/// lookup, so the two freshness paths (realtime and a screen's own
/// mutation) cannot drift.
class InvalidationRegistry {
  InvalidationRegistry(Iterable<InvalidationContribution> contributions)
    : _contributions = List.unmodifiable(contributions) {
    for (final c in _contributions) {
      assert(
        c.tables.isNotEmpty && c.tables.every((t) => t.isNotEmpty),
        'a contribution names at least one table, and no empty one',
      );
    }
  }

  final List<InvalidationContribution> _contributions;

  /// Every table some feature contributed to.
  Set<String> get tables => {for (final c in _contributions) ...c.tables};

  /// What [table] invalidates for the targets in [scopes] (default: all,
  /// which is what the single active-workspace channel applies today). A
  /// contribution outside [scopes] is refused whole, including its plan
  /// cache bust. Each provider appears once. An unknown table is empty.
  TableInvalidation lookup(
    String table, {
    Set<InvalidationScope> scopes = const {
      InvalidationScope.workspace,
      InvalidationScope.account,
    },
  }) {
    final providers = <ProviderOrFamily>{};
    var bust = false;
    for (final c in _contributions) {
      if (!c.tables.contains(table) || !scopes.contains(c.scope)) continue;
      providers.addAll(c.providers);
      bust = bust || c.bustsPlanCache;
    }
    return TableInvalidation(providers.toList(), bustsPlanCache: bust);
  }
}
