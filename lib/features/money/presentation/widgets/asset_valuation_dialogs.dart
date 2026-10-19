// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/files/file_picker.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/asset_valuation.dart';
import '../../providers/asset_valuation_providers.dart';
import 'asset_valuation_manual.dart';

/// The sentence for one problem of the file.
String _issueText(AppLocalizations l10n, ValuationIssue i) =>
    switch (i.kind) {
      ValuationIssueKind.empty => l10n.valuationIssueEmpty,
      ValuationIssueKind.tooManyRows => l10n.valuationIssueTooMany,
      ValuationIssueKind.header => l10n.valuationIssueHeader,
      ValuationIssueKind.columnCount => l10n.valuationIssueColumns(i.line),
      ValuationIssueKind.assetNumber => l10n.valuationIssueAsset(i.line),
      ValuationIssueKind.basis => l10n.valuationIssueBasis(i.line),
      ValuationIssueKind.date => l10n.valuationIssueDate(i.line),
      ValuationIssueKind.period => l10n.valuationIssuePeriod(i.line),
      ValuationIssueKind.currency => l10n.valuationIssueCurrency(i.line),
      ValuationIssueKind.minor => l10n.valuationIssueMinor(i.line, i.detail),
      ValuationIssueKind.mixed => l10n.valuationIssueMixed(i.line),
      ValuationIssueKind.duplicateAsset => l10n.valuationIssueDuplicate(i.line),
    };

/// Reads a file of valuations, shows what it says and what is wrong with it,
/// and stages it once it is usable and its source is named. True once the
/// server has it.
Future<bool?> showValuationImportDialog(
  BuildContext context,
  String workspaceId,
) => showDialog<bool>(
  context: context,
  builder: (_) => _ImportDialog(workspaceId: workspaceId),
);

class _ImportDialog extends ConsumerStatefulWidget {
  const _ImportDialog({required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<_ImportDialog> createState() => _ImportDialogState();
}

class _ImportDialogState extends ConsumerState<_ImportDialog> {
  final _source = TextEditingController();
  final _reference = TextEditingController();
  ValuationCsv? _file;
  var _movements = 'period';
  var _complete = false;
  var _invalid = false;
  var _requestId = newRequestId();
  String? _attempted;

  @override
  void dispose() {
    _source.dispose();
    _reference.dispose();
    super.dispose();
  }

  void _edit(VoidCallback change) => setState(change);

  Future<void> _pick() async {
    final l10n = context.l10n;
    final file = await ref.read(filePickerProvider)(
      XTypeGroup(
        label: l10n.valuationFileTypeLabel,
        extensions: const ['csv'],
        mimeTypes: const ['text/csv'],
      ),
    );
    if (file == null) return;
    // Explicit UTF-8: XFile.readAsString is not UTF-8-safe for data-backed files.
    final content = utf8.decode(await file.readAsBytes());
    _edit(() {
      _file = readValuationCsv(content);
      _invalid = false;
    });
  }

  Future<void> _type() async {
    final csv = await showValuationManualDialog(context);
    if (csv == null) return;
    _edit(() {
      _file = readValuationCsv(csv);
      _invalid = false;
    });
  }

  Future<void> _save() async {
    final file = _file;
    final source = ValuationSource(
      system: _source.text,
      reference: _reference.text,
      movements: _movements,
      completeScope: _complete,
    );
    if (file == null || !file.usable || source.system.trim().isEmpty) {
      _edit(() => _invalid = true);
      return;
    }
    // The same entries keep the same request id; changed ones take a new one.
    final key =
        '${file.sha256Hex}|${source.system}|${source.reference}|$_movements|$_complete';
    if (_attempted != null && _attempted != key) _requestId = newRequestId();
    _attempted = key;
    final navigator = Navigator.of(context);
    var accepted = false;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'valuation stage failed',
      errorText: context.l10n.valuationRefused,
      action: () async {
        accepted =
            await ref
                .read(assetValuationCommandProvider)
                .stage(
                  widget.workspaceId,
                  file: file,
                  source: source,
                  requestId: _requestId,
                ) !=
            null;
      },
    );
    if (ok && accepted && mounted) navigator.pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final file = _file;
    return AlertDialog(
      title: Text(l10n.valuationImport),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('valuation-pick'),
              onPressed: _pick,
              icon: const Icon(Icons.folder_open_outlined),
              label: Text(l10n.valuationPick),
            ),
            TextButton.icon(
              key: const ValueKey('valuation-type'),
              onPressed: _type,
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.valuationManual),
            ),
            if (file != null && file.issues.isEmpty && file.rows.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  l10n.valuationPreview(
                    file.basis == ValuationBasis.book
                        ? l10n.valuationBasisBook
                        : l10n.valuationBasisTax,
                    material.formatMediumDate(file.periodFrom!),
                    material.formatMediumDate(file.periodTo!),
                    file.currency,
                    file.rows.length,
                  ),
                  key: const ValueKey('valuation-preview'),
                ),
              ),
            if (file != null && file.mismatches > 0)
              Text(
                l10n.valuationMismatches(file.mismatches),
                key: const ValueKey('valuation-preview-mismatch'),
              ),
            if (file != null)
              for (final issue in file.issues.take(8))
                Text(
                  _issueText(l10n, issue),
                  key: const ValueKey('valuation-issue'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
            const SizedBox(height: AppSpacing.sm),
            AppTextField(
              key: const ValueKey('valuation-source'),
              controller: _source,
              label: l10n.valuationFieldSource,
              maxLength: 100,
            ),
            AppTextField(
              key: const ValueKey('valuation-reference'),
              controller: _reference,
              label: l10n.valuationFieldReference,
              maxLength: 200,
            ),
            DropdownButtonFormField<String>(
              key: const ValueKey('valuation-movements'),
              isExpanded: true,
              initialValue: _movements,
              decoration: InputDecoration(
                labelText: l10n.valuationFieldMovements,
              ),
              items: [
                DropdownMenuItem(
                  value: 'period',
                  child: Text(l10n.valuationMovementsPeriod),
                ),
                DropdownMenuItem(
                  value: 'ytd',
                  child: Text(l10n.valuationMovementsYtd),
                ),
              ],
              onChanged: (v) => _edit(() => _movements = v ?? _movements),
            ),
            SwitchListTile(
              key: const ValueKey('valuation-complete'),
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.valuationFieldComplete),
              value: _complete,
              onChanged: (v) => _edit(() => _complete = v),
            ),
            if (_invalid)
              Text(
                l10n.valuationInvalid,
                key: const ValueKey('valuation-invalid'),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('valuation-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('valuation-stage'),
          onPressed: _save,
          child: Text(l10n.valuationStage),
        ),
      ],
    );
  }
}

