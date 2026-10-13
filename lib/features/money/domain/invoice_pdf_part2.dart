// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoice_pdf.dart';

/// #837 — ONE invoice's sheets. Used for the document itself and then once
/// per appended reference, so every annex starts on a fresh page and can
/// never overlap the pages before it. One method per part of the sheet.
class _InvoiceSheet {
  _InvoiceSheet(
    this.request,
    this.theme, {
    required this.invoice,
    required this.proforma,
    required this.copy,
    required this.report,
    required this.dateLabel,
    required this.periodLabel,
    this.watermarkOverride,
    // #869 — only the sheet that goes in the envelope carries the
    // address window; an annex is documentation behind it.
    this.primary = false,
  });

  final InvoicePdfRequest request;
  final pw.ThemeData theme;
  final Invoice invoice;
  final bool proforma;
  final bool copy;
  final InvoiceReport? report;
  final String dateLabel;
  final String periodLabel;
  final String? watermarkOverride;
  final bool primary;

  InvoicePdfStrings get strings => request.strings;
  AddressWindow get addressWindow => request.addressWindow;
  Map<String, Uint8List> get reportImages => request.reportImages;
  String Function(int cents) get money => request.money;
  String Function(InvoiceLine line) get lineText => request.lineText;
  String Function(InvoiceDetailEntry entry) get activityText =>
      request.activityText;

  bool get windowOn => primary && addressWindow.isOn;
  String get numberLine => proforma
      ? (invoice.number.isEmpty
          ? strings.proforma
          : '${strings.proforma} · ${invoice.number}')
      : '${strings.invoiceTitle} ${invoice.number}';
  String get issuedOnLine => '${strings.issuedOn} $dateLabel';
  String get issuedByLine => '${strings.issuedBy} ${invoice.issuerName}';
  String get replacesLine => '${strings.replaces} ${invoice.replacesNumber}';

  int get chargesCents => invoice.lines
      .where((l) => l.amountCents > 0)
      .fold(0, (sum, l) => sum + l.amountCents);
  int get paymentsCents => invoice.lines
      .where((l) => l.amountCents < 0)
      .fold(0, (sum, l) => sum + l.amountCents);
  // The VAT contained in the charges (0072). Prices are VAT-inclusive, so
  // the breakdown EXPLAINS the total rather than adding to it — which is
  // why the net sits above the charges line, not beside it.
  List<InvoiceVatTotal> get vatTotals =>
      invoice.vatTotals.where((t) => t.vatCents > 0).toList();
  bool get showVat => vatTotals.isNotEmpty;

  /// '20 %', '5.5 %' — beside the caption, so one row reads 'VAT 20 %'.
  String ratePercent(double percent) =>
      '${percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent} %';

  late final List<pw.Widget> headerWidgets = _headerWidgets();
  late final List<pw.Widget> windowHeaderWidgets = _windowHeaderWidgets();
  late final List<pw.Widget> footerWidgets = _footerWidgets();
  late final pw.Widget continuationHeader = _continuationHeader();
  late final pw.Widget windowRecipient = addressWindowRecipient(
      name: invoice.clientName, address: invoice.memberAddress);

  // An erroneous invoice must be unmistakable even at arm's length, or
  // photocopied, or seen upside down on someone's desk (0071): the word
  // runs across the whole sheet, diagonally, BEHIND the content — every
  // page of it, annex included.
  // #837 — an appended reference carries the stamp that says where it
  // went; everything else follows the document's own state.
  // #917 — the development mark is absolute: even an appended annex,
  // which normally carries the stamp saying where it went, is first of
  // all a page that is not real.
  late final String watermark = _stamp();
  // Its size follows its LENGTH: 'ERRATA' and 'FEHLERHAFT' must both land
  // inside the sheet. (The package's own Watermark scales to the rotated
  // bounding box it computes, which runs the ends off the corners.)
  late final double markSize =
      math.min(120.0, 820 / math.max(watermark.length, 1));

  String _stamp() =>strings.development.isNotEmpty
        ? strings.development.toUpperCase()
        : watermarkOverride ??
            invoiceWatermark(
              strings,
              proforma: proforma,
              voided: invoice.isVoided,
              copy: copy,
            );

