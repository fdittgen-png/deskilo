// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_sheet.dart';
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
    showAppSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FieldPickerSheet(textKeys: textKeys),
    );

/// The groups a field belongs to — a reading aid over one flat list.
/// #966 — by TOPIC, in the order an owner reads a document: what the
/// document is, who it is for, who issues it, the amounts, then the
/// specialised reports and the loops.
@visibleForTesting
enum ReportFieldGroup {
  document,
  member,
  seller,
  money,
  bank,
  legal,
  usage,
  vat,
  sites,
  status,
  loops,
  texts,
}

@visibleForTesting
ReportFieldGroup reportFieldGroup(String field) => switch (field) {
      // #880 — the owner's own texts.
      final String f when f.startsWith('text.') => ReportFieldGroup.texts,
      'number' ||
      'period_month' ||
      'period_year' ||
      'period' ||
      'issued' ||
      'due_date' ||
      'purchase_order' ||
      'buyer_reference' ||
      'issued_by' ||
      'replaces' ||
      'voided' ||
      'proforma' ||
      'copy' ||
      'credit_note' =>
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
      'client_legal_id' ||
      'client_member_number' =>
        ReportFieldGroup.member,
      'seller_legal_form' ||
      'seller_registration' ||
      'seller_vat_id' ||
      'seller_legal_id' ||
      'exemption_reason' ||
      'vat_exigibility_mention' =>
        ReportFieldGroup.seller,
      'total' ||
      'charges' ||
      'payments' ||
      'has_vat' ||
      'net_total' ||
      'vat_total' ||
      'refund_total' ||
      'pending_payments_total' ||
      'pending_expenses_total' =>
        ReportFieldGroup.money,
      'iban' ||
      'bic' ||
      'bank_name' ||
      'bank_account' ||
      'bank_code' ||
      'account_holder' ||
      'payment_reference' =>
        ReportFieldGroup.bank,
      'usage_paid' ||
      'usage_included_half_days' ||
      'usage_used_half_days' ||
      'usage_remaining_half_days' ||
      'usage_extra_half_days' ||
      'usage_overage' ||
      'usage_supplements' =>
        ReportFieldGroup.usage,
      'vat_period' ||
      'vat_period_net' ||
      'vat_period_vat' ||
      'vat_period_gross' ||
      'declaration_status' || 'declaration_note' || 'declaration_invoice_count' ||
      'vat_basis_note' =>
        ReportFieldGroup.vat,
      'site_name' || 'site_address' || 'usage_sites' => ReportFieldGroup.sites,
      final String f when f.startsWith('status_') && f != 'status_members' =>
        ReportFieldGroup.status,
      'lines' ||
      'vat' ||
      'usage_records' ||
      'configuration_rows' ||
      'vat_form_boxes' ||
      'vat_positions' ||
      'vat_rate_totals' ||
      'status_members' =>
        ReportFieldGroup.loops,
      _ => ReportFieldGroup.legal,
    };

