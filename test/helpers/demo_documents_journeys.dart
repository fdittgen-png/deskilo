// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3964 (b) — the documents and reports of the reference business: what the
// owner saved, what an issued Demo invoice prints with, and the figures that
// must agree between the pages, the workbook and the data report. Rendering
// uses the report engine itself (the bands, the positioned layout and the
// sheet's own millimetre reader), no golden files.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/demo/seed/demo_purchase_seed.dart';
import 'package:deskilo/core/l10n/context_l10n.dart';
import 'package:deskilo/core/vat/tax_reference_active.dart';
import 'package:deskilo/features/money/domain/invoice_line_text.dart';
import 'package:deskilo/features/money/domain/invoice_pdf.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:deskilo/features/money/domain/invoice_report.dart';
import 'package:deskilo/features/money/domain/report_data.dart';
import 'package:deskilo/features/money/domain/report_design_file.dart';
import 'package:deskilo/features/money/domain/report_kind.dart';
import 'package:deskilo/features/money/domain/report_layout/layout_render.dart';
import 'package:deskilo/features/money/domain/report_layout_file.dart';
import 'package:deskilo/features/money/domain/report_letter_layouts.dart';
import 'package:deskilo/features/money/presentation/invoice_documents.dart';
import 'package:deskilo/features/money/presentation/report_layout_actions.dart';
import 'package:deskilo/features/money/presentation/report_sample_data.dart';
import 'package:deskilo/features/money/presentation/report_strings_l10n.dart';
import 'package:deskilo/features/workspace/domain/workspace_data_report.dart';
import 'package:deskilo/features/workspace/domain/workspace_data_report_builder.dart';
import 'package:deskilo/features/workspace/domain/workspace_excel.dart';
import 'package:deskilo/features/workspace/domain/workspace_feature.dart';
import 'package:deskilo/l10n/app_localizations_fr.dart';
import 'package:deskilo_document_model/deskilo_document_model.dart';
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_xlsx/deskilo_xlsx.dart';
import 'package:pdf/widgets.dart' as pw;

import 'demo_plan_booking_journeys.dart' show allHold;
import 'pdf_geometry.dart';

pw.Font _ttf(String path) =>
    pw.Font.ttf(File(path).readAsBytesSync().buffer.asByteData());

/// The text of the blocks of a rendered band, one line each.
String plain(List<Object?> blocks) => [
  for (final b in blocks)
    switch (b) {
      ReportHeading(:final text) ||
      ReportSubheading(:final text) ||
      ReportText(:final text) ||
      ReportMuted(:final text) => text,
      ReportTableRow(:final cells) => cells.join(' | '),
      _ => '',
    },
].join('\n');

/// The saved template of the reference business, and an issued invoice
/// printed with it, in the language it was issued in (French) and in euros.
Future<
  ({
    InvoicePdfTemplate template,
    InvoiceReport report,
    DemoFixture f,
    Map<String, Object?> data,
  })
>
_printed() async {
  final f = DemoFixture.build();
  final template = await f.money.fetchInvoicePdfTemplate('ws-1');
  final invoice = f.money.invoices.firstWhere(
    (i) => i.id == 'demo-invoice-bruno',
  );
  final workspace = f.workspaces.workspaces.firstWhere((w) => w.id == 'ws-1');
  final strings = reportStringsOf(
    AppLocalizationsFr(),
    dateLocale: 'fr',
    formatLocale: null,
  );
  final data = withOwnerTexts(
    invoiceReportData(
      strings,
      invoice,
      reference: ActiveTaxReference.current,
      proforma: false,
      copy: false,
      workspace: workspace,
    ),
    template.texts,
  );
  final report = renderReportBands(
    bands: ReportBands(
      header: template.header,
      body: template.body,
      footer: template.footer,
    ),
    data: data,
  )!;
  return (template: template, report: report, f: f, data: data);
}

