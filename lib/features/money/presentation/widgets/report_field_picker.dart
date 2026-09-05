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
Future<String?> showReportFieldPicker(
  BuildContext context, {
  /// #880 — the owner's text keys, offered as `text.<key>`.
  List<String> textKeys = const [],
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FieldPickerSheet(textKeys: textKeys),
    );

/// The groups a field belongs to — a reading aid over one flat list.
enum ReportFieldGroup { document, member, money, legal, loops, texts }

ReportFieldGroup reportFieldGroup(String field) => switch (field) {
      // #880 — the owner's own texts.
      String f when f.startsWith('text.') => ReportFieldGroup.texts,
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
      'client_name' ||
      'client_company' ||
      'client_phone' ||
      'client_email' ||
      'client_address' ||
      'client_vat_id' ||
      'client_legal_id' =>
        ReportFieldGroup.member,
      'usage_paid' ||
      'usage_included_half_days' ||
      'usage_used_half_days' ||
      'usage_remaining_half_days' ||
      'usage_extra_half_days' ||
      'usage_overage' ||
      'usage_supplements' ||
      'vat_period' ||
      'vat_period_net' ||
      'vat_period_vat' ||
      'vat_period_gross' ||
      'total' ||
      'charges' ||
      'payments' ||
      'has_vat' ||
      'net_total' ||
      'vat_total' ||
      'credit_note' ||
      'refund_total' =>
        ReportFieldGroup.money,
      'lines' ||
      'vat' ||
      'usage_records' ||
      'vat_positions' ||
      'vat_rate_totals' =>
        ReportFieldGroup.loops,
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
      ReportFieldGroup.texts => l10n?.reportFieldGroupTexts ?? 'Your texts',
    };

/// What a field inserts: a token, or for the two loops the scaffold
/// that iterates them — one table row per item, ready to edit.
String reportFieldMarkup(String field) => switch (field) {
      'lines' =>
        '{% for line in lines %}{{ line.label }} | {{ line.amount }}{% endfor %}',
      'vat' =>
        '{% for v in vat %}{{ v.rate }} | {{ v.net }} | {{ v.amount }}{% endfor %}',
      'usage_records' =>
        '{% for r in usage_records %}{{ r.date }} | {{ r.space }} | {{ r.counted }}{% endfor %}',
      'vat_positions' =>
        '{% for p in vat_positions %}{{ p.number }} | {{ p.rate }} | {{ p.net }} | {{ p.vat }} | {{ p.gross }}{% endfor %}',
      'vat_rate_totals' =>
        '{% for t in vat_rate_totals %}{{ t.rate }} | {{ t.net }} | {{ t.vat }} | {{ t.gross }}{% endfor %}',
      _ => '{{ $field }}',
    };

class _FieldPickerSheet extends StatefulWidget {
  const _FieldPickerSheet({this.textKeys = const []});

  final List<String> textKeys;

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
    final fields = [
      ...InvoicePdfTemplate.placeholders,
      for (final key in widget.textKeys) 'text.$key',
    ].where((f) => q.isEmpty || f.contains(q)).toList();
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
