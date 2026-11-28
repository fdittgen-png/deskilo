// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- an item and its group: which group it is in, and for each setting a group can carry where the
// value in force comes from ("From Drinks since 3 Dec", or "Own value" with a way back to the group's). Moving the
// item into or out of a group first PREVIEWS how many settings that changes, and a second tap makes the move; the
// move carries the item's revision and its own request id. Giving a setting back to the group changes only that
// item. What the dialog shows is one immutable view held in a notifier, replaced as things happen.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/help/help_anchors.dart';
import '../../../core/help/help_dot.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../core/ui/loading_view.dart';
import '../../../l10n/app_localizations.dart';
import '../application/stock_reads.dart';
import '../domain/item_groups.dart';
import '../providers/stock_providers.dart';
import '../providers/workspace_units_providers.dart';
import 'item_group_text.dart';
import 'item_group_unit_rows.dart';
import 'stock_config_text.dart';

/// Opens the group and inherited settings of the item [itemId].
Future<void> showItemGroupAssign(BuildContext context, {required String workspaceId, required String itemId, required String itemName}) =>
    showDialog<void>(
      context: context,
      builder: (_) => _AssignDialog(workspaceId: workspaceId, itemId: itemId, itemName: itemName),
    );

typedef _Loaded = ({List<ItemGroup> groups, ItemEffective effective, int revision});

/// What the dialog shows now: what was read, the group chosen (not yet made), the move being previewed and what
/// it reaches, and a line to say.
class _View {
  const _View({required this.read, this.target, this.chosen = false, this.previewOf, this.reaches, this.problem});

  final Future<_Loaded> read;
  final String? target;
  final bool chosen;
  final String? previewOf;
  final int? reaches;
  final String? problem;

  _View said(String? text) => _View(read: read, target: target, chosen: chosen, previewOf: previewOf, reaches: reaches, problem: text);

  _View choosing(String? group) => _View(read: read, target: group, chosen: true);

  _View previewing(String? key, int? count) => _View(read: read, target: target, chosen: chosen, previewOf: key, reaches: count);
}

class _AssignDialog extends ConsumerStatefulWidget {
  const _AssignDialog({required this.workspaceId, required this.itemId, required this.itemName});

  final String workspaceId;
  final String itemId;
  final String itemName;

  @override
  ConsumerState<_AssignDialog> createState() => _AssignDialogState();
}

class _AssignDialogState extends ConsumerState<_AssignDialog> {
  late final ValueNotifier<_View> _view = ValueNotifier(_View(read: _load()));

  @override
  void dispose() {
    _view.dispose();
    super.dispose();
  }

  Future<_Loaded> _load() =>
      StockReads(ref.read(stockConfigCommandsProvider), groups: ref.read(itemGroupsProvider)).groupOf(widget.workspaceId, widget.itemId);

  void _reload({String? say}) {
    if (mounted) _view.value = _View(read: _load(), problem: say);
  }

  Future<void> _move(int revision, String? current) async {
    final l10n = context.l10n;
    final port = ref.read(itemGroupsProvider);
    final now = _view.value;
    final target = now.chosen ? now.target : current;
    final key = target ?? '';
    final problem = await guardSave(
      domain: 'stock',
      message: 'an item was not moved to a group',
      action: () async {
        if (now.previewOf != key) {
          final preview = await port.assign(widget.workspaceId, requestId: newRequestId(), itemId: widget.itemId, expectedRevision: revision, groupId: target, apply: false);
          if (mounted) _view.value = _view.value.said(null).previewing(preview.unchanged ? null : key, preview.unchanged ? null : preview.affected);
          return;
        }
        await port.assign(widget.workspaceId, requestId: newRequestId(), itemId: widget.itemId, expectedRevision: revision, groupId: target);
        if (!mounted) return;
        ref.invalidate(itemGroupListProvider(widget.workspaceId));
        _reload(say: l10n.itemGroupMoved);
      },
      problem: (e) => stockProblemText(l10n, e, subject: StockSubject.group),
    );
    if (problem != null && mounted) _view.value = _view.value.said(problem);
  }

