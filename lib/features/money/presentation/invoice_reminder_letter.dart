// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #472 / #3587 -- the reminder LETTER of an invoice: rendered once
// ([reminderLetterReport]) and read by two surfaces -- the PDF that is shared
// ([buildReminderPdfFile]) and the on-screen preview of the by-hand queue.
// Moved unchanged out of invoice_documents.dart, which it took under its
// length budget.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_tax_reference/deskilo_tax_reference.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/files/file_names.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/invoice_pdf.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/invoice_report.dart';
import '../domain/report_data_letters.dart';
import 'invoice_document_locale.dart';
import 'invoice_documents.dart'
    show
        developmentMark,
        invoiceDocumentLocale,
        invoicePdfTemplateFor,
        l10nForLanguage,
        resolveMemberReportLanguage;
import 'report_defaults.dart';
import 'report_facts_of.dart';
import 'report_image_resolve.dart';

/// The document language of [invoice]'s customer (#496): their preference
/// → the business's document language → its country's (#3850). The reminder
/// letter resolves it here.
Future<String> customerDocumentLanguage(WidgetRef ref, Invoice invoice) async {
  // #3680 — the language comes from the members as read; a read that did
  // not answer fails the document instead of choosing a language blindly.
  // #3742 — awaited: a read still running is not a failure.
  final members = await ref.read(workspaceMembersProvider.future);
  final member = members.where((m) => m.id == invoice.memberId).firstOrNull;
  final userId = member?.userId;
  final profile = userId == null
      ? null
      : ref.read(memberProfilesProvider).value?[userId];
  return resolveMemberReportLanguage(
    ref,
    memberLocale:
        member?.preferredLocaleOverride ?? profile?.preferredLocale ?? '',
  );
}

/// The reminder letter of [invoice] at [level], rendered (#472): the owner's
/// band set for that level, else the shipped localized default, in the
/// language of the invoice it reminds of (#3850). A broken custom band set
/// falls back to the default: a reminder must never fail on a template.
/// [language] is that language: the e-mail's text is written in it too.
Future<({InvoiceReport report, String title, AppLocalizations l10n, String language})>
reminderLetterReport(
  WidgetRef ref,
  BuildContext context,
  Invoice invoice, {
  required int level,
  required TaxReferenceSet reference,
  ReportBands? draftBands,
}) async {
  // #3850 — a reminder follows the invoice it reminds of: its frozen
  // language and conventions (a legacy invoice: the business's), so the
  // jurisdiction's rule (French in Quebec) holds for its reminders too.
  final locale = invoiceDocumentLocale(ref, invoice);
  final language = locale.language;
  final l10n = l10nForLanguage(language);
  final title = level <= 1
      ? (l10n.reminderPdfTitleFriendly)
      : l10n.reminderPdfTitleLevel(level);
  final data = reminderReportData(
    documentStringsOf(locale),
    reminderFactsOf(ref, invoice),
    invoice,
    level: level,
    reference: reference,
  );
  final template = invoicePdfTemplateFor(ref).forLocale(language);
  final bands = draftBands ?? template.reminderBands(level);
  final fallback = defaultReminderBands(level, l10n);
  final texted = withOwnerTexts(data, template.texts);
  final report =
      (bands == null ? null : renderReportBands(bands: bands, data: texted)) ??
      renderReportBands(bands: fallback, data: texted)!;
  return (report: report, title: title, l10n: l10n, language: language);
}

/// Renders the reminder LETTER for [invoice] at [level] (#472): the
/// owner's band set for that level, else the shipped localized default.
/// A broken custom band set falls back to the default — a reminder must
/// never fail on a template.
Future<({List<int> bytes, String fileName, String title, String language})>
buildReminderPdfFile(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required int level,
  required TaxReferenceSet reference,
  ReportBands? draftBands,
}) async {
  // Read before any await: the context is not used across a gap.
  final mark = developmentMark(context, ref);
  final letter = await reminderLetterReport(
    ref,
    context,
    invoice,
    level: level,
    reference: reference,
    draftBands: draftBands,
  );
  final report = letter.report;
  final title = letter.title;
  final l10n = letter.l10n;
  final pageLabel = l10n.invoicePdfPage;
  Future<pw.Font> font(String asset) async =>
      pw.Font.ttf(await rootBundle.load(asset));
  final bytes = await buildBandedLetterPdf(
    report: report,
    reportImages: await resolveReportImages(ref, report),
    pageLabel: pageLabel,
    documentTitle: '$title ${invoice.number}',
    baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
    watermark: mark,
  );
  return (
    bytes: bytes,
    fileName: '${safeFileSlug('$title ${invoice.number}')}.pdf',
    title: title,
    language: letter.language,
  );
}
