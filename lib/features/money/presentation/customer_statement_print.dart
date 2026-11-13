// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — a customer's statement printed through the workspace's report
// system: the `customer_statement` kind, its bands, quick view, save or
// share like every document. The figures are the server's snapshot as of
// today (customer_statement_v1); one statement per currency, so a customer
// with open items in two currencies chooses which. The document is in the
// customer's document language when it is known, as the reminder letter is.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/time/clock.dart';
import '../../../core/ui/app_snack.dart';
import '../../../core/ui/print_or_retry.dart';
import '../domain/customer_statement.dart';
import '../domain/customer_statement_report.dart';
import '../providers/customer_statement_providers.dart';
import '../providers/money_providers.dart';
import 'invoice_documents.dart';
import 'report_actions.dart';
import 'report_layout_actions.dart';

/// Prints a customer's statement of account.
class CustomerStatementPrint {
  const CustomerStatementPrint(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// The statement of [customerId] in [workspaceId] as of today: quick view,
  /// save or share; with nothing open, says so.
  Future<void> show({
    required String workspaceId,
    required String customerId,
  }) => printOrRetry(context, 'customer statement', () async {
    await readDocumentPolicies(ref); // #3742 — the template, read
    // #3876 — the business's day, as the customer page reads it.
    final now = statementDayOf(
      ref.read(invoicingBusinessProvider),
      ref.read(clockProvider).now(),
    );
    final statement = await ref
        .read(customerStatementReaderProvider)
        .read(workspaceId, customerId, now);
    final invoices = await ref.read(invoicesProvider.future);
    if (!context.mounted) return;
    if (statement.currencies.isEmpty) {
      AppSnack.info(context, context.l10n.customerStatementNothingOpen);
      return;
    }
    final one = statement.currencies.length == 1
        ? statement.currencies.single
        : await _pick(statement.currencies);
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
    await _print(statement, one, latest, space, language, now);
  });

  Future<void> _print(
    CustomerStatement statement,
    StatementCurrency one,
    Invoice? customer,
    Invoice? space,
    String language,
    DateTime now,
  ) async {
    final l10n = language.isEmpty ? context.l10n : l10nForLanguage(language);
    final data = customerStatementReportData(
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
      asOf: statement.asOf,
      locale: language.isEmpty ? l10n.localeName : language,
    );
    final rendered = renderLetterDoc(
      context,
      ref,
      docId: 'customer_statement',
      data: data,
      language: language,
    );
    final name = customer?.memberName ?? '';
    final title = [
      l10n.reportDocCustomerStatement,
      if (name.isNotEmpty) name,
    ].join(' · ');
    await runReportActions(
      context,
      ref,
      keyPrefix: 'customer-statement',
      logMessage: 'customer statement pdf failed',
      render: () => rendered,
      buildPdf: () async {
        final pdf = await letterDocPdf(
          context,
          ref,
          report: rendered,
          title: title,
          layoutXml: letterLayoutXml(ref, docId: 'customer_statement'),
          data: data,
        );
        return (
          bytes: pdf.bytes,
          fileName: 'statement-${one.currency.toLowerCase()}.pdf',
        );
      },
    );
  }

  /// Asks which currency's statement to print.
  Future<StatementCurrency?> _pick(List<StatementCurrency> currencies) =>
      showDialog<StatementCurrency>(
        context: context,
        builder: (dialog) => SimpleDialog(
          title: Text(dialog.l10n.customerStatementPickCurrency),
          children: [
            for (final c in currencies)
              SimpleDialogOption(
                key: ValueKey('customer-statement-${c.currency}'),
                onPressed: () => Navigator.of(dialog).pop(c),
                child: Text(c.currency),
              ),
          ],
        ),
      );
}
