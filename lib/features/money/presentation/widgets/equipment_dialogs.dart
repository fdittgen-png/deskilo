// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/workspace_asset.dart';
import '../../providers/asset_providers.dart';
import 'premises_lease_dialogs.dart';

/// Registers one of the equipment lines nobody has registered yet.
Future<bool?> showEquipmentRegisterDialog(BuildContext context, String workspaceId) =>
    showDialog<bool>(
      context: context,
      builder: (_) => _RegisterDialog(workspaceId: workspaceId),
    );

/// The reviewer's treatment of one piece of equipment.
Future<bool?> showEquipmentDecideDialog(
  BuildContext context,
  String workspaceId,
  WorkspaceAsset asset,
) => showDialog<bool>(
  context: context,
  builder: (_) => _DecideDialog(workspaceId: workspaceId, asset: asset),
);

class _RegisterDialog extends ConsumerStatefulWidget {
  const _RegisterDialog({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_RegisterDialog> createState() => _RegisterDialogState();
}

class _RegisterDialogState extends ConsumerState<_RegisterDialog> {
  final _name = TextEditingController();
  AssetCandidateLine? _line;
  var _invalid = false;
  var _requestId = newRequestId();
  String? _attempted;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _markInvalid() => setState(() => _invalid = true);

  Future<void> _save() async {
    final line = _line;
    if (line == null) {
      _markInvalid();
      return;
    }
    final entries = '${line.purchaseId}|${line.lineNo}|${_name.text.trim()}';
    if (_attempted != null && _attempted != entries) _requestId = newRequestId();
    _attempted = entries;
    final navigator = Navigator.of(context);
    var accepted = false;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'equipment registration failed',
      errorText: context.l10n.equipmentRegisterRefused,
      action: () async {
        final done = await ref
            .read(assetCommandProvider)
            .register(widget.workspaceId, line, _name.text, _requestId);
        if (done == null) {
          _markInvalid();
        } else {
          accepted = true;
        }
      },
    );
    if (ok && accepted && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final lines = ref.watch(assetCandidateLinesProvider(widget.workspaceId));
    return AlertDialog(
      title: Text(l10n.equipmentRegisterTitle),
      content: SingleChildScrollView(
        child: lines.when(
          loading: () => const LoadingView(),
          error: (_, _) => Text(l10n.equipmentLoadFailed),
          data: (rows) => rows.isEmpty
              ? Text(l10n.equipmentRegisterNone, key: const ValueKey('equipment-none'))
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(l10n.equipmentRegisterHint, style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: AppSpacing.sm),
                    DropdownButtonFormField<AssetCandidateLine>(
                      key: const ValueKey('equipment-line'),
                      initialValue: _line,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: l10n.equipmentFieldLine),
                      items: [
                        for (final r in rows)
                          DropdownMenuItem(
                            value: r,
                            child: Text(
                              '${r.description.isEmpty ? '—' : r.description} · '
                              '${moneyFormat(r.currency).formatMinor(r.grossCents)}'
                              '${r.supplierName.isEmpty ? '' : ' · ${r.supplierName}'}',
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (v) => setState(() {
                        _line = v;
                        if (_name.text.isEmpty && v != null) _name.text = v.description;
                      }),
                    ),
                    AppTextField(
                      key: const ValueKey('equipment-name'),
                      controller: _name,
                      label: l10n.equipmentFieldName,
                      maxLength: 200,
                    ),
                    if (_invalid)
                      Padding(
                        padding: const EdgeInsets.only(top: AppSpacing.sm),
                        child: Text(
                          l10n.equipmentInvalid,
                          key: const ValueKey('equipment-invalid'),
                          style: TextStyle(color: Theme.of(context).colorScheme.error),
                        ),
                      ),
                  ],
                ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('equipment-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('equipment-register-save'),
          onPressed: _save,
          child: Text(l10n.equipmentRegisterSave),
        ),
      ],
    );
  }
}

class _DecideDialog extends ConsumerStatefulWidget {
  const _DecideDialog({required this.workspaceId, required this.asset});

  final String workspaceId;
  final WorkspaceAsset asset;

  @override
  ConsumerState<_DecideDialog> createState() => _DecideDialogState();
}

class _DecideDialogState extends ConsumerState<_DecideDialog> {
  final _basis = TextEditingController();
  final _external = TextEditingController();
  var _decision = AssetDecision.capitalise;
  DateTime? _from;
  var _invalid = false;
  var _requestId = newRequestId();
  String? _attempted;

  @override
  void dispose() {
    _basis.dispose();
    _external.dispose();
    super.dispose();
  }

  void _markInvalid() => setState(() => _invalid = true);

  Future<void> _save() async {
    final command = AssetDecisionCommand(
      assetId: widget.asset.id,
      revision: widget.asset.revision,
      decision: _decision,
      basis: _basis.text.trim(),
      availableForUseOn: _decision == AssetDecision.capitalise ? _from : null,
      externalAssetId: _external.text.trim(),
      requestId: _requestId,
    );
    final entries = '${command.decision.wire}|${command.basis}|${command.availableForUseOn}|${command.externalAssetId}';
    if (_attempted != null && _attempted != entries) _requestId = newRequestId();
    _attempted = entries;
    final sent = AssetDecisionCommand(
      assetId: command.assetId,
      revision: command.revision,
      decision: command.decision,
      basis: command.basis,
      availableForUseOn: command.availableForUseOn,
      externalAssetId: command.externalAssetId,
      requestId: _requestId,
    );
    final navigator = Navigator.of(context);
    var accepted = false;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'equipment decision failed',
      errorText: context.l10n.equipmentDecideRefused,
      action: () async {
        final done = await ref.read(assetCommandProvider).decide(widget.workspaceId, widget.asset, sent);
        if (done == null) {
          _markInvalid();
        } else {
          accepted = true;
        }
      },
    );
    if (ok && accepted && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final now = ref.read(clockProvider).now();
    final unknownCost = widget.asset.acquisitionCostCents == null;
    return AlertDialog(
      title: Text(l10n.equipmentDecideTitle(widget.asset.description)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.equipmentDecideHint, style: Theme.of(context).textTheme.bodySmall),
            if (unknownCost)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.equipmentCostUnknown,
                  key: const ValueKey('equipment-cost-unknown'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            RadioGroup<AssetDecision>(
              key: const ValueKey('equipment-decision'),
              groupValue: _decision,
              onChanged: (v) => setState(() => _decision = v ?? _decision),
              child: Column(
                children: [
                  RadioListTile<AssetDecision>(
                    key: const ValueKey('equipment-capitalise'),
                    value: AssetDecision.capitalise,
                    title: Text(l10n.equipmentDecisionCapitalise),
                  ),
                  RadioListTile<AssetDecision>(
                    key: const ValueKey('equipment-expense'),
                    value: AssetDecision.expense,
                    title: Text(l10n.equipmentDecisionExpense),
                  ),
                ],
              ),
            ),
            AppTextField(
              key: const ValueKey('equipment-basis'),
              controller: _basis,
              label: l10n.equipmentFieldBasis,
              maxLength: 300,
            ),
            if (_decision == AssetDecision.capitalise)
              LeaseDateButton(
                fieldKey: 'equipment-use-date',
                label: l10n.equipmentFieldUseDate,
                value: _from,
                first: DateTime(now.year - 30),
                last: DateTime(now.year + 1, 12, 31),
                onPicked: (d) => setState(() => _from = d),
              ),
            AppTextField(
              key: const ValueKey('equipment-external-id'),
              controller: _external,
              label: l10n.equipmentFieldExternalId,
              maxLength: 100,
            ),
            if (_invalid)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.equipmentInvalid,
                  key: const ValueKey('equipment-invalid'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('equipment-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('equipment-decide-save'),
          onPressed: _save,
          child: Text(l10n.equipmentDecideSave),
        ),
      ],
    );
  }
}
