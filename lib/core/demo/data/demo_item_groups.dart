// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- the Demo's item groups, in memory behind the same port as the server's, with the server's rules:
// a group holds parameters, an item inherits each one unless it keeps its own, a change shows (preview) what it
// reaches, what keeps its own value and what it cannot reach, and a group in use is not deleted. The shop's drinks
// group (shelf life 180 days, counted every 14 days) holds the milk and the syrup (which keeps its own shelf life)
// and a sub-group for hot drinks holds the beans; the mugs are in a group of homeware. The same request id answers
// once, as the server's does.
import '../../../features/stock/domain/item_groups.dart';
import '../../../features/stock/domain/stock_config.dart';
import '../../../features/stock/domain/stock_config_commands.dart';

class _Group {
  _Group(this.id, this.parentId, this.name, this.params);

  final String id;
  String? parentId;
  String name;
  int revision = 1;
  final Map<String, Object?> params;

  void setParams(Map<String, Object?> next) => params
    ..clear()
    ..addAll(next);
}

class DemoItemGroups implements ItemGroups {
  DemoItemGroups(this._workspaceId, this._config, this._now) {
    _groups['demo-group-drinks'] = _Group('demo-group-drinks', null, 'Drinks', {'tracking': 'lot', 'shelf_life_days': 180, 'count_every_days': 14});
    _groups['demo-group-hot'] = _Group('demo-group-hot', 'demo-group-drinks', 'Hot drinks', {'shelf_life_days': 365});
    _groups['demo-group-home'] = _Group('demo-group-home', null, 'Homeware', {'tracking': 'none'});
    _member.addAll({'demo-item-milk': 'demo-group-drinks', 'demo-item-syrup': 'demo-group-drinks', 'demo-item-beans': 'demo-group-hot', 'demo-item-mugs': 'demo-group-home'});
    _own['demo-item-syrup'] = {'shelf_life_days': 365};
  }

  final String _workspaceId;
  final StockConfigCommands _config;
  final DateTime Function() _now;

  final Map<String, _Group> _groups = {};
  final Map<String, String> _member = {};
  final Map<String, Map<String, Object?>> _own = {};
  final List<GroupHistoryRow> _history = [];
  final Map<String, Object> _answers = {};

  static const _params = itemGroupEditable;

  List<_Group> _childrenOf(String id) => [for (final g in _groups.values) if (g.parentId == id) g];

  /// The items of [group] and of its sub-groups.
  List<String> _itemsOf(String group) {
    final ids = {group, ..._childrenOf(group).map((g) => g.id)};
    return [for (final e in _member.entries) if (ids.contains(e.value)) e.key];
  }

  ({Object? value, String source, String? group}) _pick(String item, String param) {
    final own = _own[item];
    if (own != null && own.containsKey(param)) return (value: own[param], source: 'item', group: null);
    final gid = _member[item];
    final g = gid == null ? null : _groups[gid];
    final parent = g?.parentId == null ? null : _groups[g!.parentId];
    final inGroup = g?.params[param];
    if (inGroup != null) return (value: inGroup, source: parent == null ? 'group' : 'subgroup', group: g!.name);
    final inParent = parent?.params[param];
    if (inParent != null) return (value: inParent, source: 'group', group: parent!.name);
    return (value: null, source: 'none', group: null);
  }

  @override
  Future<List<ItemGroup>> groups(String workspaceId) async => workspaceId != _workspaceId
      ? const []
      : [
          for (final g in _groups.values.toList()..sort((a, b) => (a.parentId ?? a.id).compareTo(b.parentId ?? b.id) != 0 ? (a.parentId ?? a.id).compareTo(b.parentId ?? b.id) : (a.parentId == null ? -1 : 1)))
            ItemGroup(id: g.id, parentId: g.parentId, name: g.name, revision: g.revision, params: Map.of(g.params), items: _member.values.where((v) => v == g.id).length),
        ];

