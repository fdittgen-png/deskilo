// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4166 — a quote printed through the workspace's report system: the `quote`
// kind, its letter layout (the customer in the window) when the letter
// standard is on, else its bands; quick view, save or share like every
// document. It is the offer the customer was sent — the latest sent revision,
// its amounts as the issuer froze them — and it carries the quote's reference,
// never an invoice number.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/jurisdiction/installed_postal_layouts.dart';
import '../../../core/ui/print_or_retry.dart';
import '../domain/billing_customer.dart';
import '../domain/customer_quote.dart';
import '../domain/quote_report.dart';
import '../providers/billing_customer_providers.dart';
import 'invoice_documents.dart';
import 'report_actions.dart';
import 'report_facts_of.dart';
import 'report_layout_actions.dart';

/// The revision a quote document prints: the offer the customer holds.
QuoteRevision? quoteDocumentRevision(CustomerQuote quote) =>
    quote.current ?? quote.revisions.where((r) => r.sent).lastOrNull;

/// The customer's name and postal block, in the order of their country.
QuoteCustomer _customerBlock(BillingParty? customer) {
  if (customer == null) return (name: '', address: '');
  final d = customer.draft;
  return (
    name: customer.displayName,
    address: [
      d.street,
      ...postalLayoutOf(d.countryCode).render(
        postalCode: d.postalCode,
        city: d.city,
        region: d.subdivision,
        capitals: false,
      ),
      d.countryCode,
    ].where((p) => p.trim().isNotEmpty).join('\n'),
  );
}

/// Prints a quote of the business.
class QuotePrint {
  const QuotePrint(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  /// Opens [quote]'s document: quick view, save or share. A quote with no sent
  /// revision has no document.
  Future<void> show({
    required String workspaceId,
    required CustomerQuote quote,
  }) => printOrRetry(context, 'quote', () async {
    final revision = quoteDocumentRevision(quote);
    if (revision == null) return;
    await readDocumentPolicies(ref); // #3742 — the template and rules, read
    final customers = await ref.read(
      billingCustomersProvider(workspaceId).future,
    );
    if (!context.mounted) return;
    // A customer has no language here: the quote is written in the business's
    // document language and its country's conventions.
    final locale = businessDocumentLocale(ref);
    final l10n = l10nForLanguage(locale.language);
    final letterhead = quoteLetterheadOf(ref);
    final customer = _customerBlock(
      customers.where((c) => c.subjectId == quote.subjectId).firstOrNull,
    );
    final data = quoteReportData(
      quote,
      revision,
      customer: customer,
      format: quoteFormatsFor(
        language: locale.language,
        formatLocale: locale.formatLocale,
        currency: revision.totals?.currency ?? letterhead.currency,
      ),
      issuedBy: letterhead.name,
      letterhead: {
        'workspace': letterhead.name,
        'workspace_address': letterhead.address,
      },
    );
    final rendered = renderLetterDoc(
      context,
      ref,
      docId: 'quote',
      data: data,
      language: locale.language,
    );
    final title = l10n.reportDocQuoteTitle(quote.reference ?? '');
    await runReportActions(
      context,
      ref,
      keyPrefix: 'quote-print',
      logMessage: 'quote pdf failed',
      render: () => rendered,
      buildPdf: () async {
        final pdf = await letterPdfOf(
          ref,
          (
            report: rendered,
            title: title,
            layoutXml: letterLayoutXml(ref, docId: 'quote'),
            data: data,
            images: const {},
          ),
          kind: 'quote',
          pageLabel: l10n.invoicePdfPage,
          watermark: developmentMark(context, ref),
        );
        return (
          bytes: pdf.bytes,
          fileName: 'quote-${quote.reference ?? quote.id}.pdf',
        );
      },
    );
  });
}
