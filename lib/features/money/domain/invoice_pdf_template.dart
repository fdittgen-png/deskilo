// SPDX-License-Identifier: 0BSD

/// Owner-written invoice report template (#454, rebuilt as a banded
/// reporting tool in #470): three LIQUID bands — [header] above
/// everything, [body] carrying the invoice lines (typically a
/// `{% for line in lines %}` loop), [footer] under it (payment terms,
/// legal mentions). Rendered by `invoice_report.dart`; applied ONLY to
/// the PDF — the EN 16931 XML (and the Factur-X embed) never sees it,
/// by design. The void watermark/banner, the digital signature, the
/// annex and the page numbers stay non-templated: the legal integrity
/// floor of the document.
///
/// Stored in `workspaces.invoice_pdf_template` (migration 0088). The
/// pre-#470 keys `intro`/`footer` map onto [header]/[footer], and their
/// `{{placeholder}}` syntax is valid Liquid — old templates keep
/// working unchanged.
class InvoicePdfTemplate {
  const InvoicePdfTemplate({
    this.header = '',
    this.body = '',
    this.footer = '',
  });

  factory InvoicePdfTemplate.fromJson(Map<String, dynamic> json) =>
      InvoicePdfTemplate(
        header: json[keyHeader] as String? ??
            json[legacyKeyIntro] as String? ??
            '',
        body: json[keyBody] as String? ?? '',
        footer: json[keyFooter] as String? ?? '',
      );

  /// Band above the whole document (letterhead territory).
  final String header;

  /// The detail band: the invoice lines and totals.
  final String body;

  /// Band under the totals (payment terms, legal mentions…).
  final String footer;

  static const String keyHeader = 'header';
  static const String keyBody = 'body';
  static const String keyFooter = 'footer';

  /// Pre-#470 key: a single intro paragraph — now the header band.
  static const String legacyKeyIntro = 'intro';

  static const InvoicePdfTemplate empty = InvoicePdfTemplate();

  /// The data fields the bands can reference; pinned by test — they are
  /// part of saved templates. `lines` iterates `{label, amount,
  /// negative}`, `vat` iterates `{rate, net, amount}`.
  static const List<String> placeholders = [
    'number',
    'member',
    'workspace',
    'workspace_address',
    'period',
    'issued',
    'issued_by',
    'replaces',
    'total',
    'charges',
    'payments',
    'voided',
    'proforma',
    'copy',
    'has_vat',
    'lines',
    'vat',
  ];

  bool get isEmpty => !hasBands;

  /// Whether ANY band carries content — the switch between the built-in
  /// layout and the report renderer.
  bool get hasBands =>
      header.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      footer.trim().isNotEmpty;

  Map<String, String> toJson() => {
        keyHeader: header,
        keyBody: body,
        keyFooter: footer,
      };
}
