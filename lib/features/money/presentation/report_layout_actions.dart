// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #875 — where a positioned layout takes over from the bands.
//
// Two documents can carry a layout: the invoice (and the proforma that
// borrows it) and every letter document. Both paths do the same three
// things — run the design against the data, fetch the images it names,
// draw it — and both fall back to the bands on a failure, with a trace
// that names the document, the element path and the cause. Kept out of
// invoice_actions.dart, which is at its budget and about the invoice.
import 'dart:typed_data';

import 'package:deskilo_document_model/layout_units.dart';
import 'package:deskilo_document_model/paper.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../../core/country/country_catalog.dart';
import '../../../core/text/collation.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../l10n/app_localizations.dart';
import '../../workspace/domain/workspace_feature.dart';
import '../../workspace/providers/workspace_providers.dart';
import '../domain/address_window.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/pinned_pdf.dart';
import '../domain/report_kind.dart';
import '../domain/report_layout/layout_render.dart';
import '../providers/money_providers.dart';
import 'invoice_documents.dart';
import 'report_layout_defaults.dart';

/// #3852 — how a positioned design is printed this time: the words and
/// marks every page carries, what the document adds to the design, and
/// the paper it is printed on (the design's own page names the paper it
/// was made on).
class LayoutPrint {
  const LayoutPrint({
    required this.documentTitle,
    required this.pageLabel,
    this.watermark = '',
    this.signatureLabel = '',
    this.signature = '',
    this.additionalBody = const [],
    this.lastPage,
    this.paper,
    this.datedAt,
  });

  final String documentTitle;
  final String pageLabel;
  final String watermark;
  final String signatureLabel;
  final String signature;
  final List<pw.Widget> additionalBody;
  final pw.Page? lastPage;

  /// The paper of the document; null prints the design on its own page.
  final Paper? paper;

  /// #3853 — the instant an issued document is dated by: its bytes then
  /// depend on what it says alone, never on when it is rendered. Null for a
  /// document made now.
  final DateTime? datedAt;
}

/// Renders [layoutXml] against [data] into a PDF, printed as [print]
/// says, or returns null after
/// tracing why — the #470 contract that a broken design never blocks a
/// document. [what] names the document in the trace ("INV-2026-0047",
/// "Financial agreement Guilhem"), because a trace that cannot say which
/// document failed is a trace someone has to reproduce.
Future<Uint8List?> tryLayoutPdf({
  required String layoutXml,
  required Map<String, Object?> data,
  required String what,
  required LayoutPrint print,
  required Future<pw.Font> Function(String asset) font,
  Future<Uint8List?> Function(String name)? image,
}) async {
  try {
    final made = renderLayoutDocument(layoutXml, data);
    final paper = print.paper;
    final document = paper == null ? made : made.onPaper(paper);
    final images = <String, Uint8List>{};
    if (image != null) {
      for (final name in layoutDocumentImageNames(document)) {
        final bytes = await image(name);
        if (bytes != null) images[name] = bytes;
      }
    }
    final bytes = await buildLayoutPdf(
      document: document,
      data: data,
      documentTitle: print.documentTitle,
      pageLabel: print.pageLabel,
      images: images,
      watermark: print.watermark,
      signatureLabel: print.signatureLabel,
      signature: print.signature,
      additionalBody: print.additionalBody,
      lastPage: print.lastPage,
      baseFont: await font('assets/fonts/Roboto-Regular.ttf'),
      boldFont: await font('assets/fonts/Roboto-Bold.ttf'),
    );
    final at = print.datedAt;
    return at == null ? bytes : pinnedPdf(bytes, at);
  } on LayoutException catch (e, st) {
    TraceLogger.instance.warn(
      'money',
      'report layout for $what failed at ${e.detail} (${e.error.name}) '
          '— rendering the bands instead',
      error: e.cause ?? e,
      stackTrace: e.stackTrace ?? st,
    );
    return null;
  } on Object catch (e, st) {
    // #874 — an image store or font that cannot be reached must not
    // block a legal document either: the bands still render.
    TraceLogger.instance.warn(
      'money',
      'report layout for $what could not be built — rendering the bands instead',
      error: e,
      stackTrace: st,
    );
    return null;
  }
}