  /// #470: the header band replaces the letterhead wholesale.
  List<pw.Widget> _headerWidgets() {
    final report = this.report;
    return report == null
        ? <pw.Widget>[
          // ── Letterhead ────────────────────────────────────────────
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(invoice.workspaceName,
                        style: pw.TextStyle(
                            fontSize: 20,
                            fontWeight: pw.FontWeight.bold,
                            color: _ink)),
                    if (invoice.workspaceAddress.isNotEmpty)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 3),
                        child: pw.Text(invoice.workspaceAddress,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                      ),
                  ],
                ),
              ),
              // #873 — with a window envelope the identification block
              // does NOT sit up here: the spec puts it under the sender
              // at 90 mm, so it is the first thing in the flow instead.
              if (windowOn)
                pw.SizedBox()
              else
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Text(numberLine,
                      style: pw.TextStyle(
                          fontSize: 14,
                          fontWeight: pw.FontWeight.bold,
                          color: _accent)),
                  pw.SizedBox(height: 3),
                  pw.Text(issuedOnLine,
                      style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  pw.Text(issuedByLine,
                      style: const pw.TextStyle(fontSize: 9, color: _muted)),
                  if (invoice.replacesNumber.isNotEmpty)
                    pw.Text(replacesLine,
                        style:
                            const pw.TextStyle(fontSize: 9, color: _muted)),
                ],
              ),
            ],
          ),
          pw.Container(
              margin: const pw.EdgeInsets.symmetric(vertical: 14),
              height: 2,
              color: _accent),
        ]
        : reportBlockWidgets(report.header, images: reportImages);
  }

  /// #923 — inside the envelope's 25 mm sender band a picture the design
  /// did not size gets a ceiling, so the letterhead fits instead of
  /// being cut off at the top where the logo lives.
  List<pw.Widget> _windowHeaderWidgets() {
    final report = this.report;
    return report == null
        ? headerWidgets
        : reportBlockWidgets(report.header,
            images: reportImages, maxImageHeight: senderLogoMaxHeight);
  }

  List<pw.Widget> _footerWidgets() {
    final report = this.report;
    return report == null
        ? const <pw.Widget>[]
        : reportBlockWidgets(report.footer, images: reportImages);
  }

  /// #872 — what a page 2 says when the design does not say it: the
  /// document's own title and number over a hairline. Enough to pair a
  /// loose sheet with the invoice it belongs to, and nothing more.
  pw.Widget _continuationHeader() {
    final report = this.report;
    return report != null &&
            report.continuation.isNotEmpty
        ? pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
            children: reportBlockWidgets(report.continuation,
                images: reportImages),
          )
        : pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 12),
            padding: const pw.EdgeInsets.only(bottom: 4),
            decoration: const pw.BoxDecoration(
              border: pw.Border(bottom: pw.BorderSide(color: _hairline)),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(invoice.workspaceName,
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
                pw.Text(numberLine,
                    style: const pw.TextStyle(fontSize: 8, color: _muted)),
              ],
            ),
          );
  }

    pw.Widget label(String text) => pw.Text(text,
        style: pw.TextStyle(
            fontSize: 8,
            color: _muted,
            fontWeight: pw.FontWeight.bold,
            letterSpacing: 1.2));

    pw.Widget amountCell(int cents, {bool bold = false}) => pw.Padding(
          padding: const pw.EdgeInsets.symmetric(vertical: 5, horizontal: 8),
          child: pw.Text(money(cents),
              textAlign: pw.TextAlign.right,
              style: pw.TextStyle(
                  fontSize: 10,
                  color: cents < 0 ? _accent : _ink,
                  fontWeight:
                      bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        );

  /// Adds this invoice's sheet to [doc].
  void addTo(pw.Document doc) {
    doc.addPage(
      pw.MultiPage(
        pageTheme: _pageTheme(),
        // #872 — the letterhead is page furniture, not flow: page one
        // carries it (and reserves the envelope window under it), every
        // later page carries the short strip that says which document
        // this is instead of repeating an address block nobody rereads.
        header: _header,
        // #872 — and the footer is pinned to EVERY page, so the terms,
        // the account to pay into and the page number are on whichever
        // sheet the reader is holding.
        footer: (context) => reportPageFooter(context,
            content: footerWidgets, pageLabel: strings.page),
        build: _body,
      ),
    );
  }

  pw.PageTheme _pageTheme() => pw.PageTheme(
          pageFormat: PdfPageFormat.a4,
          theme: theme,
          // #873 — 20 mm all round: the sender block sits at 20 mm
          // from the top and left edges, which the spec fixes.
          margin: const pw.EdgeInsets.all(pageMargin),
          buildBackground: !windowOn
              ? null
              : (context) => addressWindowBackground(
                    addressWindow,
                    pageNumber: context.pageNumber,
                    child: windowRecipient,
                  ),
          buildForeground: watermark.isEmpty
              ? null
              : (context) => pw.FullPage(
                    ignoreMargins: true,
                    child: pw.Opacity(
                      opacity: _watermarkOpacity,
                      child: pw.Center(
                        child: pw.Transform.rotate(
                          angle: math.pi / 4,
                          child: pw.Text(
                            watermark,
                            style: pw.TextStyle(
                              fontSize: markSize,
                              color: _watermark,
                              fontWeight: pw.FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
        );

  pw.Widget _header(pw.Context context) => context.pageNumber == 1
            ? pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                children: [
                  if (windowOn)
                    // The sender block owns 20 mm → 45 mm, and the flow
                    // resumes at 90 mm: below the 85 × 40 mm aperture
                    // AND below the tolerance band under it.
                    //
                    // #923 — 25 mm is not much, and a letterhead with a
                    // LOGO in it is taller than that. Left to overflow,
                    // the column was clipped and the logo — the first
                    // thing in the band — vanished, while the text lines
                    // under it survived: the owner saw their mark in the
                    // quick view and the designer, and never on the
                    // document. The band is fixed by the envelope spec
                    // and cannot grow, so the letterhead SCALES to fit
                    // it instead of being cut off.
                    //
                    // #965 — capping the picture was not enough: a
                    // heading, a blank line, the logo and three lines of
                    // identity still overran the band, and this time the
                    // logo AND the lines under it vanished while the
                    // heading survived. The band now really scales: the
                    // whole letterhead is laid out at page width and
                    // shrunk uniformly until it fits, so everything the
                    // design says is on the page, smaller if it must be.
                    pw.SizedBox(
                      height: addressWindowTop - pageMargin,
                      child: pw.FittedBox(
                        fit: pw.BoxFit.scaleDown,
                        alignment: pw.Alignment.topLeft,
                        child: pw.SizedBox(
                          width: context.page.pageFormat.availableWidth,
                          child: pw.Column(
                            crossAxisAlignment: pw.CrossAxisAlignment.stretch,
                            mainAxisSize: pw.MainAxisSize.min,
                            children: windowHeaderWidgets,
                          ),
                        ),
                      ),
                    )
                  else
                    ...headerWidgets,
                  if (windowOn)
                    pw.SizedBox(
                        height: addressWindowFlowResume - addressWindowTop),
                ],
              )
            : continuationHeader;

  List<pw.Widget> _body(pw.Context context) {
    final report = this.report;
    return [
      ..._identification(),
      ..._voidedBanner(),
      // #470: the body band replaces billed-to, positions and
      // totals — the detail band of the report.
      ...(report == null
          ? <pw.Widget>[
              _billedTo(),
              pw.SizedBox(height: 16),
              _positions(),
              pw.SizedBox(height: 10),
              _totals(),
            ]
          : reportBlockWidgets(report.body, images: reportImages)),
      ..._annex(),
      pw.SizedBox(height: 24),
      ..._signature(),
    ];
  }

  /// #873 — "Facture", its number and the dates, at 90 mm: the first thing
  /// under the address field, as the spec requires.
  List<pw.Widget> _identification() {
    if (!(windowOn && report == null)) return const <pw.Widget>[];
    return [
            pw.Text(numberLine,
                style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: _accent)),
            pw.SizedBox(height: 3),
            pw.Text(issuedOnLine,
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.Text(issuedByLine,
                style: const pw.TextStyle(fontSize: 9, color: _muted)),
            if (invoice.replacesNumber.isNotEmpty)
              pw.Text(replacesLine,
                  style: const pw.TextStyle(fontSize: 9, color: _muted)),
            pw.SizedBox(height: 12),
    ];
  }

  /// ── Erroneous banner (0061) ──
  List<pw.Widget> _voidedBanner() {
    if (!(invoice.isVoided && !proforma)) return const <pw.Widget>[];
    return [
            pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              padding:
                  const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: _accent),
                borderRadius: const pw.BorderRadius.all(pw.Radius.circular(3)),
              ),
              child: pw.Text(strings.voided,
                  style: pw.TextStyle(
                      fontSize: 10,
                      color: _accent,
                      fontWeight: pw.FontWeight.bold)),
            )
    ];
  }

  /// ── Billed to + invoiced month ──
  pw.Widget _billedTo() =>
pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // #869 — the window already shows the recipient; repeating
              // it here would print the address twice.
              if (windowOn)
                pw.Spacer()
              else
                pw.Expanded(
                child: pw.Container(
                  padding: const pw.EdgeInsets.all(10),
                  decoration: const pw.BoxDecoration(
                    color: _zebra,
                    borderRadius: pw.BorderRadius.all(pw.Radius.circular(4)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      label(strings.billedTo.toUpperCase()),
                      pw.SizedBox(height: 4),
                      pw.Text(invoice.clientName,
                          style: pw.TextStyle(
                              fontSize: 11,
                              fontWeight: pw.FontWeight.bold,
                              color: _ink)),
                      if (invoice.memberAddress.isNotEmpty)
                        pw.Padding(
                          padding: const pw.EdgeInsets.only(top: 2),
                          child: pw.Text(invoice.memberAddress,
                              style: const pw.TextStyle(
                                  fontSize: 9, color: _muted)),
                        ),
                    ],
                  ),
                ),
              ),
              pw.SizedBox(width: 12),
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _hairline),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(4)),
                ),
                child: pw.Text(
                    periodLabel.isEmpty ? invoice.title : periodLabel,
                    style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _ink)),
              ),
            ],
          );

  /// ── Positions ──
  pw.Widget _positions() =>