/// Confirms a staged batch as the evidence of its period. When a confirmed
/// batch of the same basis already values the period, [candidates] lets the
/// person say which one it replaces, and why.
Future<bool?> showValuationConfirmDialog(
  BuildContext context,
  String workspaceId,
  ValuationBatch batch,
  List<ValuationBatch> candidates,
) => showDialog<bool>(
  context: context,
  builder: (_) => _ConfirmDialog(
    workspaceId: workspaceId,
    batch: batch,
    candidates: candidates,
  ),
);

class _ConfirmDialog extends ConsumerStatefulWidget {
  const _ConfirmDialog({
    required this.workspaceId,
    required this.batch,
    required this.candidates,
  });

  final String workspaceId;
  final ValuationBatch batch;
  final List<ValuationBatch> candidates;

  @override
  ConsumerState<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends ConsumerState<_ConfirmDialog> {
  final _reason = TextEditingController();
  String? _supersedes;
  var _requestId = newRequestId();

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _edit(VoidCallback change) => setState(change);

  Future<void> _save() async {
    final navigator = Navigator.of(context);
    var accepted = false;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'valuation confirm failed',
      errorText: context.l10n.valuationRefused,
      action: () async {
        accepted =
            await ref
                .read(assetValuationCommandProvider)
                .confirm(
                  widget.workspaceId,
                  batch: widget.batch,
                  requestId: _requestId,
                  supersedes: _supersedes,
                  reason: _reason.text,
                ) !=
            null;
      },
    );
    if (ok && accepted && mounted) {
      navigator.pop(true);
    } else if (ok && mounted) {
      _edit(() => _requestId = newRequestId());
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.valuationConfirm),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.valuationConfirmBody),
            if (widget.candidates.isNotEmpty) ...[
              DropdownButtonFormField<String?>(
                key: const ValueKey('valuation-supersedes'),
                isExpanded: true,
                initialValue: _supersedes,
                decoration: InputDecoration(labelText: l10n.valuationReplaces),
                items: [
                  DropdownMenuItem<String?>(
                    child: Text(l10n.valuationReplacesNone),
                  ),
                  for (final c in widget.candidates)
                    DropdownMenuItem(
                      value: c.id,
                      child: Text(
                        '${c.sourceSystem} · ${material.formatMediumDate(c.periodFrom)}'
                        ' – ${material.formatMediumDate(c.periodTo)}',
                      ),
                    ),
                ],
                onChanged: (v) => _edit(() => _supersedes = v),
              ),
              if (_supersedes != null)
                AppTextField(
                  key: const ValueKey('valuation-reason'),
                  controller: _reason,
                  label: l10n.valuationReason,
                  maxLength: 300,
                ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('valuation-confirm-cancel'),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('valuation-confirm-save'),
          onPressed: _save,
          child: Text(l10n.valuationConfirm),
        ),
      ],
    );
  }
}
