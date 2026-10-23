// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1061 / #1048 task 3.2 — DOCUMENT GENERATION: which document, for whom,
// rendered to bytes. Split out of invoice_actions.dart, which keeps the
// dialogs and the actions the buttons run. Nothing here opens a sheet or
// shows a notice; everything here returns a document or a fact about
// one.
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/files/file_names.dart';
import '../../../core/i18n/money_format.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/locale/report_language.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../events/providers/event_providers.dart';
import '../../members/providers/directory_providers.dart';
import '../../plan/providers/accessory_providers.dart';
import '../../plan/providers/floor_plan_providers.dart';
import '../../reservations/providers/reservation_providers.dart';
import '../../workspace/domain/member.dart';
import '../../workspace/domain/workspace.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/address_window.dart';
import '../domain/dunning.dart';
import '../domain/einvoice_input.dart';
import '../domain/invoice.dart';
import '../domain/invoice_cii.dart';
import '../domain/invoice_legal.dart';
import '../domain/invoice_line_text.dart';
import '../domain/invoice_pdf.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/invoice_report.dart';
import '../domain/payment_terms.dart';
import '../domain/report_data.dart';
import '../domain/report_data_letters.dart';
import '../providers/money_providers.dart';
import 'invoice_pdf_file_parts.dart';
import 'invoice_status.dart';
import 'period_label.dart';
import 'report_defaults.dart';
import 'report_facts_of.dart';
import 'report_image_resolve.dart';
import 'report_layout_actions.dart';
import 'report_layout_defaults.dart';
import 'report_strings_l10n.dart';
import 'swiss_qr_page.dart';

export 'letter_doc_pdf.dart';
export 'report_image_resolve.dart' show resolveReportImages;

/// Renders the signed PDF. Every context-derived value is captured BEFORE
/// the first await (use_build_context_synchronously).
/// The active workspace's PDF template (#454) — empty when the
/// invoicePdfTemplate feature is off, so switching the flag off takes
/// the text off every future render without touching the template. A
/// SYNC read: the invoices hub watches the provider, so it is warm
/// before any render action can be tapped.
InvoicePdfTemplate invoicePdfTemplateFor(WidgetRef ref) =>
    ref
        .read(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.invoicePdfTemplate)
    ? ref.read(invoicePdfTemplateProvider).value ?? InvoicePdfTemplate.empty
    : InvoicePdfTemplate.empty;

/// #910 — the day the invoice falls due: the issue date plus the delay
/// the workspace's reminder rules define, which is the same delay the
/// journey counts down (`invoice_journey.dart`). One source, so the
/// document and the app can never state two different deadlines.
///
/// #1913 — the date frozen at issue (`invoice_maturities`) wins, so
/// editing the rules never moves an issued invoice's due date; an
/// invoice from before 0331 keeps the date its document always printed.
DateTime invoiceDueAt(WidgetRef ref, Invoice invoice) =>
    invoice.dueOn ??
    invoice.issuedAt.add(
      Duration(
        days: (ref.read(dunningRulesProvider).value ?? DunningRules.defaults)
            .firstAfterDays,
      ),
    );

/// The l10n bundle of a target DOCUMENT language (#496) — what a
/// letter renders with when its reader's language differs from the UI.
AppLocalizations l10nForLanguage(String language) =>
    lookupAppLocalizations(Locale(language));

/// Resolves a document's language for a reader (#496): member's
/// preferred → workspace language → country language; throws
/// [AmbiguousReportLanguage] for a multi-language country with nothing
/// configured.
String resolveMemberReportLanguage(WidgetRef ref, {String memberLocale = ''}) {
  final workspace = ref.read(currentWorkspaceProvider).value;
  return resolveReportLanguage(
    memberLocale: memberLocale,
    workspaceLocale: workspace?.defaultLocale ?? '',
    countryCode: workspace?.countryCode ?? '',
  );
}

