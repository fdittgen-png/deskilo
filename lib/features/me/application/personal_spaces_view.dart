// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2554 — Me › My spaces, as a pure function of what was loaded: every
// workspace my account names (#2563 `my_personal_workspace_refs_v1`), each
// with its host, whether its membership is verified, and the one action
// its state allows. Nothing here reads a server; nothing here grants
// anything a reference does not already say.
//
// C3 — the entries as cards: one per test/production pair of this server
// (the two sides inside it), filtered by state, kept in the person's own
// order (favourites first, then Move up/down) on this device, and the
// Overview's preview ordered by when each space was last entered.
import 'package:meta/meta.dart';

import '../../../core/storage/space_prefs_store.dart';
import '../../workspace/domain/workspace.dart';
import '../domain/personal_workspace_refs.dart';
import '../domain/space_pairs.dart';

/// Where a space lives, as the personal home knows it.
enum PersonalSpaceHost {
  /// On the installation that answered: the person's own home.
  here,

  /// On another installation.
  elsewhere,
}

/// The one main action a space's state allows.
enum PersonalSpaceAction {
  /// An active membership of a space this server lists: walk in.
  open,

  /// A request not decided yet: its status, never operational access.
  requestStatus,

  /// History, an unverified relationship, or a saved space: no entry.
  none,
}

/// One space of My spaces.
class PersonalSpaceEntry {
  const PersonalSpaceEntry({required this.ref, this.local});

  final PersonalWorkspaceRef ref;

  /// The space of this server the reference names, when it is one of mine.
  final Workspace? local;

  PersonalSpaceHost get host =>
      ref.hostedHere ? PersonalSpaceHost.here : PersonalSpaceHost.elsewhere;

  /// The installation read the relationship from its own membership row.
  bool get verified =>
      ref.freshness == RefFreshness.local && ref.status != null;

  /// A development (test) space: its entry says so.
  bool get isTest => local?.isDevelopment ?? false;

  PersonalSpaceAction get action {
    if (!verified) return PersonalSpaceAction.none;
    return switch (ref.status) {
      RefStatus.active when local != null => PersonalSpaceAction.open,
      RefStatus.pending => PersonalSpaceAction.requestStatus,
      _ => PersonalSpaceAction.none,
    };
  }
}

/// My spaces from [refs], each matched to the space of this server it names
/// in [local] — by its qualified reference, so equal local ids on two
/// installations never meet. Favourites first, then the default, otherwise
/// in the order the home answered; filtered by [query] over the names that
/// may be read, the loaded records only.
@visibleForTesting
List<PersonalSpaceEntry> personalSpaceEntries(
  PersonalWorkspaceRefs refs,
  List<Workspace> local, {
  String query = '',
}) {
  Workspace? localOf(PersonalWorkspaceRef ref) {
    if (!ref.hostedHere) return null;
    for (final w in local) {
      if (w.networkId.isNotEmpty
          ? w.networkId == ref.networkId
          : w.id == ref.workspaceId) {
        return w;
      }
    }
    return null;
  }

  final needle = query.trim().toLowerCase();
  final entries = [
    for (final ref in refs.refs)
      if (needle.isEmpty ||
          (ref.label ?? '').toLowerCase().contains(needle))
        PersonalSpaceEntry(ref: ref, local: localOf(ref)),
  ];
  int rank(PersonalSpaceEntry e) =>
      e.ref.isFavorite ? 0 : (e.ref.isDefault ? 1 : 2);
  // A stable sort: equal ranks keep the home's order.
  final indexed = entries.indexed.toList()
    ..sort((a, b) {
      final byRank = rank(a.$2) - rank(b.$2);
      return byRank != 0 ? byRank : a.$1 - b.$1;
    });
  return [for (final (_, e) in indexed) e];
}

/// What My spaces shows: every loaded space, or the ones in one state.
enum PersonalSpaceFilter {
  all,

  /// An active relationship.
  active,

  /// A request not decided yet, and my guest visits.
  requests,

  /// Paused or left: history only.
  history;

  /// Whether my guest visits belong under this filter.
  bool get showsVisits => this == all || this == requests;

  bool _admits(RefStatus? status) => switch (this) {
        all => true,
        active => status == RefStatus.active,
        requests => status == RefStatus.pending,
        history => status == RefStatus.paused || status == RefStatus.exited,
      };
}

/// One card of My spaces: a lone space, or both sides of a test/production
/// pair of this server, production first.
class PersonalSpaceRow {
  const PersonalSpaceRow({required this.key, required this.sides});