/// An issued Demo invoice prints with the owner's template: the letterhead,
/// its own lines and its footer, in euros.
Future<bool> invoiceTemplateState() async {
  final p = await _printed();
  final invoice = p.f.money.invoices.firstWhere(
    (i) => i.id == 'demo-invoice-bruno',
  );
  final all =
      '${plain(p.report.header)}\n${plain(p.report.body)}\n${plain(p.report.footer)}';
  return allHold({
    'the letterhead names the business': plain(p.report.header)
        .contains('Atelier du Marché'),
    'the body carries the number': plain(p.report.body)
        .contains(invoice.number),
    'the body names the customer': plain(p.report.body)
        .contains(invoice.memberName),
    'in euros': invoice.currency == 'EUR' && all.contains('€'),
    'the footer is the owner\'s text': plain(p.report.footer)
        .contains(p.template.texts['thanks']!),
  });
}

/// The owner changes a text of the report: the saved template carries it and
/// the rendered footer reads it.
Future<bool> reportTextAction() async {
  final p = await _printed();
  const changed = 'À bientôt à l\'Atelier.';
  await p.f.money.setInvoicePdfTemplate(
    'ws-1',
    InvoicePdfTemplate(
      header: p.template.header,
      body: p.template.body,
      footer: p.template.footer,
      addressWindow: p.template.addressWindow,
      layouts: p.template.layouts,
      texts: {...p.template.texts, 'thanks': changed},
    ),
  );
  final saved = await p.f.money.fetchInvoicePdfTemplate('ws-1');
  final report = renderReportBands(
    bands: ReportBands(
      header: saved.header,
      body: saved.body,
      footer: saved.footer,
    ),
    data: {...p.data, 'text': OwnerTexts(saved.texts)},
  )!;
  return allHold({
    'it was the thank-you': plain(p.report.footer)
        .contains(p.template.texts['thanks']!),
    'the saved template carries the change': saved.texts['thanks'] == changed,
    'the footer reads it': plain(report.footer).contains(changed),
    'the old text is gone': !plain(report.footer)
        .contains(p.template.texts['thanks']!),
  });
}

/// The designer opens the design, a line is edited and saved; the saved design
/// still renders, and the rendered body shows the edit.
Future<bool> designerEditAction() async {
  final p = await _printed();
  final opened = await p.f.money.fetchInvoicePdfTemplate('ws-1');
  final edited = opened.body.replaceFirst('Total :', 'Total TTC :');
  final bands = ReportBands(
    header: opened.header,
    body: edited,
    footer: opened.footer,
  );
  final error = reportBandsError(bands: bands, data: p.data);
  await p.f.money.setInvoicePdfTemplate(
    'ws-1',
    InvoicePdfTemplate(
      header: bands.header,
      body: bands.body,
      footer: bands.footer,
      addressWindow: opened.addressWindow,
      layouts: opened.layouts,
      texts: opened.texts,
    ),
  );
  final saved = await p.f.money.fetchInvoicePdfTemplate('ws-1');
  final rendered = renderReportBands(
    bands: ReportBands(
      header: saved.header,
      body: saved.body,
      footer: saved.footer,
    ),
    data: p.data,
  )!;
  return allHold({
    'the edit changed a line': edited != opened.body,
    'the design is sound': error == null,
    'saved': saved.body == edited,
    'the document shows it': plain(rendered.body).contains('Total TTC :'),
    'the letterhead is untouched': saved.header == opened.header,
  });
}

/// The positioned layout saved for the usage statement is the one that
/// prints for it; another kind keeps the built-in, and the layout renders.
Future<bool> layoutState() async {
  final p = await _printed();
  final saved = resolveLayoutXml(
    template: p.template,
    kindId: 'usage',
    letterStandard: false,
  );
  final other = resolveLayoutXml(
    template: p.template,
    kindId: 'statement',
    letterStandard: false,
  );
  final data = {...sampleReportData(englishL10n), ...p.data};
  final document = renderLayoutDocument(saved!, data);
  final bytes = await buildLayoutPdf(
    document: document,
    data: data,
    documentTitle: 'usage',
    pageLabel: 'Page',
    baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
    boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
  );
  return allHold({
    'a layout is saved for the usage statement': p.template.layouts.containsKey(
      'usage',
    ),
    'it is the one that prints': saved == p.template.layouts['usage'],
    'another kind has none': other == null,
    'it prints ink on the first page': textPositions(bytes)
        .any((i) => i.page == 1),
  });
}