  /// Gives the item its own value for [parameter], whatever its group says; the server refuses what cannot hold (a tag
  /// per piece needs tracking by piece) and the refusal is said here.
  Future<void> _setOwn(int revision, String parameter, Object value) async {
    final l10n = context.l10n;
    final problem = await guardSave(
      domain: 'stock',
      message: 'an item was not given its own value',
      action: () async {
        await ref.read(itemGroupsProvider).setOverride(widget.workspaceId, newRequestId(), (itemId: widget.itemId, expectedRevision: revision, parameter: parameter, mode: 'set', value: value));
        _reload();
      },
      problem: (e) => stockProblemText(l10n, e, subject: StockSubject.group),
    );
    // the field shows the value in force: read it again, so a refused choice does not stay on the screen
    if (problem != null && mounted) _reload(say: problem);
  }

  /// #4479 -- gives the item its own unit: each parameter of the block that was filled is set, one after the other, each at the
  /// revision the one before left.
  Future<void> _setOwnUnit(ItemUnitBlock block, ItemEffective effective, _Loaded data) async {
    final l10n = context.l10n;
    final units = await ref.read(workspaceUnitListProvider(widget.workspaceId).future);
    if (!mounted) return;
    final form = ownUnitForm(block: block, effective: effective, format: appFormatOf(context), workspaceId: widget.workspaceId, units: units);
    final saved = await showAppFormSheet(
      context,
      AppFormSheet(
        title: block == ItemUnitBlock.sale ? l10n.itemGroupSaleUnit : l10n.itemGroupPurchaseUnit,
        submitLabel: l10n.itemGroupSetOwn,
        submitKey: const ValueKey('item-group-unit-own-save'),
        validate: () => form.fields.errors(l10n),
        onSubmit: () => _sendUnits({for (final e in form.values().entries) if (e.value != null) e.key: e.value!}, 'set'),
        builder: (context, refresh) => form.widgets(l10n, (f) {
          f();
          refresh();
        }, () {}),
      ),
    );
    if (saved && mounted) _reload();
  }

  Future<void> _useGroupUnits(ItemUnitBlock block, ItemEffective effective) async {
    final problem = await _sendUnits({for (final p in block.parameters) if (effective.params[p]?.own ?? false) p: ''}, 'inherit');
    if (!mounted) return;
    problem == null ? _reload() : _view.value = _view.value.said(problem);
  }

  /// One override call per parameter, each at the revision the last one left (a save raises it by one); null when all were made.
  Future<String?> _sendUnits(Map<String, Object> values, String mode) async {
    final l10n = context.l10n;
    final port = ref.read(itemGroupsProvider);
    return guardSave(
      domain: 'stock',
      message: 'an item unit was not saved against its group',
      action: () async {
        for (final e in values.entries) {
          final revision = (await _load()).revision;
          await port.setOverride(widget.workspaceId, newRequestId(), (itemId: widget.itemId, expectedRevision: revision, parameter: e.key, mode: mode, value: mode == 'set' ? e.value : null));
        }
      },
      problem: (e) => stockProblemText(l10n, e, subject: StockSubject.group),
    );
  }

