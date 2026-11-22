// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- an item and its group: which group it is in, and for each setting a group can carry where the
// value in force comes from ("From Drinks since 3 Dec", or "Own value" with a way back to the group's). Moving the
// item into or out of a group first PREVIEWS how many settings that changes, and a second tap makes the move; the
// move carries the item's revision and its own request id. Giving a setting back to the group changes only that
// item.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/item_groups.dart';
import '../providers/stock_providers.dart';
import 'item_group_text.dart';

/// Opens the group and inherited settings of the item [itemId].
Future<void> showItemGroupAssign(BuildContext context, {required String workspaceId, required String itemId, required String itemName}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _AssignDialog(workspaceId: workspaceId, itemId: itemId, itemName: itemName),
    );

class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.workspaceId, required this.itemId, required this.itemName});

  final String workspaceId;
  final String itemId;
  final String itemName;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  late Future<({List<ItemGroup> groups, ItemEffective effective, int revision})> _read = _load();
  String? _target;
  bool _targetChosen = false;
  String? _previewOf;
  int? _reaches;
  String? _problem;

  Future<({List<ItemGroup> groups, ItemEffective effective, int revision})> _load() async {
    final port = ref.read(itemGroupsProvider);
    final groups = await port.groups(widget.workspaceId);
    final effective = await port.effective(widget.workspaceId, widget.itemId);
    final config = await ref.read(stockConfigCommandsProvider).item(widget.workspaceId, widget.itemId);
    return (groups: groups, effective: effective, revision: config?.revision ?? 0);
  }

  void _reload() => setState(() {
    _read = _load();
    _previewOf = null;
    _reaches = null;
    _targetChosen = false;
  });

  Future<void> _move(int revision, String? current) async {
    final l10n = context.l10n;
    final port = ref.read(itemGroupsProvider);
    final target = _targetChosen ? _target : current;
    final key = target ?? '';
    try {
      if (_previewOf != key) {
        final preview = await port.assign(widget.workspaceId, requestId: newRequestId(), itemId: widget.itemId, expectedRevision: revision, groupId: target, apply: false);
        if (!mounted) return;
        setState(() {
          _problem = null;
          if (preview.unchanged) {
            _previewOf = null;
            _reaches = null;
          } else {
            _previewOf = key;
            _reaches = preview.affected;
          }
        });
        return;
      }
      await port.assign(widget.workspaceId, requestId: newRequestId(), itemId: widget.itemId, expectedRevision: revision, groupId: target);
      if (!mounted) return;
      ref.invalidate(itemGroupListProvider(widget.workspaceId));
      setState(() => _problem = l10n.itemGroupMoved);
      _reload();
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'an item was not moved to a group: $e', stackTrace: st);
      if (mounted) setState(() => _problem = itemGroupProblem(l10n, e));
    }
  }

  Future<void> _useGroup(int revision, String parameter) async {
    final l10n = context.l10n;
    try {
      await ref.read(itemGroupsProvider).setOverride(widget.workspaceId, requestId: newRequestId(), itemId: widget.itemId, expectedRevision: revision, parameter: parameter, mode: 'inherit');
      if (mounted) _reload();
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'an item was not given back to its group: $e', stackTrace: st);
      if (mounted) setState(() => _problem = itemGroupProblem(l10n, e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const ValueKey('item-group-assign'),
      title: Text(l10n.itemGroupAssignTitle(widget.itemName)),
      content: SizedBox(
        width: 460,
        child: FutureBuilder<({List<ItemGroup> groups, ItemEffective effective, int revision})>(
          future: _read,
          builder: (context, snapshot) {
            if (snapshot.hasError) return Text(l10n.itemGroupFailed, key: const ValueKey('item-group-assign-failed'));
            final data = snapshot.data;
            if (data == null) return const SizedBox(height: 60, child: Center(child: CircularProgressIndicator()));
            final current = data.effective.groupId;
            return SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppDropdownField<String?>(
                    key: ValueKey('item-group-assign-field-${_targetChosen ? _target : current}'),
                    label: l10n.itemGroupAssignField,
                    value: _targetChosen ? _target : current,
                    items: [(null, l10n.itemGroupAssignNone), for (final g in data.groups) (g.id, g.name)],
                    onChanged: (v) => setState(() {
                      _target = v;
                      _targetChosen = true;
                      _previewOf = null;
                      _reaches = null;
                    }),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      key: const ValueKey('item-group-move'),
                      onPressed: () => _move(data.revision, current),
                      child: Text(l10n.itemGroupMove),
                    ),
                  ),
                  if (_reaches != null) Text(l10n.itemGroupMoveReaches(_reaches!), key: const ValueKey('item-group-move-reaches')),
                  const Divider(),
                  for (final p in itemGroupEditable)
                    if (data.effective.params[p] != null)
                      Padding(
                        key: ValueKey('item-group-param-$p'),
                        padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${itemGroupParamLabel(l10n, p)}: ${itemGroupValueText(l10n, p, data.effective.params[p]!.value)}'),
                            Text(_source(l10n, data.effective.params[p]!), style: Theme.of(context).textTheme.bodySmall),
                            if (data.effective.params[p]!.own && current != null)
                              TextButton(
                                key: ValueKey('item-group-use-$p'),
                                onPressed: () => _useGroup(data.revision, p),
                                child: Text(l10n.itemGroupUseGroup),
                              ),
                          ],
                        ),
                      ),
                  if (_problem != null) Text(_problem!, key: const ValueKey('item-group-assign-problem')),
                ],
              ),
            );
          },
        ),
      ),
      actions: [TextButton(key: const ValueKey('item-group-assign-close'), onPressed: () => Navigator.of(context).pop(), child: Text(l10n.itemGroupClose))],
    );
  }

  String _source(AppLocalizations l10n, EffectiveParam p) {
    if (p.own) return l10n.itemGroupOwn;
    final group = p.group;
    if (group == null) return '';
    final since = p.since;
    return since == null
        ? l10n.itemGroupFrom(group)
        : l10n.itemGroupFromSince(group, MaterialLocalizations.of(context).formatMediumDate(since.toLocal()));
  }
}
