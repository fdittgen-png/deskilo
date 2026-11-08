// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2372 — what the Xero sales-invoice file needs from the person: the
// organisation's sales account, the name of each tax rate the documents
// carry, and the order the organisation writes dates in. Nothing is
// proposed: every Xero organisation names its own.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/xero_invoice_csv.dart';

/// Asks for the Xero settings of [rates]; null when the person backs out.
Future<XeroInvoiceSettings?> showXeroInvoiceDialog(
  BuildContext context, {
  required List<InvoiceVatTotal> rates,
}) {
  final l10n = context.l10n;
  final account = TextEditingController();
  final taxTypes = {for (final t in rates) xeroRateKey(t): TextEditingController()};
  var order = XeroDateOrder.dayFirst;
  return showDialog<XeroInvoiceSettings>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text(l10n.xeroInvoiceAccountsTitle),
        content: SingleChildScrollView(
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l10n.xeroInvoiceAccountsIntro, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            Text(
              l10n.xeroInvoiceImportTaxExclusive,
              key: const ValueKey('xero-import-tax-exclusive'),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: AppSpacing.md),
            AppTextField(
              fieldKey: 'xero-account-code',
              controller: account,
              label: l10n.xeroInvoiceAccountCode,
            ),
            for (final t in rates)
              AppTextField(
                fieldKey: 'xero-tax-type-${xeroRateKey(t)}',
                controller: taxTypes[xeroRateKey(t)]!,
                label: l10n.xeroInvoiceTaxType(xeroRateLabel(t)),
              ),
            const SizedBox(height: AppSpacing.md),
            Text(l10n.xeroInvoiceDateOrder, style: Theme.of(context).textTheme.labelLarge),
            for (final (value, label) in [
              (XeroDateOrder.dayFirst, l10n.xeroInvoiceDayFirst),
              (XeroDateOrder.monthFirst, l10n.xeroInvoiceMonthFirst),
            ])
              ListTile(
                key: ValueKey('xero-date-order-${value.name}'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(order == value ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                title: Text(label),
                onTap: () => setState(() => order = value),
              ),
          ]),
        ),
        actions: [
          TextButton(
            key: const ValueKey('xero-invoice-cancel'),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            key: const ValueKey('xero-invoice-confirm'),
            onPressed: () => Navigator.of(context).pop(XeroInvoiceSettings(
              accountCode: account.text.trim(),
              taxTypes: {for (final e in taxTypes.entries) e.key: e.value.text.trim()},
              dateOrder: order,
            )),
            child: Text(l10n.commonSave),
          ),
        ],
      ),
    ),
  );
}