  @override
  Future<GroupSaved> save(String workspaceId, {required String requestId, required String groupId, required int expectedRevision, required Map<String, Object?> body, bool apply = true}) async {
    final replay = apply ? _answers[requestId] : null;
    if (replay is GroupSaved) return replay;
    final old = _groups[groupId];
    final creating = old == null;
    if (creating && expectedRevision != 0) throw const StockConfigRefused('group_id', 'group_unknown');
    if (!creating && old.revision != expectedRevision) throw const StockConfigStale();
    final name = (body['name'] as String?)?.trim() ?? old?.name;
    if (name == null || name.isEmpty) throw const StockConfigRefused('name', 'required');
    if (_groups.values.any((g) => g.id != groupId && g.name.toLowerCase() == name.toLowerCase())) throw const StockConfigRefused('name', 'name_duplicate');
    final parentId = body.containsKey('parent_id') ? body['parent_id'] as String? : old?.parentId;
    if (parentId != null) {
      final parent = _groups[parentId];
      if (parent == null) throw const StockConfigRefused('parent_id', 'group_unknown');
      if (parent.parentId != null || _childrenOf(groupId).isNotEmpty) throw const StockConfigRefused('parent_id', 'depth');
    }
    final changes = Map<String, Object?>.from((body['parameters'] as Map?) ?? const {});
    final next = {...?old?.params};
    for (final e in changes.entries) {
      if (e.value == null) {
        next.remove(e.key);
      } else {
        next[e.key] = e.value;
      }
    }
    if (next['tag_mode'] == 'per_unit' && (next['tracking'] ?? _groups[parentId]?.params['tracking']) != 'serial') {
      throw const StockConfigRefused('tag_mode', 'needs_serial');
    }
    final impact = <String, GroupImpact>{};
    final skipped = <SkippedItem>[];
    final reached = creating ? const <String>[] : _itemsOf(groupId);
    // what each item reads of each changed setting, with the group as it is and as it would be (an item whose
    // group or sub-group already says otherwise is not reached)
    final before = {for (final item in reached) item: {for (final k in changes.keys) k: _pick(item, k).value}};
    final saved = old == null ? null : Map<String, Object?>.of(old.params);
    old?.setParams(next);
    final after = {for (final item in reached) item: {for (final k in changes.keys) k: _pick(item, k).value}};
    if (saved != null) old?.setParams(saved);
    for (final k in changes.keys) {
      var affected = 0;
      var kept = 0;
      var skip = 0;
      for (final item in reached) {
        final own = _own[item]?.containsKey(k) ?? false;
        if (before[item]![k] == after[item]![k] && !own) continue;
        if (own) {
          if (before[item]![k] != after[item]![k] || old?.params[k] != changes[k]) kept++;
        } else if (k == 'inventory_unit' && after[item]![k] != null) {
          skip++;
          skipped.add(SkippedItem(itemId: item, parameter: k, reason: 'has_movements'));
        } else {
          affected++;
        }
      }
      if (old?.params[k] == changes[k] && affected == 0 && kept == 0 && skip == 0) continue;
      impact[k] = GroupImpact(affected: affected, keptOwn: kept, skipped: skip);
    }
    final revision = (old?.revision ?? 0) + 1;
    final result = GroupSaved(groupId: groupId, revision: revision, created: creating, applied: apply, items: reached.length, impact: impact, skipped: skipped);
    if (!apply) return result;
    (old ?? (_groups[groupId] = _Group(groupId, parentId, name, {})))
      ..name = name
      ..parentId = parentId
      ..revision = revision
      ..setParams(next);
    for (final e in impact.entries) {
      _history.insert(0, GroupHistoryRow(at: _now(), groupId: groupId, parameter: e.key, oldValue: old?.params[e.key], newValue: changes[e.key], affected: e.value.affected, keptOwn: e.value.keptOwn, skipped: e.value.skipped));
    }
    return _answers[requestId] = result;
  }

