// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- item groups on screen: a group holds shared settings and an item inherits each of them unless it
// keeps its own value. The server decides everything (`item_groups_v1`, `item_group_save_v1`,
// `item_group_assign_v1`, `item_override_save_v1`, `item_group_delete_v1`, `item_effective_settings_v1`,
// `item_group_history_v1`); this file is what it answers and the port the screens use. A save or a move first asks
// for a PREVIEW (`apply: false`: what it would reach, what keeps its own value, what it cannot reach) and only then
// applies, with one request id per sheet and the revision it read.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart' show JsonReader;

/// The parameters this version edits, in the order a sheet shows them.
const itemGroupEditable = [
  'tracking',
  'shelf_life_days',
  'tag_mode',
  'inventory_unit',
  'count_every_days',
  'min_age',
  'sold_by_weight',
  'till_category',
  'quick_key_colour',
  'deposit_item_id',
  'deposit_minor',
  'label_template',
  'vat_rate_id',
  'supply_class',
];

/// The proposals a group carries: copied into a new item as a starting point, never inherited and never linked, so a
/// change of one reaches no item.
const itemGroupProposals = [
  'default_purchase_unit',
  'default_purchase_factor_num',
  'default_purchase_factor_den',
  'default_sale_unit',
  'default_sale_factor_num',
  'default_sale_factor_den',
  'default_sale_price_cents',
  'reorder_point_default',
  'reorder_quantity_default',
  'home_zone_id',
  'price_rounding',
  'target_margin_bps',
];

/// A group: its name, its parent (a group nests one level), the parameters it sets (a parameter it does not set
/// is absent or null) and how many items belong to it.
class ItemGroup {
  const ItemGroup({required this.id, required this.parentId, required this.name, required this.revision, required this.params, required this.items});

  final String id;
  final String? parentId;
  final String name;
  final int revision;
  final Map<String, Object?> params;
  final int items;

  factory ItemGroup.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'item_groups');
    final raw = json! as Map;
    return ItemGroup(
      id: r.string('id'),
      parentId: r.stringOrNull('parent_id'),
      name: r.string('name'),
      revision: r.intOrNull('revision') ?? 0,
      params: {for (final k in [...itemGroupEditable, ...itemGroupProposals]) if (raw[k] != null) k: raw[k]},
      items: r.intOrNull('items') ?? 0,
    );
  }
}

/// What one changed parameter does to the items: reached, keeping their own value, or skipped.
class GroupImpact {
  const GroupImpact({required this.affected, required this.keptOwn, required this.skipped});

  final int affected;
  final int keptOwn;
  final int skipped;
}

/// An item a change could not reach, and why (tags bound, stock in lots, movements in another unit...).
class SkippedItem {
  const SkippedItem({required this.itemId, required this.parameter, required this.reason});

  final String itemId;
  final String parameter;
  final String reason;
}

/// The answer to a group save (or its preview).
class GroupSaved {
  const GroupSaved({required this.groupId, required this.revision, required this.created, required this.applied, required this.items, required this.impact, required this.skipped});

  final String groupId;
  final int revision;
  final bool created;
  final bool applied;
  final int items;
  final Map<String, GroupImpact> impact;
  final List<SkippedItem> skipped;

  factory GroupSaved.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'item_group_save');
    final impact = <String, GroupImpact>{};
    final params = r.objectOrNull('parameters');
    final raw = (json! as Map)['parameters'];
    if (params != null && raw is Map) {
      for (final k in raw.keys) {
        final p = JsonReader.of(raw[k], context: 'item_group_save.parameters');
        impact['$k'] = GroupImpact(affected: p.intOrNull('affected') ?? 0, keptOwn: p.intOrNull('kept_own') ?? 0, skipped: p.intOrNull('skipped') ?? 0);
      }
    }
    final skipped = ((json as Map)['skipped'] as List? ?? const []).map((s) {
      final x = JsonReader.of(s, context: 'item_group_save.skipped');
      return SkippedItem(itemId: x.string('item_id'), parameter: x.string('parameter'), reason: x.string('reason'));
    }).toList();
    return GroupSaved(
      groupId: r.string('group_id'),
      revision: r.intOrNull('revision') ?? 0,
      created: r.boolOr('created', fallback: false),
      applied: r.boolOr('applied', fallback: false),
      items: r.intOrNull('items') ?? 0,
      impact: impact,
      skipped: skipped,
    );
  }
}

/// One parameter of an item as it is in force: its value, where it comes from (`item`, `group`, `subgroup`,
/// `business`, `system`, `none`, `hidden`), the group that gave it and since when.
class EffectiveParam {
  const EffectiveParam({required this.value, required this.source, this.group, this.since});

  final Object? value;
  final String source;
  final String? group;
  final DateTime? since;

  /// The item keeps a value of its own.
  bool get own => source == 'item';
}

/// An item's settings as they are in force, with the problems the server found.
class ItemEffective {
  const ItemEffective({required this.itemId, required this.groupId, required this.params, required this.problems});

  final String itemId;
  final String? groupId;
  final Map<String, EffectiveParam> params;
  final List<String> problems;

  static const _tagModeKey = 'tag_mode';
  static const _tagPerPiece = 'per_unit';

  /// Whether the effective tag mode (the item's own, its group's, the business's) is one tag per piece.
  bool get tagsEachPiece => params[_tagModeKey]?.value == _tagPerPiece;