/// Warms every provider the #494 letter-document builders read, so the
/// SYNC data builders see loaded values (the invoice-hub warming idiom).
Future<void> warmLetterDocProviders(WidgetRef ref, String docId) async {
  Future<void> quiet(Future<void> Function() load) async {
    try {
      await load();
    } on Object catch (e, st) {
      TraceLogger.instance.warn(
        'money',
        'letter-doc provider warm failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  await quiet(() => ref.read(invoicePdfTemplateProvider.future));
  if (docId == 'agreement') {
    await quiet(() => ref.read(feeBandsProvider.future));
    await quiet(() => ref.read(servicesProvider.future));
    await quiet(() => ref.read(packagesProvider.future));
    await quiet(() => ref.read(accessoriesProvider().future));
    await quiet(() async {
      final levels = await ref.read(levelsProvider.future);
      for (final level in levels) {
        await ref.read(floorPlanProvider(level.id).future);
      }
    });
  } else if (docId == 'payments') {
    await quiet(() => ref.read(myLedgerProvider.future));
    await quiet(() => ref.read(eventsProvider.future));
  } else if (docId == 'workspace') {
    await quiet(() => ref.read(workspaceMembersProvider.future));
    await quiet(() => ref.read(feeBandsProvider.future));
    await quiet(() => ref.read(servicesProvider.future));
    await quiet(() => ref.read(openWeekdaysProvider.future));
    await quiet(() async {
      final levels = await ref.read(levelsProvider.future);
      for (final level in levels) {
        await ref.read(floorPlanProvider(level.id).future);
      }
    });
  }
  await quiet(() => ref.read(memberNamesProvider.future));
}

/// Renders letter document [docId] through the workspace's template
/// bands (or the shipped default — a broken template never blocks, the
/// #470 contract).
InvoiceReport renderLetterDoc(
  BuildContext context,
  WidgetRef ref, {
  required String docId,
  required Map<String, Object?> data,
  // #496 — the TARGET language; '' renders in the UI language.
  String language = '',
}) {
  final l10n = language.isEmpty
      ? context.l10n
      : l10nForLanguage(language);
  final template = invoicePdfTemplateFor(ref).forLocale(language);
  final bands = template.docBands(docId) ?? defaultBandsForDoc(docId, l10n);
  // #880 — the owner's texts ride beside the data for every document.
  final texted = withOwnerTexts(data, template.texts);
  return (renderReportBands(bands: bands, data: texted) ?? renderReportBands(
      bands: defaultBandsForDoc(docId, l10n), data: texted)!).numberedFor(docId);
}

/// #917 — the word every document of a DEVELOPMENT workspace carries,
/// '' from a real one. One source, so an invoice, a statement, a VAT
/// report and a reminder all say it the same way.
String developmentMark(BuildContext context, WidgetRef ref) =>
    (ref.read(currentWorkspaceProvider).value?.isDevelopment ?? false)
        ? (context.l10n.developmentWatermark)
        : '';

/// What [buildInvoicePdfFile] renders besides the invoice itself.
class InvoicePdfFileOptions {
  const InvoicePdfFileOptions({
    this.proforma = false,
    this.copy = false,
    this.facturXml = '',
    this.colorProfile,
    this.template = InvoicePdfTemplate.empty,
    this.workspace,
    this.reportImage,
    this.settledIn = '',
    this.annexInvoices = const [],
    this.memberTerms,
    this.dueAt,
    this.memberCapacity,
  });

  final bool proforma;
  final bool copy;
  final String facturXml;
  final Uint8List? colorProfile;
  final InvoicePdfTemplate template;
  final Workspace? workspace;

  /// #488 — resolves ![name] references; null renders without images.
  final Future<Uint8List?> Function(String name)? reportImage;

  /// #831 — the stamp of a regrouped source ('' otherwise); the callers
  /// with a ref build it with [settledStampOf].
  final String settledIn;

  /// #837 — the invoices this one regrouped, appended after its own
  /// pages as documentation. The caller resolves them, because only it
  /// holds the archive; each is stamped with this document's number.
  final List<Invoice> annexInvoices;

  /// #881 — the member's own conditions; callers holding a ref pass
  /// memberTermsFor(ref, invoice.memberId).
  final PaymentTerms? memberTerms;

  /// #910 — the settlement date the document must state; callers
  /// holding a ref pass invoiceDueAt(ref, invoice).
  final DateTime? dueAt;

  /// #1916 — an unissued document's customer capacity; callers holding a
  /// ref pass memberCapacityFor(ref, invoice.memberId).
  final String? memberCapacity;
}

/// A positioned layout wins over bands. A proforma without a layout of its
/// own borrows the invoice's, as it borrows its bands. Annexes stay banded
/// — they are documentation appended behind, and the layout engine renders
/// one document. Undesigned documents use the enabled letter standard.
String? _layoutXmlOf(
  BuildContext context,
  Invoice invoice,
  InvoicePdfFileOptions options,
  Set<WorkspaceFeature> features,
) {
  final template = options.template;
  final workspace = options.workspace;
  final letterStandard = features.contains(WorkspaceFeature.letterStandard);
  if (!features.contains(WorkspaceFeature.reportLayouts) ||
      options.annexInvoices.isNotEmpty) {
    return null;
  }
  String? standard() => resolveLayoutXmlFor(
    template: template,
    kindId: 'invoice',
    countryCode: invoice.sellerParty?.country ?? workspace?.countryCode ?? '',
    letterStandard: letterStandard,
    l10n: context.l10n,
  );
  return options.proforma ? (template.layoutFor('proforma') ?? standard()) : standard();
}

/// #869 — the envelope window: the template's explicit choice wins,
/// otherwise the seller's country decides the side. Off entirely when
/// the workspace has not enabled the feature.
AddressWindow _addressWindowOf(
  InvoicePdfFileOptions options,
  Set<WorkspaceFeature> features,
) => features.contains(WorkspaceFeature.invoiceAddressWindow)
    ? (options.template.addressWindow ??
          addressWindowForCountry(options.workspace?.countryCode ?? ''))
    : AddressWindow.off;

Future<pw.Font> _asset(String asset) async =>
    pw.Font.ttf(await rootBundle.load(asset));

Future<({List<int> bytes, String fileName})> buildInvoicePdfFile(
  BuildContext context,
  Invoice invoice, [
  InvoicePdfFileOptions options = const InvoicePdfFileOptions(),
]) async {
  final l10n = context.l10n;
  final proforma = options.proforma;
  final template = options.template;
  final workspace = options.workspace;
  final periodLabel = invoicePeriodLabel(context, invoice);
  final reportData = invoiceReportData(
    reportStringsFor(context),
    invoice,
    memberTerms: options.memberTerms,
    proforma: proforma,
    copy: options.copy,
    workspace: workspace,
    dueAt: options.dueAt,
    memberCapacity: options.memberCapacity,
  );
  // #476: a proforma renders its OWN bands when the owner set them —
  // else the invoice's, as it always did.
  final bands = proforma
      ? (template.proformaBands ?? template.invoiceBands)
      : template.invoiceBands;
  final features = effectiveFeatures(
    resolveEnabledFeatures(workspace?.featureFlags ?? const {}),
  );
  final strings = invoicePdfStringsOf(
    context,
    invoice,
    settledIn: options.settledIn,
    development: workspace?.isDevelopment ?? false,
  );
  // A proforma is named after what it covers — it has no number to be
  // filed under, and must never sit in a folder looking like the invoice.
  final stem = proforma
      ? safeFileSlug(
          '${l10n.invoicePdfProforma} '
          '${invoice.number.isEmpty ? '${invoice.clientName} $periodLabel' : invoice.number}',
        )
      : safeFileSlug(invoice.number);
  final layoutXml = _layoutXmlOf(context, invoice, options, features);
  final dateFormat = DateFormat.yMMMd(
    Localizations.maybeLocaleOf(context)?.toString(),
  );
  final annexes = invoiceAnnexesOf(context, invoice, options.annexInvoices, dateFormat);
  // #2360 — a Swiss seller's invoice ends on the QR-bill its customer pays with.
  final qrPage = await swissQrPageFor(
    l10n,
    invoice,
    workspace?.paymentInstructions ?? const {},
    workspace?.countryCode ?? '',
    proforma: proforma,
    font: _asset,
  );
  if (layoutXml != null) {
    final bytes = await tryLayoutPdf(
      layoutXml: layoutXml,
      data: withOwnerTexts(reportData, template.texts),
      what: invoice.number.isEmpty ? stem : invoice.number,
      documentTitle: '${strings.invoiceTitle} ${invoice.number}',
      pageLabel: strings.page,
      font: _asset,
      image: options.reportImage,
      watermark: invoiceWatermark(
        strings,
        proforma: proforma,
        voided: invoice.isVoided,
        copy: options.copy,
      ),
      signatureLabel: strings.signature,
      signature: proforma ? '' : invoice.signature,
      lastPage: qrPage,
    );
    if (bytes != null) return (bytes: bytes, fileName: '$stem.pdf');
  }
  final report = renderReportBands(bands: bands, data: withOwnerTexts(reportData, template.texts));
  final reportImages = await reportImagesOf(report, options.reportImage);
  final association = InvoiceLegal.fromJson(
    workspace?.invoiceLegal ?? const {},
  ).isAssociation;
  final words = reportStringsOf(l10n);
  final bytes = await buildInvoicePdf(InvoicePdfRequest(
    qrBillPage: qrPage,
    addressWindow: _addressWindowOf(options, features),
    invoice: invoice,
    reportImages: reportImages,
    lineText: (line) => invoiceLineText(words, line,
        association: association, period: invoice.period),
    activityText: (entry) => annexEntryText(words, entry),
    strings: strings,
    money: moneyFormat(invoice.currency).formatMinor,
    dateLabel: dateFormat.format(invoice.issuedAt),
    // The stored title is the raw period ('2026-07'); the document reads
    // the month like a human would.
    periodLabel: periodLabel,
    annexes: annexes,
    proforma: proforma,
    copy: options.copy,
    facturXml: options.facturXml,
    colorProfile: options.colorProfile,
    report: report,
    baseFont: await _asset('assets/fonts/Roboto-Regular.ttf'),
    boldFont: await _asset('assets/fonts/Roboto-Bold.ttf'),
  ));
  return (bytes: bytes, fileName: '$stem.pdf');
}

/// FACTUR-X: one PDF that carries the EN 16931 invoice inside it (as CII,
/// the syntax the format mandates). A human opens it and sees the invoice;
/// a platform opens it and finds `factur-x.xml`. This is what French and
/// German small businesses actually hand to their platform.
Future<({List<int> bytes, String fileName})> buildFacturXFile(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required InvoiceParty seller,
  required InvoiceParty buyer,
  required String iban,
}) async {
  final association = ref.read(sellerIsAssociationProvider);
  final words = reportStringsOf(context.l10n);
  final xml = buildInvoiceCii(EInvoiceInput(invoice: invoice,
    seller: seller,
    buyer: buyer,
    iban: iban,
    lineText: (line) => invoiceLineText(words, line,
        association: association, period: invoice.period),
    // #941 — the same due date and terms the PDF prints.
    dueDate: invoiceDueAt(ref, invoice),
    // #1916 — an issued invoice states the terms frozen with it.
    paymentTerms: invoice.legalClauses?.clauses.paymentTerms ??
        memberTermsFor(ref, invoice.memberId)?.paymentTerms ??
        ''));
  // PDF/A-3 cannot exist without an embedded output intent.
  final icc = await rootBundle.load('assets/pdf/sRGB2014.icc');
  if (!context.mounted) {
    return (bytes: const <int>[], fileName: '');
  }
  final pdf = await buildInvoicePdfFile(
    context,
    invoice,
    InvoicePdfFileOptions(
      // #920 — through layoutImage, so the shipped layouts' `logo`
      // resolves to whatever the owner actually called theirs.
      reportImage: (String name) => layoutImage(ref, name),
      memberTerms: memberTermsFor(ref, invoice.memberId),
    dueAt: invoiceDueAt(ref, invoice),
    copy: rendersCopy(ref),
    settledIn: settledStampOf(context, ref, invoice),
    facturXml: xml,
    colorProfile: icc.buffer.asUint8List(),
    template: invoicePdfTemplateFor(ref),
    workspace: ref.read(currentWorkspaceProvider).value));
  return (
    bytes: pdf.bytes,
    fileName: '${safeFileSlug('facturx ${invoice.number}')}.pdf',
  );
}

/// Whether THIS viewer renders a copy: only an issuer (owner, or an admin
/// with the delegation) holds the original. A member downloading their own
/// invoice gets a document stamped as the duplicate it is.
bool rendersCopy(WidgetRef ref) {
  final me = ref.read(myMemberProvider).value;
  if (me == null) return true;
  return !(me.actsAsOwner || me.canAdminister);
}

/// Records a payment reminder (0066) and hands the invoice PDF to the share
/// sheet with a localized reminder message — mail, WhatsApp, whatever the
/// device offers.
/// Renders the reminder LETTER for [invoice] at [level] (#472): the
/// owner's band set for that level, else the shipped localized default.
/// A broken custom band set falls back to the default — a reminder must
/// never fail on a template.
Future<({List<int> bytes, String fileName, String title})> buildReminderPdfFile(
  BuildContext context,
  WidgetRef ref,
  Invoice invoice, {
  required int level,
  ReportBands? draftBands,
}) async {
  // #496 — the reminder letter prints in the MEMBER's language (their
  // preference → workspace language → country language).
  var language = '';
  try {
    final members =
        ref.read(workspaceMembersProvider).value ?? const <Member>[];
    final member = members.where((m) => m.id == invoice.memberId).firstOrNull;
    final userId = member?.userId;
    final profile = userId == null
        ? null
        : ref.read(memberProfilesProvider).value?[userId];
    language = resolveMemberReportLanguage(
      ref,
      memberLocale: member?.preferredLocaleOverride ?? profile?.preferredLocale ?? '',
    );
  } on AmbiguousReportLanguage {
    language = '';
  }
  final l10n = language.isEmpty
      ? context.l10n
      : l10nForLanguage(language);
  final title = level <= 1
      ? (l10n.reminderPdfTitleFriendly)
      : '${l10n.reminderPdfTitleFirm} $level';
  final data = reminderReportData(
    reportStringsFor(context,
        l10n: l10n, localeName: language.isEmpty ? null : language),
    reminderFactsOf(ref, invoice),
    invoice,
    level: level,
  );
  final template = invoicePdfTemplateFor(ref).forLocale(language);
  final bands = draftBands ?? template.reminderBands(level);
  final fallback = defaultReminderBands(level, l10n);
  final texted = withOwnerTexts(data, template.texts);
  final report =
      (bands == null ? null : renderReportBands(bands: bands, data: texted)) ??
      renderReportBands(bands: fallback, data: texted)!;
  final pageLabel = l10n.invoicePdfPage;
  final mark = developmentMark(context, ref);
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
  );
}

/// #831 — the watermark of a regrouped source: "Regrouped in INV-…", or
/// '' for every other document.
String settledStampOf(BuildContext context, WidgetRef ref, Invoice invoice) {
  if (!invoice.isFolded) return '';
  final l10n = context.l10n;
  final number = settledByNumberOf(
    invoice,
    ref.read(invoicesProvider).value ?? const [],
  );
  return l10n.invoicePdfSettledIn(number);
}

/// #837 — the invoices [invoice] regrouped, resolved from the archive in
/// the order its own snapshot lists them. Empty when it regroups
/// nothing, or when the archive has not loaded them.
List<Invoice> regroupedSourcesOf(WidgetRef ref, Invoice invoice) {
  if (invoice.settles.isEmpty) return const [];
  final all = ref.read(invoicesProvider).value ?? const <Invoice>[];
  return [
    for (final source in invoice.settles)
      ...all.where((i) => i.id == source.invoiceId),
  ];
}

/// #881 — the member's own payment conditions, from the members list
/// already loaded; null when they inherit the workspace's.
/// #1916 — the member's stated customer capacity (wire), null when not
/// stated or unknown here.
String? memberCapacityFor(WidgetRef ref, String memberId) => ref
    .read(workspaceMembersProvider)
    .value
    ?.where((m) => m.id == memberId)
    .firstOrNull
    ?.customerCapacity;

PaymentTerms? memberTermsFor(WidgetRef ref, String memberId) => ref
    .read(workspaceMembersProvider)
    .value
    ?.where((m) => m.id == memberId)
    .firstOrNull
    ?.paymentTerms;