/// The design leaves as its exchange file and comes back equal, and so does
/// the positioned layout.
Future<bool> exchangeAction() async {
  final p = await _printed();
  const invoice = ReportKind(id: 'invoice', slot: ReportRootSlot());
  final bands = ReportBands(
    header: p.template.header,
    body: p.template.body,
    footer: p.template.footer,
  );
  final file = buildReportDesignFile(
    kind: invoice,
    language: 'fr',
    workspaceName: 'Atelier du Marché',
    bands: bands,
    exportedAt: p.f.seededAt,
  );
  final back = parseReportDesignFile(file, expectedKind: invoice);
  final layoutFile = buildReportLayoutFile(
    kind: reportKindById('usage')!,
    language: '',
    workspaceName: 'Atelier du Marché',
    layoutXml: p.template.layouts['usage']!,
    exportedAt: p.f.seededAt,
    texts: p.template.texts,
  );
  final layoutBack = parseReportLayoutFile(
    layoutFile,
    expectedKind: reportKindById('usage'),
  );
  return allHold({
    'the design file is JSON': jsonDecode(file) is Map,
    'back with its header': back.bands.header == bands.header,
    'back with its body': back.bands.body == bands.body,
    'back with its footer': back.bands.footer == bands.footer,
    'back in French': back.language == 'fr',
    'the layout comes back for its kind': layoutBack.kindId == 'usage',
    'the layout comes back with the owner\'s texts':
        layoutBack.texts['thanks'] == p.template.texts['thanks'],
    'the layout still renders': renderLayoutDocument(layoutBack.layoutXml, {
      ...sampleReportData(englishL10n),
      ...p.data,
    }).toString().isNotEmpty,
  });
}

/// The letter the Demo prints: the recipient sits in the window of the
/// envelope (the sheet's own millimetre reader), on A4, with the footer;
/// and the New York house's invoice, on Letter, has its recipient in the
/// #10 window's field (#3981).
Future<bool> addressWindowState() async {
  final p = await _printed();
  final window = p.template.addressWindow ?? AddressWindow.off;
  final xml = defaultLetterLayoutXml(
    'invoice',
    const LetterStrings(),
    window: window,
  );
  final profile = p.f.profiles.profiles.firstWhere(
    (x) => x.displayName == 'Bruno Kessler',
  );
  final data = {
    ...sampleReportData(englishL10n),
    ...p.data,
    'client_name': 'Bruno Kessler',
    'client_address': profile.address.isEmpty
        ? 'Rue du Marché\n34120 Pézenas'
        : profile.address,
  };
  final bytes = await buildLayoutPdf(
    document: renderLayoutDocument(xml, data),
    data: data,
    documentTitle: 'invoice',
    pageLabel: 'Page',
    baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
    boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
  );
  final page1 = textPositions(bytes).where((i) => i.page == 1).toList();
  final inWindow = page1
      .where((i) => i.xMm >= 100 && i.yMm >= 40 && i.yMm <= 90)
      .toList();
  final ny = await _newYorkInvoice(p.f);
  return allHold({
    'the New York invoice is on Letter': ny.paper == Paper.letter,
    'on the banded engine, which the app picks for it': !ny.positioned,
    'its recipient is in the field, nothing else from 50 to 93 mm': ny.inField,
    'the window is the owner\'s':
        p.template.addressWindow == AddressWindow.right,
    'on A4 the window holds': window == AddressWindow.right,
    'a recipient in the window': inWindow.isNotEmpty,
    'right of the left edge': inWindow.every((i) => i.xMm >= 109.5),
    'inside the field': inWindow.every((i) => i.yMm >= 44.5 && i.yMm <= 85),
    'nothing else beside the aperture': page1
        .where((i) => i.xMm < 100 && i.yMm > 45 && i.yMm < 89.5)
        .isEmpty,
  });
}