  factory ItemEffective.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'item_effective_settings');
    final raw = (json! as Map)['parameters'];
    final params = <String, EffectiveParam>{};
    if (raw is Map) {
      for (final k in raw.keys) {
        final p = JsonReader.of(raw[k], context: 'item_effective_settings.parameters');
        final since = p.stringOrNull('since');
        params['$k'] = EffectiveParam(
          value: (raw[k] as Map)['value'],
          source: p.stringOr('source', 'none'),
          group: p.stringOrNull('group'),
          since: since == null ? null : DateTime.tryParse(since),
        );
      }
    }
    return ItemEffective(
      itemId: r.string('item_id'),
      groupId: r.stringOrNull('group_id'),
      params: params,
      problems: [for (final p in ((json as Map)['problems'] as List? ?? const [])) '$p'],
    );
  }
}

/// The answer to moving an item into or out of a group (or its preview).
class GroupAssigned {
  const GroupAssigned({required this.applied, required this.affected, required this.skipped, required this.unchanged});

  final bool applied;
  final int affected;
  final List<SkippedItem> skipped;
  final bool unchanged;

  factory GroupAssigned.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'item_group_assign');
    final skipped = ((json! as Map)['skipped'] as List? ?? const []).map((s) {
      final x = JsonReader.of(s, context: 'item_group_assign.skipped');
      return SkippedItem(itemId: x.stringOr('item_id'), parameter: x.string('parameter'), reason: x.string('reason'));
    }).toList();
    return GroupAssigned(
      applied: r.boolOr('applied', fallback: false),
      affected: r.intOrNull('affected') ?? 0,
      skipped: skipped,
      unchanged: r.boolOr('unchanged', fallback: false),
    );
  }
}

/// One line of the history of a group or an item.
class GroupHistoryRow {
  const GroupHistoryRow({required this.at, required this.parameter, required this.oldValue, required this.newValue, required this.affected, required this.keptOwn, required this.skipped, this.groupId, this.itemId});

  final DateTime at;
  final String? groupId;
  final String? itemId;
  final String parameter;
  final Object? oldValue;
  final Object? newValue;
  final int affected;
  final int keptOwn;
  final int skipped;

  factory GroupHistoryRow.fromJson(Object? json) {
    final r = JsonReader.of(json, context: 'item_group_history');
    return GroupHistoryRow(
      at: DateTime.parse(r.string('at')),
      groupId: r.stringOrNull('group_id'),
      itemId: r.stringOrNull('item_id'),
      parameter: r.string('parameter'),
      oldValue: (json! as Map)['old'],
      newValue: (json as Map)['new'],
      affected: r.intOrNull('affected') ?? 0,
      keptOwn: r.intOrNull('kept_own') ?? 0,
      skipped: r.intOrNull('skipped') ?? 0,
    );
  }
}

/// An item's own value of one setting, or its way back to the group's: the item and the revision read, the
/// parameter, `mode` (`set` with [value], or `inherit`).
typedef ItemOverride = ({String itemId, int expectedRevision, String parameter, String mode, Object? value});

/// A group as it is saved: its name, the group above it (null: a top group) and the parameters it changes. A
/// parameter is the group's own open set (the same keys as [ItemGroup.params]); a null value takes it back, and a key
/// left out is left as it is (what an item costs or sells for is left out for someone who may not see it).
class ItemGroupDraft {
  const ItemGroupDraft({required this.name, required this.parentId, required this.parameters});

  final String name;
  final String? parentId;
  final Map<String, Object?> parameters;

  Map<String, Object?> toJson() => {'name': name, 'parent_id': parentId, 'parameters': parameters};
}

/// The item groups of a business.
abstract interface class ItemGroups {
  Future<List<ItemGroup>> groups(String workspaceId);

  /// Creates ([expectedRevision] 0, [groupId] new) or changes a group; with [apply] false only says what it would do.
  Future<GroupSaved> save(String workspaceId, {required String requestId, required String groupId, required int expectedRevision, required ItemGroupDraft body, bool apply = true});

  Future<GroupAssigned> assign(String workspaceId, {required String requestId, required String itemId, required int expectedRevision, required String? groupId, bool apply = true});

  /// `mode` is `set` (with [value]) or `inherit` (back to the group's value).
  Future<void> setOverride(String workspaceId, String requestId, ItemOverride change);

  Future<void> delete(String workspaceId, {required String requestId, required String groupId, required int expectedRevision});

  Future<ItemEffective> effective(String workspaceId, String itemId);

  Future<List<GroupHistoryRow>> history(String workspaceId, {String? groupId, String? itemId, int limit = 50});
}

/// The roundings a group may propose for a price, as the server accepts them.
const itemGroupRoundings = ['none', '0.05', '0.10', '0.99'];

/// [percent] (a decimal text, at most two decimals) as basis points, or null when it is not one: `35` is 3500, `12.5` 1250.
int? marginBpsOfPercent(String percent) {
  final m = RegExp(r'^([0-9]{1,4})(?:\.([0-9]{1,2}))?$').firstMatch(percent.trim());
  if (m == null) return null;
  final bps = int.parse(m[1]!) * 100 + int.parse((m[2] ?? '').padRight(2, '0'));
  return bps > 100000 ? null : bps;
}

/// Basis points as a percent text: 3500 is `35`, 1250 is `12.5`.
String percentOfMarginBps(int bps) {
  final whole = bps ~/ 100;
  final frac = bps % 100;
  if (frac == 0) return '$whole';
  return '$whole.${frac.toString().padLeft(2, '0').replaceFirst(RegExp(r'0$'), '')}';
}