/// #966 — what a field IS, in one line, in the reader's language. Every
/// registry placeholder has one (pinned by test); an unknown field (a
/// text key) reads as itself.
@visibleForTesting
String reportFieldMeaning(String field, AppLocalizations l10n) =>
    switch (field) {
      'number' => l10n.reportFieldMeaningNumber,
      'member' => l10n.reportFieldMeaningMember,
      'workspace' => l10n.reportFieldMeaningWorkspace,
      'workspace_address' => l10n.reportFieldMeaningWorkspaceAddress,
      'period' => l10n.reportFieldMeaningPeriod,
      // #1002 — the month by name, and the year, for a designed label.
      'period_month' => l10n.reportFieldMeaningPeriodMonth,
      'period_year' => l10n.reportFieldMeaningPeriodYear,
      'issued' => l10n.reportFieldMeaningIssued,
      'due_date' => l10n.reportFieldMeaningDueDate,
      'purchase_order' => l10n.reportFieldMeaningPurchaseOrder,
      'buyer_reference' => l10n.reportFieldMeaningBuyerReference,
      'issued_by' => l10n.reportFieldMeaningIssuedBy,
      'replaces' => l10n.reportFieldMeaningReplaces,
      'total' => l10n.reportFieldMeaningTotal,
      'charges' => l10n.reportFieldMeaningCharges,
      'payments' => l10n.reportFieldMeaningPayments,
      'voided' => l10n.reportFieldMeaningVoided,
      'proforma' => l10n.reportFieldMeaningProforma,
      'copy' => l10n.reportFieldMeaningCopy,
      'has_vat' => l10n.reportFieldMeaningHasVat,
      'lines' => l10n.reportFieldMeaningLines,
      'vat' => l10n.reportFieldMeaningVat,
      'net_total' => l10n.reportFieldMeaningNetTotal,
      'vat_total' => l10n.reportFieldMeaningVatTotal,
      'credit_note' => l10n.reportFieldMeaningCreditNote,
      'refund_total' => l10n.reportFieldMeaningRefundTotal,
      'iban' => l10n.reportFieldMeaningIban,
      'bic' => l10n.reportFieldMeaningBic,
      'bank_name' => l10n.reportFieldMeaningBankName,
      'bank_account' => l10n.reportFieldMeaningBankAccount,
      'bank_code' => l10n.reportFieldMeaningBankCode,
      'account_holder' => l10n.reportFieldMeaningAccountHolder,
      'payment_reference' => l10n.reportFieldMeaningPaymentReference,
      'seller_legal_form' => l10n.reportFieldMeaningSellerLegalForm,
      'seller_registration' => l10n.reportFieldMeaningSellerRegistration,
      'seller_vat_id' => l10n.reportFieldMeaningSellerVatId,
      'seller_legal_id' => l10n.reportFieldMeaningSellerLegalId,
      'exemption_reason' => l10n.reportFieldMeaningExemptionReason,
      'vat_exigibility_mention' => l10n.reportFieldMeaningVatExigibilityMention,
      'client_name' => l10n.reportFieldMeaningClientName,
      'client_company' => l10n.reportFieldMeaningClientCompany,
      'client_phone' => l10n.reportFieldMeaningClientPhone,
      'client_email' => l10n.reportFieldMeaningClientEmail,
      'client_address' => l10n.reportFieldMeaningClientAddress,
      'client_vat_id' => l10n.reportFieldMeaningClientVatId,
      'client_legal_id' => l10n.reportFieldMeaningClientLegalId,
      'client_member_number' => l10n.reportFieldMeaningClientMemberNumber,
      'usage_paid' => l10n.reportFieldMeaningUsagePaid,
      'usage_included_half_days' => l10n.reportFieldMeaningUsageIncludedHalfDays,
      'usage_used_half_days' => l10n.reportFieldMeaningUsageUsedHalfDays,
      'usage_remaining_half_days' => l10n.reportFieldMeaningUsageRemainingHalfDays,
      'usage_extra_half_days' => l10n.reportFieldMeaningUsageExtraHalfDays,
      'usage_overage' => l10n.reportFieldMeaningUsageOverage,
      'usage_supplements' => l10n.reportFieldMeaningUsageSupplements,
      'usage_records' => l10n.reportFieldMeaningUsageRecords,
      'vat_period' => l10n.reportFieldMeaningVatPeriod,
      'vat_period_net' => l10n.reportFieldMeaningVatPeriodNet,
      'vat_period_vat' => l10n.reportFieldMeaningVatPeriodVat,
      'vat_period_gross' => l10n.reportFieldMeaningVatPeriodGross,
      'vat_basis_note' => l10n.reportFieldMeaningVatBasisNote,
      'site_name' => l10n.reportFieldMeaningSiteName,
      'site_address' => l10n.reportFieldMeaningSiteAddress,
      'usage_sites' => l10n.reportFieldMeaningUsageSites,
      'pending_payments_total' => l10n.reportFieldMeaningPendingPaymentsTotal,
      'pending_expenses_total' => l10n.reportFieldMeaningPendingExpensesTotal,
      'status_from' => l10n.reportFieldMeaningStatusFrom,
      'status_to' => l10n.reportFieldMeaningStatusTo,
      'status_invoiced' => l10n.reportFieldMeaningStatusInvoiced,
      'status_credit_notes' => l10n.reportFieldMeaningStatusCreditNotes,
      'status_payments' => l10n.reportFieldMeaningStatusPayments,
      'status_reimbursed' => l10n.reportFieldMeaningStatusReimbursed,
      'status_repartitioned' => l10n.reportFieldMeaningStatusRepartitioned,
      'status_credits' => l10n.reportFieldMeaningStatusCredits,
      'status_net' => l10n.reportFieldMeaningStatusNet,
      'status_members' => l10n.reportFieldMeaningStatusMembers,
      'declaration_status' => l10n.vatDeclStatus,
      'declaration_note' => l10n.reportFieldMeaningDeclarationNote,
      'declaration_invoice_count' => l10n.vatDeclInvoices,
      'configuration_rows' => l10n.workspaceConfigPdfTitle,
      'vat_form_boxes' => l10n.vatDeclBoxes,
      'vat_positions' => l10n.reportFieldMeaningVatPositions,
      'vat_rate_totals' => l10n.reportFieldMeaningVatRateTotals,
      'payment_terms' => l10n.reportFieldMeaningPaymentTerms,
      'payment_terms_source' => l10n.reportFieldMeaningPaymentTermsSource,
      'late_penalty' => l10n.reportFieldMeaningLatePenalty,
      'recovery_indemnity' => l10n.reportFieldMeaningRecoveryIndemnity,
      'escompte' => l10n.reportFieldMeaningEscompte,
      'insurance' => l10n.reportFieldMeaningInsurance,
      'special_mentions' => l10n.reportFieldMeaningSpecialMentions,
      _ => field,
    };

