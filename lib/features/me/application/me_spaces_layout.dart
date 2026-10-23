// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/storage/space_prefs_store.dart';
import '../../workspace/domain/workspace.dart';
import '../domain/space_pairs.dart';

/// One group of Me › Home as laid out: its id and its rows' keys, in the
/// order they are shown.
typedef SpaceGroupRows = ({String id, List<String> keys});

/// Me › Home's list of my spaces before any widget is built: which rows
/// there are, which groups show which of them in what order, and what the
/// person may do with them.
class MeSpacesLayout {
  const MeSpacesLayout._({
    required this.rows,
    required this.groups,
    required this.visible,
    required this.filtered,
    required this.canDrag,
  });

  /// [spaces] in [prefs]' groups and order, filtered by [query]. Rows nobody
  /// placed keep the order they come in, the last used one ([lastUsedId])
  /// first.
  factory MeSpacesLayout.of({
    required SpacePrefs prefs,
    required List<Workspace> spaces,
    required String? lastUsedId,
    required String query,
  }) {
    final rows = {
      for (final sides in pairSides([
        ...spaces.where((w) => w.id == lastUsedId),
        ...spaces.where((w) => w.id != lastUsedId),
      ]))
        spaceRowKeyOf(sides.first): sides,
    };
    String nameOf(String key) => rows[key]!.first.name;
    final words = query.trim().toLowerCase();
    final filtered = words.isNotEmpty;
    final visible = [
      for (final key in rows.keys)
        if (!filtered || nameOf(key).toLowerCase().contains(words)) key,
    ];
    final groups = <SpaceGroupRows>[];
    for (final id in prefs.groupIds) {
      final keys = prefs.sorted([
        for (final key in visible)
          if (prefs.groupIdOf(key) == id) key,
      ], nameOf);
      // A search shows only the groups it found something in.
      if (filtered && keys.isEmpty) continue;
      groups.add((id: id, keys: keys));
    }
    return MeSpacesLayout._(
      rows: rows,
      groups: groups,
      visible: visible,
      filtered: filtered,
      // Holding a card moves it only in my own order, with nothing filtered.
      canDrag: prefs.sort == SpaceSort.byHand && !filtered,
    );
  }

  /// Each row's sides, production first, by row key.
  final Map<String, List<Workspace>> rows;

  /// The groups shown, in order, each with its rows.
  final List<SpaceGroupRows> groups;

  /// The rows the search lets through, whatever group they are in.
  final List<String> visible;

  /// Whether a search narrows the list.
  final bool filtered;

  /// Whether a row may be dragged to a new place.
  final bool canDrag;

  /// The search found nothing at all.
  bool get noMatch => filtered && visible.isEmpty;

  /// Whether the empty group [id] says how to fill it: Favorites and my own
  /// groups do, Other does not, and nothing does during a search.
  bool explainsEmpty(String id) => !filtered && id != SpaceGroup.otherGroup;
}