/// #3852 — the paper the business's letters and reports made now are
/// printed on: its own choice, else its country's usual paper.
Paper businessPaperOf(WidgetRef ref) {
  final workspace = ref.read(currentWorkspaceProvider).value;
  return Paper.fromWire(workspace?.paper) ??
      CountryCatalog.byCode(workspace?.countryCode ?? '').paper;
}

/// #4119 -- the paper the document [kindId] is shown and printed on when it
/// is made now: the business's paper where the kind declares it, else null
/// (the design's own).
Paper? kindPaperOf(WidgetRef ref, String kindId, {int reminderLevels = 9}) =>
    reportKindById(kindId, reminderLevels: reminderLevels)
        ?.printedOn(businessPaperOf(ref));

/// The positioned layout for letter [docId] in [language], or null when
/// that document still uses its bands (or the feature is off).
String? letterLayoutXml(
  WidgetRef ref, {
  required String docId,
  String language = '',
  AppLocalizations? l10n,
}) {
  final features = ref.read(enabledFeaturesSyncProvider);
  if (!features.contains(WorkspaceFeature.reportLayouts)) return null;
  // #874 — no design → the letter standard's default for a person-facing kind.
  return resolveLayoutXmlFor(
    template: invoicePdfTemplateFor(ref).forLocale(language),
    kindId: docId,
    countryCode: ref.read(currentWorkspaceProvider).value?.countryCode ?? '',
    letterStandard: features.contains(WorkspaceFeature.letterStandard),
    l10n: l10n,
  );
}

/// The library image named [name], for a layout rendered with a [ref].
Future<Uint8List?> layoutImage(WidgetRef ref, String name) async {
  final exact = await ref.read(reportImageBytesProvider(name).future);
  if (exact != null) return exact;
  // #920 — the SHIPPED layouts ask for an image called `logo`, because a
  // default cannot know what the owner called theirs. Nobody uploads a
  // file named exactly "logo": theirs is "coworking-logo-1-jpg" or
  // whatever the phone produced, so the letter came out without it while
  // the banded template — which references the real name — showed it.
  //
  // So `logo` is a ROLE, not a file name: the library's own logo is the
  // one named after it, else the only image there is. Anything else
  // stays an exact lookup, because a design that names a picture means
  // that picture.
  if (name != _logoRole) return null;
  final names = await ref.read(reportImagesProvider.future);
  final named = names.firstWhere(
    (n) => foldForSearch(n).contains(_logoRole),
    orElse: () => names.length == 1 ? names.first : '',
  );
  if (named.isEmpty) return null;
  return ref.read(reportImageBytesProvider(named).future);
}

/// The name the shipped layouts use for "the workspace's own mark".
const String _logoRole = 'logo';

// #3673 — moved from invoice_documents.dart (its 500-line budget): the
// invoice's positioned layout and envelope window, beside the other layouts.
/// A positioned layout wins over bands. A proforma without a layout of its
/// own borrows the invoice's, as it borrows its bands. Annexes stay banded
/// — they are documentation appended behind, and the layout engine renders
/// one document. Undesigned documents use the enabled letter standard.
String? invoiceLayoutXmlOf(
  Invoice invoice,
  InvoicePdfFileOptions options,
  InvoicePdfTemplate template,
  Set<WorkspaceFeature> features,
  AppLocalizations l10n,
) {
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
    l10n: l10n,
  );
  return options.proforma ? (template.layoutFor('proforma') ?? standard()) : standard();
}

/// #869 — the envelope window: the template's explicit choice wins,
/// otherwise the seller's country decides the side. Off entirely when
/// the workspace has not enabled the feature.
AddressWindow invoiceAddressWindowOf(
  InvoicePdfFileOptions options,
  Set<WorkspaceFeature> features,
) => features.contains(WorkspaceFeature.invoiceAddressWindow)
    ? (options.template.addressWindow ??
          addressWindowForCountry(options.workspace?.countryCode ?? ''))
    : AddressWindow.off;