pw.Table(
            columnWidths: showVat
                ? const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FlexColumnWidth(0.8),
                    2: pw.FlexColumnWidth(1.2),
                  }
                : const {
                    0: pw.FlexColumnWidth(4),
                    1: pw.FlexColumnWidth(1.2),
                  },
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: _ink),
                children: [
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8),
                    child: pw.Text(strings.description,
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                  if (showVat)
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 5, horizontal: 8),
                      child: pw.Text(strings.vat,
                          textAlign: pw.TextAlign.right,
                          style: pw.TextStyle(
                              fontSize: 9,
                              color: PdfColors.white,
                              fontWeight: pw.FontWeight.bold)),
                    ),
                  pw.Padding(
                    padding: const pw.EdgeInsets.symmetric(
                        vertical: 5, horizontal: 8),
                    child: pw.Text(strings.total,
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.white,
                            fontWeight: pw.FontWeight.bold)),
                  ),
                ],
              ),
              for (final (i, line) in invoice.lines.indexed) ...[
                // #831 — a settlement groups its lines under the source
                // invoice they came from.
                if (line.sourceNumber.isNotEmpty &&
                    (i == 0 ||
                        invoice.lines[i - 1].sourceNumber != line.sourceNumber))
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: _zebra),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        child: pw.Text(line.sourceNumber,
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: _muted,
                                fontWeight: pw.FontWeight.bold)),
                      ),
                      if (showVat) pw.SizedBox(),
                      pw.SizedBox(),
                    ],
                  ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(
                      color: i.isOdd ? _zebra : PdfColors.white),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.symmetric(
                          vertical: 5, horizontal: 8),
                      child: pw.Text(lineText(line),
                          style:
                              const pw.TextStyle(fontSize: 10, color: _ink)),
                    ),
                    if (showVat)
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(
                            vertical: 5, horizontal: 8),
                        // A credit line is money moving, not a supply: it
                        // carries no rate to print.
                        child: pw.Text(
                            line.amountCents > 0
                                ? ratePercent(line.vatPercent)
                                : '',
                            textAlign: pw.TextAlign.right,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                      ),
                    amountCell(line.amountCents),
                  ],
                ),
              ],
            ],
          );

  /// ── Totals: charges / payments / SOLDE ──
  pw.Widget _totals() =>
pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.SizedBox(
                width: 220,
                child: pw.Column(children: [
                  if (showVat) ...[
                    pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text(strings.net,
                              style: const pw.TextStyle(
                                  fontSize: 9, color: _muted)),
                          pw.Text(money(invoice.netCents),
                              style: const pw.TextStyle(
                                  fontSize: 9, color: _muted)),
                        ]),
                    for (final total in vatTotals)
                      pw.Padding(
                        padding: const pw.EdgeInsets.only(top: 2),
                        child: pw.Row(
                            mainAxisAlignment:
                                pw.MainAxisAlignment.spaceBetween,
                            children: [
                              pw.Text(
                                  '${strings.vat} ${ratePercent(total.percent)}',
                                  style: const pw.TextStyle(
                                      fontSize: 9, color: _muted)),
                              pw.Text(money(total.vatCents),
                                  style: const pw.TextStyle(
                                      fontSize: 9, color: _muted)),
                            ]),
                      ),
                    pw.SizedBox(height: 2),
                  ],
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(strings.charges,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                        pw.Text(money(chargesCents),
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                      ]),
                  if (paymentsCents != 0)
                    pw.Padding(
                      padding: const pw.EdgeInsets.only(top: 2),
                      child: pw.Row(
                          mainAxisAlignment:
                              pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text(strings.payments,
                                style: const pw.TextStyle(
                                    fontSize: 9, color: _muted)),
                            pw.Text(money(paymentsCents),
                                style: const pw.TextStyle(
                                    fontSize: 9, color: _muted)),
                          ]),
                    ),
                  pw.Container(
                      margin: const pw.EdgeInsets.symmetric(vertical: 5),
                      height: 1.5,
                      color: _accent),
                  pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(strings.total,
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: _ink)),
                        pw.Text(money(invoice.totalCents),
                            style: pw.TextStyle(
                                fontSize: 12,
                                fontWeight: pw.FontWeight.bold,
                                color: _ink)),
                      ]),
                ]),
              ),
            ],
          );

  /// ── Annex (0064) ──
  List<pw.Widget> _annex() {
    if (!invoice.detailed) return const <pw.Widget>[];
    return [
            pw.SizedBox(height: 22),
            pw.Text(strings.annex,
                style: pw.TextStyle(
                    fontSize: 12,
                    fontWeight: pw.FontWeight.bold,
                    color: _ink)),
            pw.Container(
                margin: const pw.EdgeInsets.only(top: 3, bottom: 8),
                height: 1,
                width: 120,
                color: _accent),
            if (invoice.attendance.isNotEmpty) ...[
              label(strings.attendance.toUpperCase()),
              pw.SizedBox(height: 4),
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside:
                      pw.BorderSide(color: _hairline, width: .4),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(1.2),
                  2: pw.FlexColumnWidth(2.6),
                },
                children: [
                  for (final row in invoice.attendance)
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(row.startsAt.split('T').first,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _ink)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(
                            '${row.startsAt.split('T').last}–'
                            '${row.endsAt.split('T').last}',
                            style: const pw.TextStyle(
                                fontSize: 9, color: _ink)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(
                            row.status == 'reserved'
                                ? '${row.space} · ${strings.reserved}'
                                : row.space,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                      ),
                    ]),
                ],
              ),
              pw.SizedBox(height: 10),
            ],
            if (invoice.detailLedger.isNotEmpty) ...[
              label(strings.activity.toUpperCase()),
              pw.SizedBox(height: 4),
              pw.Table(
                border: const pw.TableBorder(
                  horizontalInside:
                      pw.BorderSide(color: _hairline, width: .4),
                ),
                columnWidths: const {
                  0: pw.FlexColumnWidth(1.2),
                  1: pw.FlexColumnWidth(2.8),
                  2: pw.FlexColumnWidth(),
                },
                children: [
                  for (final entry in invoice.detailLedger)
                    pw.TableRow(children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(entry.on,
                            style: const pw.TextStyle(
                                fontSize: 9, color: _ink)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(activityText(entry),
                            style: const pw.TextStyle(
                                fontSize: 9, color: _muted)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.symmetric(vertical: 3),
                        child: pw.Text(money(entry.amountCents),
                            textAlign: pw.TextAlign.right,
                            style: pw.TextStyle(
                                fontSize: 9,
                                color: entry.amountCents < 0
                                    ? _accent
                                    : _ink)),
                      ),
                    ]),
                ],
              ),
            ],
    ];
  }

  /// ── Digital signature ── A proforma has none: nothing was issued, so
  /// there is nothing to fingerprint.
  List<pw.Widget> _signature() {
    if (proforma) return const <pw.Widget>[];
    return [
          pw.Container(
            padding: const pw.EdgeInsets.only(top: 6),
            decoration: const pw.BoxDecoration(
              border: pw.Border(top: pw.BorderSide(color: _hairline)),
            ),
            child: pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Text(strings.signature,
                    style: const pw.TextStyle(fontSize: 7, color: _muted)),
                pw.Text(invoice.signature,
                    style: const pw.TextStyle(fontSize: 7, color: _muted)),
              ],
            ),
          )
    ];
  }
}