  Future<void> _useGroup(int revision, String parameter) async {
    final l10n = context.l10n;
    final problem = await guardSave(
      domain: 'stock',
      message: 'an item was not given back to its group',
      action: () async {
        await ref.read(itemGroupsProvider).setOverride(widget.workspaceId, newRequestId(), (itemId: widget.itemId, expectedRevision: revision, parameter: parameter, mode: 'inherit', value: null));
        _reload();
      },
      problem: (e) => stockProblemText(l10n, e, subject: StockSubject.group),
    );
    if (problem != null && mounted) _view.value = _view.value.said(problem);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      key: const ValueKey('item-group-assign'),
      title: Text(l10n.itemGroupAssignTitle(widget.itemName)),
      content: SizedBox(
        width: 460,
        child: ValueListenableBuilder<_View>(
          valueListenable: _view,
          builder: (context, view, _) => FutureBuilder<_Loaded>(
            future: view.read,
            builder: (context, snapshot) {
              if (snapshot.hasError) return Text(l10n.itemGroupFailed, key: const ValueKey('item-group-assign-failed'));
              final data = snapshot.data;
              if (data == null) return const LoadingView();
              return SingleChildScrollView(child: _body(context, l10n, view, data));
            },
          ),
        ),
      ),
      actions: [TextButton(key: const ValueKey('item-group-assign-close'), onPressed: () => Navigator.of(context).pop(), child: Text(l10n.itemGroupClose))],
    );
  }

  Widget _body(BuildContext context, AppLocalizations l10n, _View view, _Loaded data) {
    final current = data.effective.groupId;
    final shown = view.chosen ? view.target : current;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppDropdownField<String?>(
          key: ValueKey('item-group-assign-field-$shown'),
          label: l10n.taxRefGroup,
          value: shown,
          items: [(null, l10n.itemGroupAssignNone), for (final g in data.groups) (g.id, g.name)],
          onChanged: (v) => _view.value = view.choosing(v),
        ),
        const SizedBox(height: AppSpacing.xs),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton(key: const ValueKey('item-group-move'), onPressed: () => _move(data.revision, current), child: Text(l10n.itemGroupMove)),
        ),
        if (view.reaches != null) Text(l10n.itemGroupMoveReaches(view.reaches!), key: const ValueKey('item-group-move-reaches')),
        const Divider(),
        for (final p in itemGroupEditable)
          if (data.effective.params[p] != null) _param(context, l10n, p, data.effective.params[p]!, canGiveBack: current != null, revision: data.revision),
        // #4479 -- the units follow the group live: from it, or the item's own
        if (current != null)
          for (final block in ItemUnitBlock.values)
            ItemGroupUnitRow(
              block: block,
              effective: data.effective,
              onSetOwn: () => unawaited(_setOwnUnit(block, data.effective, data)),
              onUseGroup: () => unawaited(_useGroupUnits(block, data.effective)),
            ),
        if (view.problem != null) Text(view.problem!, key: const ValueKey('item-group-assign-problem')),
      ],
    );
  }

  Widget _param(BuildContext context, AppLocalizations l10n, String p, EffectiveParam param, {required bool canGiveBack, required int revision}) => Padding(
    key: ValueKey('item-group-param-$p'),
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.labelWithValue(itemGroupParamLabel(l10n, p), itemGroupValueText(l10n, p, param.value))),
        Text(_source(context, l10n, param), key: ValueKey('item-group-source-$p'), style: Theme.of(context).textTheme.bodySmall),
        if (p == 'tag_mode')
          Row(
            children: [
              Expanded(
                child: AppDropdownField<String?>(
                  key: const ValueKey('item-group-tag-mode'),
                  label: l10n.itemGroupTagModeOwn,
                  value: param.value as String?,
                  items: [for (final m in const ['none', 'per_batch', 'per_unit']) (m, itemGroupValueText(l10n, 'tag_mode', m))],
                  onChanged: (v) {
                    if (v != null && v != param.value) unawaited(_setOwn(revision, p, v));
                  },
                ),
              ),
              HelpDot(l10n.itemGroupTagModeOwn, anchor: HelpAnchor.moneyStockRfid),
            ],
          ),
        if (param.own && canGiveBack)
          TextButton(key: ValueKey('item-group-use-$p'), onPressed: () => _useGroup(revision, p), child: Text(l10n.itemGroupUseGroup)),
      ],
    ),
  );

  String _source(BuildContext context, AppLocalizations l10n, EffectiveParam p) {
    if (p.own) return l10n.itemGroupOwn;
    final group = p.group;
    if (group == null) return '';
    final since = p.since;
    return since == null ? l10n.itemGroupFrom(group) : l10n.itemGroupFromSince(group, appFormatOf(context).date(since));
  }
}