/// What the New York house's first invoice prints, the way the app prints
/// it: the engine the app picks for it (the banded sheet, as the Demo's
/// New York space has no layout design and the positioned engine is used
/// only when `invoiceLayoutXmlOf` yields one), on the
/// paper frozen on the invoice; `inField` says the first page's ink between
/// 50 and 93 mm is all inside the field.
Future<({bool positioned, Paper paper, bool inField})>
_newYorkInvoice(DemoFixture f) async {
  final invoice = f.newYork.money.invoices.firstWhere(
    (i) => i.workspaceId == demoNewYorkSpaceId,
  );
  final workspace = f.workspaces.workspaces.firstWhere(
    (w) => w.id == demoNewYorkSpaceId,
  );
  final template = await f.newYork.money.fetchInvoicePdfTemplate(
    demoNewYorkSpaceId,
  );
  final options = InvoicePdfFileOptions(
    reference: ActiveTaxReference.current,
    template: template,
    workspace: workspace,
  );
  final features = effectiveFeatures(
    resolveEnabledFeatures(workspace.featureFlags),
  );
  final paper = Paper.fromWire(invoice.paper) ?? Paper.a4;
  final layoutXml = invoiceLayoutXmlOf(
    invoice,
    options,
    template,
    features,
    englishL10n,
  );
  final window = invoiceAddressWindowOf(options, features);
  final Uint8List bytes;
  if (layoutXml == null) {
    bytes = await buildInvoicePdf(
      InvoicePdfRequest(
        invoice: invoice,
        strings: const InvoicePdfStrings(
          invoiceTitle: 'Invoice',
          issuedOn: 'Issued on',
          issuedBy: 'Issued by',
          billedTo: 'Billed to',
          total: 'Total',
          signature: 'Digital signature',
          voided: '',
          voidedWatermark: 'Voided',
          proforma: 'Proforma',
          replaces: 'Replaces',
          description: 'Description',
          charges: 'Charges',
          payments: 'Payments',
          annex: 'Annex',
          attendance: 'Attendance',
          activity: 'Bookings',
          reserved: 'reserved',
          page: 'Page',
        ),
        addressWindow: window,
        paper: paper,
        money: (int cents) => '${cents / 100}',
        lineText: (InvoiceLine line) => invoiceLineText(const ReportStrings(), line),
        activityText: (InvoiceDetailEntry e) => annexEntryText(const ReportStrings(), e),
        dateLabel: '',
        baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
        boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
      ),
    );
  } else {
    final data = invoiceReportData(
      reportStringsOf(englishL10n, dateLocale: 'en', formatLocale: null),
      invoice,
      reference: ActiveTaxReference.current,
      proforma: false,
      copy: false,
      workspace: workspace,
    );
    bytes = await buildLayoutPdf(
      document: renderLayoutDocument(layoutXml, data).onPaper(paper),
      data: data,
      documentTitle: 'invoice',
      pageLabel: 'Page',
      baseFont: _ttf('assets/fonts/Roboto-Regular.ttf'),
      boldFont: _ttf('assets/fonts/Roboto-Bold.ttf'),
    );
  }
  final field = window.fieldOn(paper);
  final band = textPositions(bytes, paper: paper)
      .where(
        (i) => i.page == 1 && i.yMm > field.senderLimitMm && i.yMm < field.flowResumeMm,
      )
      .toList();
  final inField = band
      .where(
        (i) => i.yMm >= field.topMm - 0.5 && i.yMm <= field.bottomMm && i.xMm >= field.leftMm - 0.5,
      )
      .toList();
  return (
    positioned: layoutXml != null,
    paper: paper,
    inField: inField.isNotEmpty && inField.length == band.length,
  );
}

