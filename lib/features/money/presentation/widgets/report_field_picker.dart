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
/// #966 — by TOPIC, in the order an owner reads a document: what the
/// document is, who it is for, who issues it, the amounts, then the
/// specialised reports and the loops.
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

ReportFieldGroup reportFieldGroup(String field) => switch (field) {
      // #880 — the owner's own texts.
      String f when f.startsWith('text.') => ReportFieldGroup.texts,
      'number' ||
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
      'vat_basis_note' =>
        ReportFieldGroup.vat,
      'site_name' || 'site_address' || 'usage_sites' => ReportFieldGroup.sites,
      String f when f.startsWith('status_') && f != 'status_members' =>
        ReportFieldGroup.status,
      'lines' ||
      'vat' ||
      'usage_records' ||
      'vat_positions' ||
      'vat_rate_totals' ||
      'status_members' =>
        ReportFieldGroup.loops,
      _ => ReportFieldGroup.legal,
    };

/// #966 — what a field IS, in one line, in the reader's language. Every
/// registry placeholder has one (pinned by test); an unknown field (a
/// text key) reads as itself.
String reportFieldMeaning(String field, AppLocalizations? l10n) =>
    switch (field) {
      'number' => l10n?.reportFieldMeaningNumber ?? 'The document\'s number',
      'member' => l10n?.reportFieldMeaningMember ?? 'The member\'s display name',
      'workspace' => l10n?.reportFieldMeaningWorkspace ?? 'The workspace\'s name',
      'workspace_address' => l10n?.reportFieldMeaningWorkspaceAddress ?? 'The workspace\'s address, or the document site\'s',
      'period' => l10n?.reportFieldMeaningPeriod ?? 'The month the document covers',
      'issued' => l10n?.reportFieldMeaningIssued ?? 'The issue date',
      'due_date' => l10n?.reportFieldMeaningDueDate ?? 'The settlement date',
      'purchase_order' => l10n?.reportFieldMeaningPurchaseOrder ?? 'The buyer\'s purchase-order reference',
      'buyer_reference' => l10n?.reportFieldMeaningBuyerReference ?? 'The buyer\'s own reference (public sector)',
      'issued_by' => l10n?.reportFieldMeaningIssuedBy ?? 'Who issued the document',
      'replaces' => l10n?.reportFieldMeaningReplaces ?? 'The number of the invoice this one replaces',
      'total' => l10n?.reportFieldMeaningTotal ?? 'The amount due, everything included',
      'charges' => l10n?.reportFieldMeaningCharges ?? 'The charges before payments',
      'payments' => l10n?.reportFieldMeaningPayments ?? 'Payments already received',
      'voided' => l10n?.reportFieldMeaningVoided ?? 'True when the invoice was cancelled',
      'proforma' => l10n?.reportFieldMeaningProforma ?? 'True on a proforma',
      'copy' => l10n?.reportFieldMeaningCopy ?? 'True on a duplicate',
      'has_vat' => l10n?.reportFieldMeaningHasVat ?? 'True when VAT applies',
      'lines' => l10n?.reportFieldMeaningLines ?? 'The invoice lines — a loop',
      'vat' => l10n?.reportFieldMeaningVat ?? 'VAT by rate — a loop',
      'net_total' => l10n?.reportFieldMeaningNetTotal ?? 'The total before VAT',
      'vat_total' => l10n?.reportFieldMeaningVatTotal ?? 'The total VAT',
      'credit_note' => l10n?.reportFieldMeaningCreditNote ?? 'True on a credit note',
      'refund_total' => l10n?.reportFieldMeaningRefundTotal ?? 'The amount refunded',
      'iban' => l10n?.reportFieldMeaningIban ?? 'The account\'s IBAN',
      'bic' => l10n?.reportFieldMeaningBic ?? 'The bank\'s BIC',
      'bank_name' => l10n?.reportFieldMeaningBankName ?? 'The bank\'s name',
      'bank_account' => l10n?.reportFieldMeaningBankAccount ?? 'The account number',
      'bank_code' => l10n?.reportFieldMeaningBankCode ?? 'The bank code',
      'account_holder' => l10n?.reportFieldMeaningAccountHolder ?? 'The account holder',
      'payment_reference' => l10n?.reportFieldMeaningPaymentReference ?? 'The reference to quote when paying',
      'seller_legal_form' => l10n?.reportFieldMeaningSellerLegalForm ?? 'The seller\'s legal form',
      'seller_registration' => l10n?.reportFieldMeaningSellerRegistration ?? 'The seller\'s registration (SIREN, RNA…)',
      'seller_vat_id' => l10n?.reportFieldMeaningSellerVatId ?? 'The seller\'s VAT number',
      'seller_legal_id' => l10n?.reportFieldMeaningSellerLegalId ?? 'The seller\'s legal identifier',
      'exemption_reason' => l10n?.reportFieldMeaningExemptionReason ?? 'The VAT exemption mention',
      'vat_exigibility_mention' => l10n?.reportFieldMeaningVatExigibilityMention ?? 'When the VAT falls due, in words',
      'client_name' => l10n?.reportFieldMeaningClientName ?? 'The client\'s full name',
      'client_company' => l10n?.reportFieldMeaningClientCompany ?? 'The client\'s company',
      'client_phone' => l10n?.reportFieldMeaningClientPhone ?? 'The client\'s phone',
      'client_email' => l10n?.reportFieldMeaningClientEmail ?? 'The client\'s e-mail',
      'client_address' => l10n?.reportFieldMeaningClientAddress ?? 'The client\'s postal block',
      'client_vat_id' => l10n?.reportFieldMeaningClientVatId ?? 'The client\'s VAT number',
      'client_legal_id' => l10n?.reportFieldMeaningClientLegalId ?? 'The client\'s legal identifier (SIREN…)',
      'client_member_number' => l10n?.reportFieldMeaningClientMemberNumber ?? 'The client\'s member number',
      'usage_paid' => l10n?.reportFieldMeaningUsagePaid ?? 'What the month\'s usage cost',
      'usage_included_half_days' => l10n?.reportFieldMeaningUsageIncludedHalfDays ?? 'Half-days included in the subscription',
      'usage_used_half_days' => l10n?.reportFieldMeaningUsageUsedHalfDays ?? 'Half-days used',
      'usage_remaining_half_days' => l10n?.reportFieldMeaningUsageRemainingHalfDays ?? 'Half-days remaining',
      'usage_extra_half_days' => l10n?.reportFieldMeaningUsageExtraHalfDays ?? 'Half-days beyond the subscription',
      'usage_overage' => l10n?.reportFieldMeaningUsageOverage ?? 'The overage charged',
      'usage_supplements' => l10n?.reportFieldMeaningUsageSupplements ?? 'The accessory supplements',
      'usage_records' => l10n?.reportFieldMeaningUsageRecords ?? 'Every consumption record — a loop',
      'vat_period' => l10n?.reportFieldMeaningVatPeriod ?? 'The VAT period reported',
      'vat_period_net' => l10n?.reportFieldMeaningVatPeriodNet ?? 'The period\'s net total',
      'vat_period_vat' => l10n?.reportFieldMeaningVatPeriodVat ?? 'The period\'s VAT',
      'vat_period_gross' => l10n?.reportFieldMeaningVatPeriodGross ?? 'The period\'s gross total',
      'vat_basis_note' => l10n?.reportFieldMeaningVatBasisNote ?? 'Whether the period counts what was paid or what was issued',
      'site_name' => l10n?.reportFieldMeaningSiteName ?? 'The document site\'s name',
      'site_address' => l10n?.reportFieldMeaningSiteAddress ?? 'The document site\'s address',
      'usage_sites' => l10n?.reportFieldMeaningUsageSites ?? 'The other sites the month stood at',
      'pending_payments_total' => l10n?.reportFieldMeaningPendingPaymentsTotal ?? 'Payments still to confirm',
      'pending_expenses_total' => l10n?.reportFieldMeaningPendingExpensesTotal ?? 'Expenses still to validate',
      'status_from' => l10n?.reportFieldMeaningStatusFrom ?? 'The status period\'s first day',
      'status_to' => l10n?.reportFieldMeaningStatusTo ?? 'The status period\'s last day',
      'status_invoiced' => l10n?.reportFieldMeaningStatusInvoiced ?? 'What the workspace invoiced',
      'status_credit_notes' => l10n?.reportFieldMeaningStatusCreditNotes ?? 'The credit notes issued',
      'status_payments' => l10n?.reportFieldMeaningStatusPayments ?? 'What was collected',
      'status_reimbursed' => l10n?.reportFieldMeaningStatusReimbursed ?? 'What was reimbursed',
      'status_repartitioned' => l10n?.reportFieldMeaningStatusRepartitioned ?? 'What was repartitioned',
      'status_credits' => l10n?.reportFieldMeaningStatusCredits ?? 'The credits granted',
      'status_net' => l10n?.reportFieldMeaningStatusNet ?? 'Revenues minus expenses',
      'status_members' => l10n?.reportFieldMeaningStatusMembers ?? 'The member-by-member lines — a loop',
      'vat_positions' => l10n?.reportFieldMeaningVatPositions ?? 'Every invoice of the VAT period — a loop',
      'vat_rate_totals' => l10n?.reportFieldMeaningVatRateTotals ?? 'The VAT period totals by rate — a loop',
      'payment_terms' => l10n?.reportFieldMeaningPaymentTerms ?? 'The payment terms mention',
      'payment_terms_source' => l10n?.reportFieldMeaningPaymentTermsSource ?? 'Where the payment terms come from (member or workspace)',
      'late_penalty' => l10n?.reportFieldMeaningLatePenalty ?? 'The late-payment penalty mention',
      'recovery_indemnity' => l10n?.reportFieldMeaningRecoveryIndemnity ?? 'The recovery indemnity mention',
      'escompte' => l10n?.reportFieldMeaningEscompte ?? 'The early-payment discount mention',
      'insurance' => l10n?.reportFieldMeaningInsurance ?? 'The professional insurance mention',
      'special_mentions' => l10n?.reportFieldMeaningSpecialMentions ?? 'The workspace\'s special mentions',
      _ => field,
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
      ReportFieldGroup.seller => l10n?.reportFieldGroupSeller ?? 'Seller',
      ReportFieldGroup.bank => l10n?.reportFieldGroupBank ?? 'Bank details',
      ReportFieldGroup.usage => l10n?.reportFieldGroupUsage ?? 'Usage report',
      ReportFieldGroup.vat => l10n?.reportFieldGroupVat ?? 'VAT report',
      ReportFieldGroup.sites => l10n?.reportFieldGroupSites ?? 'Sites',
      ReportFieldGroup.status =>
        l10n?.reportFieldGroupStatus ?? 'Workspace status',
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