  /// The key of the person's layout on this device: the pair's key for a
  /// space of this server, the qualified reference otherwise — so equal
  /// local ids on two installations never share one.
  final String key;
  final List<PersonalSpaceEntry> sides;

  /// The side the card leads with: production when the pair has one.
  PersonalSpaceEntry get main => sides.first;

  /// The test side of a pair, shown inside the card.
  PersonalSpaceEntry? get testSide =>
      sides.length > 1 ? sides.skip(1).first : null;

  /// Kept on this device, or saved on my account.
  bool favoriteIn(SpacePrefs prefs) =>
      prefs.favorites.contains(key) || sides.any((s) => s.ref.isFavorite);

  bool _matches(String needle, PersonalSpaceFilter filter) =>
      sides.any((s) =>
          filter._admits(s.ref.status) &&
          (needle.isEmpty ||
              (s.ref.label ?? '').toLowerCase().contains(needle)));
}

String _keyOf(PersonalSpaceEntry e) {
  final local = e.local;
  return local != null ? spaceRowKeyOf(local) : 'ref:${e.ref.networkId}';
}

/// Every space of [refs] as cards, in the person's order: favourites, then
/// the default, then as moved by hand ([SpacePrefs.arrange]), otherwise in
/// the home's order. [query] and [filter] narrow the loaded records only.
List<PersonalSpaceRow> personalSpaceRows(
  PersonalWorkspaceRefs refs,
  List<Workspace> local, {
  SpacePrefs prefs = SpacePrefs.empty,
  String query = '',
  PersonalSpaceFilter filter = PersonalSpaceFilter.all,
}) {
  final byKey = <String, List<PersonalSpaceEntry>>{};
  for (final e in personalSpaceEntries(refs, local)) {
    (byKey[_keyOf(e)] ??= []).add(e);
  }
  int prod(PersonalSpaceEntry e) =>
      (e.local?.env.isProduction ?? true) ? 0 : 1;
  final rows = [
    for (final MapEntry(:key, :value) in byKey.entries)
      PersonalSpaceRow(
        key: key,
        // A stable sort: production first, otherwise as they came.
        sides: [
          for (final (_, e) in value.indexed.toList()
            ..sort((a, b) {
              final c = prod(a.$2) - prod(b.$2);
              return c != 0 ? c : a.$1 - b.$1;
            }))
            e,
        ],
      ),
  ];
  final ordered = _ordered(rows, prefs);
  final needle = query.trim().toLowerCase();
  return [
    for (final row in ordered)
      if (row._matches(needle, filter)) row,
  ];
}

int _rank(PersonalSpaceRow row, SpacePrefs prefs) => row.favoriteIn(prefs)
    ? 0
    : (row.sides.any((s) => s.ref.isDefault) ? 1 : 2);

List<PersonalSpaceRow> _ordered(
    List<PersonalSpaceRow> rows, SpacePrefs prefs) {
  final byKey = {for (final r in rows) r.key: r};
  final arranged = prefs.arrange([for (final r in rows) r.key]);
  final indexed = arranged.indexed.toList()
    ..sort((a, b) {
      final c = _rank(byKey[a.$2]!, prefs) - _rank(byKey[b.$2]!, prefs);
      return c != 0 ? c : a.$1 - b.$1;
    });
  return [for (final (_, k) in indexed) byKey[k]!];
}

/// The keys [row] moves among with Move up/down: the cards of its own rank
/// (favourites among favourites), in the order [rows] (unfiltered) shows.
List<String> personalSpaceMoveScope(
  List<PersonalSpaceRow> rows,
  PersonalSpaceRow row,
  SpacePrefs prefs,
) {
  final rank = _rank(row, prefs);
  return [
    for (final r in rows)
      if (_rank(r, prefs) == rank) r.key,
  ];
}

/// The Overview's first [count] spaces: favourites, then the most recently
/// entered on this device, then the rest in My spaces' order.
List<PersonalSpaceRow> personalSpacePreview(
  PersonalWorkspaceRefs refs,
  List<Workspace> local, {
  required SpacePrefs prefs,
  required int count,
}) {
  final rows = personalSpaceRows(refs, local, prefs: prefs);
  int fav(PersonalSpaceRow r) => r.favoriteIn(prefs) ? 0 : 1;
  final indexed = rows.indexed.toList()
    ..sort((a, b) {
      final f = fav(a.$2) - fav(b.$2);
      if (f != 0) return f;
      final used = (prefs.lastUsed[b.$2.key] ?? 0)
          .compareTo(prefs.lastUsed[a.$2.key] ?? 0);
      return used != 0 ? used : a.$1 - b.$1;
    });
  return [for (final (_, r) in indexed.take(count)) r];
}
