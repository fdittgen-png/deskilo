// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/invoice_pdf_template.dart';

/// #822 — the data fields as a searchable, GROUPED picker: the chips
/// under the active element stay for the quick reach, this is the
/// place to find a field by name when there are thirty-odd of them.
/// Pops with the markup to insert (`{{ field }}`, or a loop scaffold
/// for `lines` / `vat`), or null.
Future<String?> showReportFieldPicker(BuildContext context) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _FieldPickerSheet(),
    );

/// The groups a field belongs to — a reading aid over one flat list.
enum ReportFieldGroup { document, member, money, legal, loops }

ReportFieldGroup reportFieldGroup(String field) => switch (field) {
      'number' ||
      'period' ||
      'issued' ||
      'issued_by' ||
      'replaces' ||
      'voided' ||
      'proforma' ||
      'copy' =>
        ReportFieldGroup.document,
      'member' ||
      'workspace' ||
      'workspace_address' ||
      'client_address' ||
      'client_vat_id' ||
      'client_legal_id' =>
        ReportFieldGroup.member,
      'total' ||
      'charges' ||
      'payments' ||
      'has_vat' ||
      'net_total' ||
      'vat_total' ||
      'credit_note' ||
      'refund_total' =>
        ReportFieldGroup.money,
      'lines' || 'vat' => ReportFieldGroup.loops,
      _ => ReportFieldGroup.legal,
    };

String reportFieldGroupName(ReportFieldGroup group, AppLocalizations? l10n) =>
    switch (group) {
      ReportFieldGroup.document =>
        l10n?.reportFieldGroupDocument ?? 'Document',
      ReportFieldGroup.member =>
        l10n?.reportFieldGroupMember ?? 'Member & workspace',
      ReportFieldGroup.money => l10n?.reportFieldGroupMoney ?? 'Amounts',
      ReportFieldGroup.legal =>
        l10n?.reportFieldGroupLegal ?? 'Legal mentions',
      ReportFieldGroup.loops =>
        l10n?.reportFieldGroupLoops ?? 'Lines & VAT loops',
    };

/// What a field inserts: a token, or for the two loops the scaffold
/// that iterates them — one table row per item, ready to edit.
String reportFieldMarkup(String field) => switch (field) {
      'lines' =>
        '{% for line in lines %}{{ line.label }} | {{ line.amount }}{% endfor %}',
      'vat' =>
        '{% for v in vat %}{{ v.rate }} | {{ v.net }} | {{ v.amount }}{% endfor %}',
      _ => '{{ $field }}',
    };

class _FieldPickerSheet extends StatefulWidget {
  const _FieldPickerSheet();

  @override
  State<_FieldPickerSheet> createState() => _FieldPickerSheetState();
}

class _FieldPickerSheetState extends State<_FieldPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final fields = InvoicePdfTemplate.placeholders
        .where((f) => q.isEmpty || f.contains(q))
        .toList();
    final groups = <ReportFieldGroup, List<String>>{};
    for (final f in fields) {
      groups.putIfAbsent(reportFieldGroup(f), () => []).add(f);
    }
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n?.reportDesignerFields ?? 'Fields',
                style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('report-fields-search'),
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText:
                    l10n?.reportDesignerFieldsSearch ?? 'Search a field',
                isDense: true,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final group in ReportFieldGroup.values)
                    if (groups[group] case final list?) ...[
                      Padding(
                        padding: const EdgeInsets.only(
                            top: AppSpacing.sm, bottom: AppSpacing.xs),
                        child: Text(
                          reportFieldGroupName(group, l10n),
                          style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant),
                        ),
                      ),
                      Wrap(
                        spacing: AppSpacing.xs,
                        runSpacing: AppSpacing.xs,
                        children: [
                          for (final f in list)
                            ActionChip(
                              key: ValueKey('report-field-$f'),
                              label: Text(f,
                                  style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontSize: 11)),
                              onPressed: () => Navigator.of(context)
                                  .pop(reportFieldMarkup(f)),
                            ),
                        ],
                      ),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