  @override
  Future<GroupAssigned> assign(String workspaceId, {required String requestId, required String itemId, required int expectedRevision, required String? groupId, bool apply = true}) async {
    final revision = (await _config.item(workspaceId, itemId))?.revision;
    if (revision == null) throw const StockConfigRefused('item_id', 'not_an_item');
    if (revision != expectedRevision) throw const StockConfigStale();
    if (groupId != null && !_groups.containsKey(groupId)) throw const StockConfigRefused('group_id', 'group_unknown');
    if (_member[itemId] == groupId) return const GroupAssigned(applied: false, affected: 0, skipped: [], unchanged: true);
    final before = {for (final p in _params) p: _pick(itemId, p).value};
    final saved = _member[itemId];
    groupId == null ? _member.remove(itemId) : _member[itemId] = groupId;
    final affected = _params.where((p) => before[p] != _pick(itemId, p).value).length;
    // a preview looks at the new membership without making it
    if (!apply) saved == null ? _member.remove(itemId) : _member[itemId] = saved;
    return GroupAssigned(applied: apply, affected: affected, skipped: const [], unchanged: false);
  }

  @override
  Future<void> setOverride(String workspaceId, {required String requestId, required String itemId, required int expectedRevision, required String parameter, required String mode, Object? value}) async {
    if (!_params.contains(parameter)) throw StockConfigRefused(parameter, 'not_overridable');
    final revision = (await _config.item(workspaceId, itemId))?.revision;
    if (revision != expectedRevision) throw const StockConfigStale();
    final before = _pick(itemId, parameter).value;
    if (mode == 'set') {
      if (value == null) throw StockConfigRefused(parameter, 'value_required');
      (_own[itemId] ??= {})[parameter] = value;
    } else {
      _own[itemId]?.remove(parameter);
    }
    _history.insert(0, GroupHistoryRow(at: _now(), itemId: itemId, parameter: parameter, oldValue: before, newValue: _pick(itemId, parameter).value, affected: 1, keptOwn: 0, skipped: 0));
  }

  @override
  Future<void> delete(String workspaceId, {required String requestId, required String groupId, required int expectedRevision}) async {
    final g = _groups[groupId];
    if (g == null) throw const StockConfigRefused('group_id', 'group_unknown');
    if (g.revision != expectedRevision) throw const StockConfigStale();
    if (_childrenOf(groupId).isNotEmpty) throw const StockConfigRefused('group_id', 'has_subgroups');
    if (_member.containsValue(groupId)) throw const StockConfigRefused('group_id', 'in_use');
    _groups.remove(groupId);
  }

  @override
  Future<ItemEffective> effective(String workspaceId, String itemId) async {
    final config = await _config.item(workspaceId, itemId);
    if (config == null) throw const StockConfigRefused('item_id', 'not_an_item');
    final own = {'tracking': config.tracking, 'shelf_life_days': config.shelfLifeDays, 'inventory_unit': config.inventoryUnit};
    final out = <String, EffectiveParam>{};
    for (final p in _params) {
      final picked = _pick(itemId, p);
      final since = picked.source == 'none' ? null : _history.where((h) => (picked.source == 'item' ? h.itemId == itemId : h.groupId == _member[itemId]) && h.parameter == p).map((h) => h.at).firstOrNull;
      out[p] = EffectiveParam(value: picked.source == 'none' ? own[p] : picked.value, source: picked.source, group: picked.group, since: since);
    }
    return ItemEffective(itemId: itemId, groupId: _member[itemId], params: out, problems: const []);
  }

  @override
  Future<List<GroupHistoryRow>> history(String workspaceId, {String? groupId, String? itemId, int limit = 50}) async => [
    for (final h in _history)
      if ((groupId == null || h.groupId == groupId) && (itemId == null || h.itemId == itemId)) h,
  ].take(limit).toList();
}
