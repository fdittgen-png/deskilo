// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4361 (G12) -- one item group in a sheet: its name, where it sits (a group nests one level), the shared settings
// it carries and, for a group that exists, what changed it. Saving first PREVIEWS: the sheet says which settings
// reach how many items, which keep their own value and which cannot be reached, and a second save applies it
// (editing anything in between asks for a new preview). The group's id is made once per sheet and the save carries
// one request id and the revision it read, so a retry after a lost answer answers once and a group that moved
// meanwhile is refused. A group nothing uses can be deleted here.
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/dropdown_field.dart';
import '../../../core/ui/form_kit.dart';
import '../../../l10n/app_localizations.dart';
import '../domain/item_groups.dart';
import 'item_group_text.dart';

/// The units a group may set for its items (the registry's units of count, mass and volume).
const itemGroupUnits = ['piece', 'g', 'kg', 'ml', 'cl', 'l'];

/// Opens the sheet of [group] (null: a new group); true when something was saved or deleted.
Future<bool> showItemGroupSheet(
  BuildContext context,
  ItemGroups port, {
  required String workspaceId,
  required ItemGroup? group,
  required List<ItemGroup> groups,
}) {
  final l10n = context.l10n;
  final draft = _GroupDraft(port, workspaceId, group, groups);
  return showAppFormSheet(
    context,
    AppFormSheet(
      title: group == null ? l10n.itemGroupNewTitle : l10n.itemGroupEditTitle,
      submitLabel: l10n.stockEditSave,
      submitKey: const ValueKey('item-group-save'),
      onDispose: draft.fields.dispose,
      validate: () => draft.validate(l10n),
      onSubmit: () => draft.submit(l10n),
      builder: draft.build,
    ),
  );
}

class _GroupDraft {
  _GroupDraft(this.port, this.workspaceId, this.group, this.groups)
    : _id = group?.id ?? newRequestId(),
      parentId = group?.parentId,
      tracking = group?.params['tracking'] as String?,
      tagMode = group?.params['tag_mode'] as String?,
      unit = group?.params['inventory_unit'] as String?,
      sold = group?.params['sold_by_weight'] as bool?,
      fields = FormControllers({
        'name': group?.name ?? '',
        'shelf': '${group?.params['shelf_life_days'] ?? ''}',
        'count': '${group?.params['count_every_days'] ?? ''}',
        'age': '${group?.params['min_age'] ?? ''}',
      });

  final ItemGroups port;
  final String workspaceId;
  final ItemGroup? group;
  final List<ItemGroup> groups;
  final FormControllers fields;
  final String _id;

  /// One per sheet: a retry of the same save answers once.
  final String requestId = newRequestId();
  String? parentId;
  String? tracking;
  String? tagMode;
  String? unit;
  bool? sold;

  GroupSaved? _preview;
  String? _previewOf;

  int? _int(String key) => int.tryParse(fields.text(key));

  Map<String, Object?> body() => {
    'name': fields.text('name'),
    'parent_id': parentId,
    'parameters': {
      'tracking': tracking,
      'shelf_life_days': _int('shelf'),
      'tag_mode': tagMode,
      'inventory_unit': unit,
      'count_every_days': _int('count'),
      'min_age': _int('age'),
      'sold_by_weight': sold,
    },
  };

  FieldErrors validate(AppLocalizations l10n) => {
    if (fields.text('name').isEmpty) 'name': l10n.stockReasonNameMalformed,
    for (final (key, field) in [('shelf', 'shelf'), ('count', 'count'), ('age', 'age')])
      if (fields.text(key).isNotEmpty && (_int(key) ?? 0) < 1) field: l10n.stockReasonOutOfRange,
  };