@visibleForTesting
String reportFieldGroupName(ReportFieldGroup group, AppLocalizations l10n) =>
    switch (group) {
      ReportFieldGroup.document =>
        l10n.reportFieldGroupDocument,
      ReportFieldGroup.member =>
        l10n.reportFieldGroupMember,
      ReportFieldGroup.money => l10n.reportFieldGroupMoney,
      ReportFieldGroup.legal =>
        l10n.reportFieldGroupLegal,
      ReportFieldGroup.loops =>
        l10n.reportFieldGroupLoops,
      ReportFieldGroup.texts => l10n.reportFieldGroupTexts,
      ReportFieldGroup.seller => l10n.reportFieldGroupSeller,
      ReportFieldGroup.bank => l10n.reportFieldGroupBank,
      ReportFieldGroup.usage => l10n.reportFieldGroupUsage,
      ReportFieldGroup.vat => l10n.reportFieldGroupVat,
      ReportFieldGroup.sites => l10n.reportFieldGroupSites,
      ReportFieldGroup.status =>
        l10n.reportFieldGroupStatus,
    };

/// What a field inserts: a token, or for the two loops the scaffold
/// that iterates them — one table row per item, ready to edit.
@visibleForTesting
String reportFieldMarkup(String field) => switch (field) {
      // #1002 — a subscription row composes its own wording from the
      // month and the percentage; every other kind keeps its label.
      'lines' =>
        '{% for line in lines %}{% if line.kind == "subscription" %}{{ line.month }} {{ line.pct }} %{% else %}{{ line.label }}{% endif %} | {{ line.amount }}{% endfor %}',
      'vat' =>
        '{% for v in vat %}{{ v.rate }} | {{ v.net }} | {{ v.amount }}{% endfor %}',
      'usage_records' =>
        '{% for r in usage_records %}{{ r.date }} | {{ r.space }} | {{ r.counted }}{% endfor %}',
      'configuration_rows' =>
        '{% for row in configuration_rows %}{{ row.label }} | {{ row.value }} | {{ row.detail }}{% endfor %}',
      'vat_form_boxes' =>
        '{% for box in vat_form_boxes %}{{ box.code }} | {{ box.label }} | {{ box.net }} | {{ box.vat }}{% endfor %}',
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
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final q = _query.trim().toLowerCase();
    final fields = [
      ...InvoicePdfTemplate.placeholders,
      for (final key in widget.textKeys) 'text.$key',
    ].where((f) =>
        q.isEmpty ||
        f.contains(q) ||
        reportFieldMeaning(f, l10n).toLowerCase().contains(q)).toList();
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
            Text(l10n.reportDesignerFields,
                style: theme.textTheme.titleMedium),
            const SizedBox(height: AppSpacing.sm),
            TextField(
              key: const ValueKey('report-fields-search'),
              autofocus: true,
              onChanged: (v) => setState(() => _query = v),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText:
                    l10n.reportDesignerFieldsSearch,
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
                      // #966 — the field AND what it means, one row
                      // each: a name alone is a riddle.
                      for (final f in list)
                        ListTile(
                          key: ValueKey('report-field-$f'),
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                          title: Text(f,
                              style: const TextStyle(
                                  fontFamily: 'monospace', fontSize: 12)),
                          subtitle: Text(reportFieldMeaning(f, l10n),
                              style: theme.textTheme.bodySmall),
                          onTap: () =>
                              Navigator.of(context).pop(reportFieldMarkup(f)),
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
