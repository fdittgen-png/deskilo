// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/storage/space_prefs_store.dart';
import '../../../core/text/collation.dart';
import '../../workspace/domain/organisation.dart';
import '../../workspace/domain/workspace.dart';
import '../domain/space_pairs.dart';

/// One group of Me › Home as laid out: its id, its rows' keys in the order
/// they are shown, and — for an organisation (#4006) — its name.
typedef SpaceGroupRows = ({String id, List<String> keys, String? organisation});

/// #4006 — an organisation's group id is this prefix and the organisation's.
const _organisationGroup = 'organisation:';

/// #4007 — the organisation a group of Me shows, or none for another group.
String? organisationOfGroup(String groupId) =>
    groupId.startsWith(_organisationGroup)
        ? groupId.substring(_organisationGroup.length)
        : null;

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
  /// first. #4006 — the houses of each of [organisations] come first, as
  /// one group under the organisation's name, the head first and then by
  /// country; they are in none of the person's own groups.
  factory MeSpacesLayout.of({
    required SpacePrefs prefs,
    required List<Workspace> spaces,
    required String? lastUsedId,
    required String query,
    List<Organisation> organisations = const [],
  }) {
    final rows = {
      for (final sides in pairSides([
        ...spaces.where((w) => w.id == lastUsedId),
        ...spaces.where((w) => w.id != lastUsedId),
      ]))
        spaceRowKeyOf(sides.first): sides,
    };
    String nameOf(String key) => rows[key]!.first.name;
    final words = foldForSearch(query.trim());
    final filtered = words.isNotEmpty;
    final visible = [
      for (final key in rows.keys)
        if (!filtered || foldForSearch(nameOf(key)).contains(words)) key,
    ];
    final housed = <String>{};
    final groups = _organisationGroups(organisations, rows, visible, housed);
    for (final id in prefs.groupIds) {
      final keys = prefs.sorted([
        for (final key in visible)
          if (prefs.groupIdOf(key) == id && !housed.contains(key)) key,
      ], nameOf);
      // A search shows only the groups it found something in.
      if (filtered && keys.isEmpty) continue;
      groups.add((id: id, keys: keys, organisation: null));
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

  /// #4006 — one group per organisation, its houses' rows in its order;
  /// each row taken is added to [housed].
  static List<SpaceGroupRows> _organisationGroups(
    List<Organisation> organisations,
    Map<String, List<Workspace>> rows,
    List<String> visible,
    Set<String> housed,
  ) {
    // The row of each house: the row one of its sides is.
    final rowOfSpace = {
      for (final MapEntry(:key, :value) in rows.entries)
        for (final side in value) side.id: key,
    };
    return [
      for (final organisation in organisations)
        if ([
              for (final house in organisation.byCountry)
                if (rowOfSpace[house.workspaceId] case final key?)
                  if (housed.add(key) && visible.contains(key)) key,
            ]
            case final keys when keys.isNotEmpty)
          (
            id: '$_organisationGroup${organisation.id}',
            keys: keys,
            organisation: organisation.name,
          ),
    ];
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