  Future<String?> submit(AppLocalizations l10n) async {
    final now = jsonEncode(body());
    try {
      if (_preview == null || _previewOf != now) {
        final preview = await port.save(workspaceId, requestId: requestId, groupId: _id, expectedRevision: group?.revision ?? 0, body: body(), apply: false);
        _previewOf = now;
        _preview = preview;
        // nothing is reached: there is nothing to confirm
        if (preview.impact.isEmpty && preview.skipped.isEmpty) return await _apply(l10n);
        return l10n.itemGroupConfirm;
      }
      return await _apply(l10n);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'an item group was not saved: $e', stackTrace: st);
      return itemGroupProblem(l10n, e);
    }
  }

  Future<String?> _apply(AppLocalizations l10n) async {
    await port.save(workspaceId, requestId: requestId, groupId: _id, expectedRevision: group?.revision ?? 0, body: body());
    return null;
  }

  List<Widget> build(BuildContext context, VoidCallback refresh) {
    final l10n = context.l10n;
    void edit(void Function() change) {
      change();
      _preview = null;
      refresh();
    }

    final parents = [
      for (final g in groups)
        if (g.parentId == null && g.id != group?.id) g,
    ];
    return [
      AppTextField(key: const ValueKey('item-group-name'), controller: fields['name'], fieldKey: 'name', label: l10n.itemGroupName, onChanged: (_) => _preview = null),
      const FormGap(),
      AppDropdownField<String?>(
        key: const ValueKey('item-group-parent'),
        label: l10n.itemGroupParent,
        value: parentId,
        items: [(null, l10n.itemGroupNoParent), for (final g in parents) (g.id, g.name)],
        onChanged: (v) => edit(() => parentId = v),
      ),
      const FormGap(),
      AppDropdownField<String?>(
        key: const ValueKey('item-group-tracking'),
        label: l10n.stockEditTracking,
        value: tracking,
        items: [(null, l10n.itemGroupNotSet), for (final t in ['none', 'lot', 'expiry', 'serial']) (t, itemGroupValueText(l10n, 'tracking', t))],
        onChanged: (v) => edit(() => tracking = v),
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('item-group-shelf'),
        controller: fields['shelf'],
        fieldKey: 'shelf',
        label: l10n.stockEditShelfLife,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => _preview = null,
      ),
      const FormGap(),
      AppDropdownField<String?>(
        key: const ValueKey('item-group-tag-mode'),
        label: l10n.itemGroupTagMode,
        value: tagMode,
        items: [(null, l10n.itemGroupNotSet), for (final t in ['none', 'per_batch', 'per_unit']) (t, itemGroupValueText(l10n, 'tag_mode', t))],
        onChanged: (v) => edit(() => tagMode = v),
      ),
      const FormGap(),
      AppDropdownField<String?>(
        key: const ValueKey('item-group-unit'),
        label: l10n.stockEditInventoryUnit,
        value: unit,
        items: [(null, l10n.itemGroupNotSet), for (final u in itemGroupUnits) (u, u)],
        onChanged: (v) => edit(() => unit = v),
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('item-group-count'),
        controller: fields['count'],
        fieldKey: 'count',
        label: l10n.itemGroupCountEvery,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => _preview = null,
      ),
      const FormGap(),
      AppTextField(
        key: const ValueKey('item-group-age'),
        controller: fields['age'],
        fieldKey: 'age',
        label: l10n.itemGroupMinAge,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        onChanged: (_) => _preview = null,
      ),
      const FormGap(),
      AppDropdownField<bool?>(
        key: const ValueKey('item-group-weight'),
        label: l10n.itemGroupSoldByWeight,
        value: sold,
        items: [(null, l10n.itemGroupNotSet), (true, l10n.itemGroupYes), (false, l10n.itemGroupNo)],
        onChanged: (v) => edit(() => sold = v),
      ),
      if (_preview != null) _PreviewCard(preview: _preview!),
      if (group != null) ...[
        const FormGap(),
        _HistoryBlock(port: port, workspaceId: workspaceId, groupId: group!.id),
        if (group!.items == 0)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              key: const ValueKey('item-group-delete'),
              onPressed: () => _delete(context),
              child: Text(l10n.itemGroupDelete),
            ),
          ),
      ],
    ];
  }

  Future<void> _delete(BuildContext context) async {
    final l10n = context.l10n;
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await port.delete(workspaceId, requestId: newRequestId(), groupId: group!.id, expectedRevision: group!.revision);
      messenger.showSnackBar(SnackBar(content: Text(l10n.itemGroupDeleted)));
      navigator.pop(true);
    } on Object catch (e, st) {
      TraceLogger.instance.warn('stock', 'an item group was not deleted: $e', stackTrace: st);
      messenger.showSnackBar(SnackBar(content: Text(itemGroupProblem(l10n, e))));
    }
  }
}

/// What the change would reach: a line per changed setting, and the items that cannot be reached.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({required this.preview});

  final GroupSaved preview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      key: const ValueKey('item-group-preview'),
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.itemGroupPreviewTitle, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            if (preview.impact.isEmpty) Text(l10n.itemGroupPreviewNothing),
            for (final e in preview.impact.entries)
              Text(
                l10n.itemGroupPreviewLine(itemGroupParamLabel(l10n, e.key), e.value.affected, e.value.keptOwn, e.value.skipped),
                key: ValueKey('item-group-preview-${e.key}'),
              ),
            if (preview.skipped.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(l10n.itemGroupSkippedTitle, style: Theme.of(context).textTheme.labelLarge),
              for (final s in preview.skipped) Text(l10n.itemGroupSkippedLine(s.itemId, itemGroupParamLabel(l10n, s.parameter), itemGroupReasonText(l10n, s.reason))),
            ],
          ],
        ),
      ),
    );
  }
}

/// The recorded changes of a group, newest first.
class _HistoryBlock extends StatelessWidget {
  const _HistoryBlock({required this.port, required this.workspaceId, required this.groupId});

  final ItemGroups port;
  final String workspaceId;
  final String groupId;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FutureBuilder<List<GroupHistoryRow>>(
      future: port.history(workspaceId, groupId: groupId),
      builder: (context, snapshot) {
        final rows = snapshot.data;
        return Column(
          key: const ValueKey('item-group-history'),
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.itemGroupHistory, style: Theme.of(context).textTheme.titleSmall),
            if (rows != null && rows.isEmpty) Text(l10n.itemGroupHistoryNone),
            for (final r in rows ?? const <GroupHistoryRow>[])
              Text(
                l10n.itemGroupHistoryLine(
                  itemGroupParamLabel(l10n, r.parameter),
                  itemGroupValueText(l10n, r.parameter, r.oldValue),
                  itemGroupValueText(l10n, r.parameter, r.newValue),
                  r.affected,
                ),
              ),
          ],
        );
      },
    );
  }
}
