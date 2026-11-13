// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3839 — a customer's statement for a period, printed through the
// workspace's report system: the `customer_statement_period` kind, its
// bands, quick view, save or share like every document. The person picks
// the days; the figures are the server's (customer_statement_period_v1).
// One statement per currency, so a customer with movements in two
// currencies chooses which. The document is in the customer's document
// language when it is known, as the open-items statement is.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/time/clock.dart';
import '../../../core/ui/app_date_picker.dart';
import '../../../core/ui/print_or_retry.dart';
import '../domain/customer_statement.dart';
import '../domain/customer_statement_period_report.dart';
import '../domain/customer_statement_report.dart';
import '../providers/customer_statement_providers.dart';
import '../providers/money_providers.dart';
import 'invoice_documents.dart';
import 'report_actions.dart';
import 'report_layout_actions.dart';

/// Prints a customer's statement for a period.
class CustomerStatementPeriodPrint {
  const CustomerStatementPeriodPrint(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// Asks for the days (the last month by default), then prints the
  /// statement of [customerId] in [workspaceId] for them.
  Future<void> show({
    required String workspaceId,
    required String customerId,
  }) async {
    final now = ref.read(clockProvider).now();
    final today = DateTime(now.year, now.month, now.day);
    final range = await showAppDateRangePicker(
      context: context,
      firstDate: DateTime(today.year - 10, today.month, today.day),
      lastDate: today,
      initialDateRange: DateTimeRange(
        start: DateTime(today.year, today.month - 1, today.day),
        end: today,
      ),
    );
    if (range == null || !context.mounted) return;
    await printPeriod(
      workspaceId: workspaceId,
      customerId: customerId,
      from: range.start,
      to: range.end,
    );
  }

  /// Prints the statement of [customerId] for [from]–[to]: quick view, save
  /// or share.
  Future<void> printPeriod({
    required String workspaceId,
    required String customerId,
    required DateTime from,
    required DateTime to,
  }) => printOrRetry(context, 'customer statement period', () async {
    await readDocumentPolicies(ref); // #3742 — the template, read
    final now = ref.read(clockProvider).now();
    final period = await ref
        .read(customerStatementReaderProvider)
        .period(workspaceId, customerId, from, to);
    final invoices = await ref.read(invoicesProvider.future);
    if (!context.mounted || period.currencies.isEmpty) return;
    final one = period.currencies.length == 1
        ? period.currencies.single
        : await _pick(period.currencies);
    if (one == null || !context.mounted) return;
    // The customer as last invoiced, under the space as it last printed.
    final theirs = invoices.where((i) => i.memberId == customerId).toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    final latest = theirs.firstOrNull;
    final space = ([
      ...invoices,
    ]..sort((a, b) => b.issuedAt.compareTo(a.issuedAt))).firstOrNull;
    final language = latest == null
        ? ''
        : await customerDocumentLanguage(ref, latest);
    if (!context.mounted) return;
    await _print(period, one, latest, space, language, now);
  });

  Future<void> _print(
    CustomerStatementPeriod period,
    PeriodCurrency one,
    Invoice? customer,
    Invoice? space,
    String language,
    DateTime now,
  ) async {
    final l10n = language.isEmpty ? context.l10n : l10nForLanguage(language);
    final data = customerStatementPeriodReportData(
      one,
      StatementLetter(
        customerName: customer?.memberName ?? '',
        customerAddress: customer?.memberAddress ?? '',
        issued: now,
        issuedBy: space?.issuerName ?? '',
        letterhead: {
          'workspace': space?.workspaceName ?? '',
          'workspace_address': space?.workspaceAddress ?? '',
        },
      ),
      period: period,
      locale: language.isEmpty ? l10n.localeName : language,
    );
    final rendered = renderLetterDoc(
      context,
      ref,
      docId: 'customer_statement_period',
      data: data,
      language: language,
    );
    final name = customer?.memberName ?? '';
    final title = [
      l10n.reportDocCustomerStatementPeriod,
      if (name.isNotEmpty) name,
    ].join(' · ');
    await runReportActions(
      context,
      ref,
      keyPrefix: 'customer-statement-period',
      logMessage: 'customer statement period pdf failed',
      render: () => rendered,
      buildPdf: () async {
        final pdf = await letterDocPdf(
          context,
          ref,
          report: rendered,
          title: title,
          layoutXml: letterLayoutXml(ref, docId: 'customer_statement_period'),
          data: data,
        );
        return (
          bytes: pdf.bytes,
          fileName: 'statement-period-${one.currency.toLowerCase()}.pdf',
        );
      },
    );
  }

  /// Asks which currency's statement to print.
  Future<PeriodCurrency?> _pick(List<PeriodCurrency> currencies) =>
      showDialog<PeriodCurrency>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: Text(dialog.l10n.customerStatementPickCurrency),
          children: [
            for (final c in currencies)
              SimpleDialogOption(
                key: ValueKey('customer-statement-period-${c.currency}'),
                onPressed: () => Navigator.of(dialog).pop(c),
                child: Text(c.currency),
              ),
          ],
        ),
      );
}