/// The letter standard: a person-facing kind without a design of its own is
/// printed on the standard letter, a designed kind keeps its design.
Future<bool> letterStandardState() async {
  final p = await _printed();
  final standard = resolveLayoutXml(
    template: p.template,
    kindId: 'statement',
    letterStandard: true,
  );
  final designed = resolveLayoutXml(
    template: p.template,
    kindId: 'usage',
    letterStandard: true,
  );
  final account = resolveLayoutXml(
    template: p.template,
    kindId: 'coa',
    letterStandard: true,
  );
  return allHold({
    'a statement is on the standard letter':
        standard != null && standard.contains('<recipient window='),
    'a designed kind keeps its design': designed == p.template.layouts['usage'],
    'a chart of accounts is not a letter': account == null,
  });
}

/// The whole space as a workbook, written from the Demo's own rows: the file
/// is a real archive and its Invoices sheet holds the Demo's invoices, with
/// their currency.
Future<bool> dataExportAction() async {
  final x = await _dataRows();
  final bytes = buildXlsx(x.workbook);
  final sheet = x.workbook.firstWhere((s) => s.name == 'Invoices');
  return allHold({
    'a zip archive': bytes.length > 4 && bytes[0] == 0x50 && bytes[1] == 0x4b,
    'every invoice is a row': sheet.rows.length - 1 == x.invoiceCount,
    'the Demo has invoices': x.invoiceCount > 0,
    'the users are rows':
        x.workbook.firstWhere((s) => s.name == 'Users').rows.length > 1,
  });
}

/// The data report is built from the same rows: every section holds records,
/// and its invoice register counts the invoices the workbook counts.
Future<bool> dataReportState() async {
  final x = await _dataRows();
  final report = x.report;
  return allHold({
    'members': report.table('members').rows.isNotEmpty,
    'bookings': report.table('bookings').rows.isNotEmpty,
    'invoices': report.table('invoices').rows.isNotEmpty,
    'payments': report.table('payments').rows.isNotEmpty,
    'in euros': report.currency == 'EUR',
    'the register counts the workbook\'s invoices':
        report.table('invoices').rows.length == x.invoiceCount,
  });
}

Future<
  ({List<XlsxSheet> workbook, WorkspaceDataReport report, int invoiceCount})
>
_dataRows() async {
  final f = DemoFixture.build(now: DateTime(2026, 10, 14, 10));
  final ws = f.workspaces.workspaces.first;
  final levels = await f.floorPlan.fetchLevels(ws.id);
  final plans = {
    for (final l in levels) l.id: await f.floorPlan.fetchPlan(l.id),
  };
  final members = await f.workspaces.fetchMembers(ws.id);
  final reservations = await f.reservations.fetchAllForExport(ws.id);
  final ledger = await f.money.fetchWorkspaceLedger(ws.id);
  final invoices = await f.money.fetchInvoices(ws.id);
  final buying = seedDemoPurchasing(DateTime(2026, 10, 14, 10), money: f.money);
  final details = WorkspaceExportDetails(
    workspace: ws,
    levels: levels,
    plansByLevel: plans,
    memberName: f.workspaces.memberNames,
    ledger: ledger,
    events: const [],
    decisions: const {},
    invoices: invoices,
    members: members,
    reservations: reservations,
    invoiceMatches: await f.money.fetchInvoiceMatches(ws.id),
  );
  final workbook = [
    ...buildWorkspaceExcelExport(
      workspace: ws,
      enabledFeatures: const {},
      levels: levels,
      plansByLevel: plans,
      members: members,
      profilesByUserId: const {},
      reservations: reservations,
      ledger: ledger,
      pendingEvents: const [],
      paymentIntents: const [],
      services: const [],
      invoices: invoices,
      transmissionsByInvoice: const {},
    ),
    ...buildWorkspaceExcelDetailSheets(details),
  ];
  final report = buildWorkspaceDataReport(
    details,
    purchases: [
      for (final p in await buying.purchases.fetchPurchases(ws.id))
        (
          date: p.originalDate ?? p.receivedOn,
          reference: p.reference,
          kind: p.kind.wire,
          state: p.state.name,
          category: p.category,
          grossCents: p.grossCents,
        ),
    ],
  );
  return (workbook: workbook, report: report, invoiceCount: invoices.length);
}
