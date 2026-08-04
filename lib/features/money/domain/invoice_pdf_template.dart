// SPDX-License-Identifier: 0BSD

/// Owner-written invoice-PDF template (#454): two free-text blocks with
/// `{{placeholder}}` substitution — [intro] renders above the billed-to
/// block, [footer] under the totals. Applied ONLY to the rendered PDF;
/// the EN 16931 XML (and the Factur-X embed) never sees it, by design —
/// the machine document must stay exactly what the schema validated.
///
/// Stored in `workspaces.invoice_pdf_template` (migration 0088) under
/// the [keyIntro]/[keyFooter] jsonb keys.
class InvoicePdfTemplate {
  const InvoicePdfTemplate({this.intro = '', this.footer = ''});

  factory InvoicePdfTemplate.fromJson(Map<String, dynamic> json) =>
      InvoicePdfTemplate(
        intro: json[keyIntro] as String? ?? '',
        footer: json[keyFooter] as String? ?? '',
      );

  /// Text rendered between the letterhead and the billed-to block.
  final String intro;

  /// Text rendered under the totals (payment terms, legal mentions…).
  final String footer;

  static const String keyIntro = 'intro';
  static const String keyFooter = 'footer';

  static const InvoicePdfTemplate empty = InvoicePdfTemplate();

  /// The placeholder names the editor offers and [apply] resolves.
  /// Pinned by test — they are part of saved templates.
  static const List<String> placeholders = [
    'workspace',
    'member',
    'number',
    'period',
    'issued',
    'total',
  ];

  bool get isEmpty => intro.trim().isEmpty && footer.trim().isEmpty;

  Map<String, String> toJson() => {keyIntro: intro, keyFooter: footer};

  /// Replaces `{{name}}` (whitespace-tolerant: `{{ name }}`) with its
  /// value; unknown names stay verbatim so a typo is visible on the
  /// document instead of silently vanishing.
  static String apply(String template, Map<String, String> values) =>
      template.replaceAllMapped(
        RegExp(r'\{\{\s*([a-zA-Z_]+)\s*\}\}'),
        (m) => values[m.group(1)] ?? m.group(0)!,
      );
}
