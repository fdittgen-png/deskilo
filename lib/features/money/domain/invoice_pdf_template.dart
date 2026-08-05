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
/// One set of report bands — the invoice document uses one, and each
/// reminder LEVEL (#472) carries its own, so a friendly
/// Zahlungserinnerung and a firm final notice are different documents.
class ReportBands {
  const ReportBands({this.header = '', this.body = '', this.footer = ''});

  factory ReportBands.fromJson(Map<String, dynamic> json) => ReportBands(
        header: json['header'] as String? ?? '',
        body: json['body'] as String? ?? '',
        footer: json['footer'] as String? ?? '',
      );

  final String header;
  final String body;
  final String footer;

  static const ReportBands empty = ReportBands();

  bool get hasBands =>
      header.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      footer.trim().isNotEmpty;

  Map<String, String> toJson() =>
      {'header': header, 'body': body, 'footer': footer};
}

class InvoicePdfTemplate {
  const InvoicePdfTemplate({
    this.header = '',
    this.body = '',
    this.footer = '',
    this.reminders = const [],
    this.proforma = ReportBands.empty,
    this.statement = ReportBands.empty,
    this.extraDocs = const {},
    this.translations = const {},
  });

  factory InvoicePdfTemplate.fromJson(Map<String, dynamic> json) =>
      InvoicePdfTemplate(
        header: json[keyHeader] as String? ??
            json[legacyKeyIntro] as String? ??
            '',
        body: json[keyBody] as String? ?? '',
        footer: json[keyFooter] as String? ?? '',
        reminders: [
          for (final r in json[keyReminders] as List<dynamic>? ?? const [])
            ReportBands.fromJson(
                (r as Map).cast<String, dynamic>()),
        ],
        proforma: json[keyProforma] is Map
            ? ReportBands.fromJson(
                (json[keyProforma] as Map).cast<String, dynamic>())
            : ReportBands.empty,
        statement: json[keyStatement] is Map
            ? ReportBands.fromJson(
                (json[keyStatement] as Map).cast<String, dynamic>())
            : ReportBands.empty,
        extraDocs: {
          for (final entry
              in (json[keyDocs] as Map? ?? const {}).entries)
            if (entry.value is Map)
              entry.key as String: ReportBands.fromJson(
                  (entry.value as Map).cast<String, dynamic>()),
        },
        translations: {
          for (final entry
              in (json[keyI18n] as Map? ?? const {}).entries)
            if (entry.value is Map)
              entry.key as String: InvoicePdfTemplate.fromJson(
                  (entry.value as Map).cast<String, dynamic>()),
        },
      );

  /// Band above the whole document (letterhead territory).
  final String header;

  /// The detail band: the invoice lines and totals.
  final String body;

  /// Band under the totals (payment terms, legal mentions…).
  final String footer;

  /// Reminder band sets by LEVEL (index 0 = level 1, the friendly
  /// Zahlungserinnerung). An absent or empty entry falls back to the
  /// localized default letter for that level (#472).
  final List<ReportBands> reminders;

  /// Proforma document bands (#476); empty = the proforma renders with
  /// the invoice's bands, as it always did.
  final ReportBands proforma;

  /// Member-statement document bands (#476); empty = the built-in bill
  /// PDF renders unchanged.
  final ReportBands statement;

  /// Further documents by id (#494): 'agreement' (the financial
  /// agreement), 'payments' (the monthly payments report), 'workspace'
  /// (the workspace report) — extensible without another schema step.
  final Map<String, ReportBands> extraDocs;

  /// Per-LANGUAGE template overlays (#496): language code → a template
  /// whose non-empty documents replace the base's when a document is
  /// rendered in that language. One level deep by design.
  final Map<String, InvoicePdfTemplate> translations;

  static const String keyHeader = 'header';
  static const String keyBody = 'body';
  static const String keyFooter = 'footer';
  static const String keyReminders = 'reminders';
  static const String keyProforma = 'proforma';
  static const String keyStatement = 'statement';
  static const String keyDocs = 'docs';
  static const String keyI18n = 'i18n';

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
    // #480 — the legal mention variables.
    'net_total',
    'vat_total',
    'seller_legal_form',
    'seller_registration',
    'seller_vat_id',
    'seller_legal_id',
    'exemption_reason',
    'client_address',
    'client_vat_id',
    'client_legal_id',
    'payment_terms',
    'late_penalty',
    'recovery_indemnity',
    'escompte',
    'insurance',
    'special_mentions',
  ];

  bool get isEmpty => !hasBands;

  /// Whether ANY band carries content — the switch between the built-in
  /// layout and the report renderer.
  bool get hasBands =>
      header.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      footer.trim().isNotEmpty;

  /// The invoice document's own bands as a [ReportBands].
  ReportBands get invoiceBands =>
      ReportBands(header: header, body: body, footer: footer);

  /// The proforma's own bands, or null to fall back to the invoice's.
  ReportBands? get proformaBands => proforma.hasBands ? proforma : null;

  /// The statement's own bands, or null for the built-in bill PDF.
  ReportBands? get statementBands => statement.hasBands ? statement : null;

  /// An extra document's own bands (#494), or null to use the shipped
  /// default for that document.
  ReportBands? docBands(String docId) {
    final bands = extraDocs[docId];
    return bands != null && bands.hasBands ? bands : null;
  }

  /// Copy with extra document [docId]'s bands replaced (#494).
  InvoicePdfTemplate withDoc(String docId, ReportBands bands) =>
      InvoicePdfTemplate(
        header: header,
        body: body,
        footer: footer,
        reminders: reminders,
        proforma: proforma,
        statement: statement,
        extraDocs: {...extraDocs, docId: bands},
        translations: translations,
      );

  /// Copy with language [lang]'s overlay replaced (#496).
  InvoicePdfTemplate withTranslation(
          String lang, InvoicePdfTemplate overlay) =>
      InvoicePdfTemplate(
        header: header,
        body: body,
        footer: footer,
        reminders: reminders,
        proforma: proforma,
        statement: statement,
        extraDocs: extraDocs,
        translations: {...translations, lang: overlay},
      );

  /// The template as seen from language [lang] (#496): a MERGED view —
  /// every document the overlay defines wins, everything else falls
  /// back to the base template. '' or an unknown language returns the
  /// base unchanged.
  InvoicePdfTemplate forLocale(String lang) {
    final overlay = translations[lang];
    if (overlay == null) return this;
    final levels = overlay.reminders.length > reminders.length
        ? overlay.reminders.length
        : reminders.length;
    return InvoicePdfTemplate(
      header: overlay.hasBands ? overlay.header : header,
      body: overlay.hasBands ? overlay.body : body,
      footer: overlay.hasBands ? overlay.footer : footer,
      reminders: [
        for (var level = 1; level <= levels; level++)
          overlay.reminderBands(level) ??
              (level <= reminders.length
                  ? reminders[level - 1]
                  : ReportBands.empty),
      ],
      proforma: overlay.proforma.hasBands ? overlay.proforma : proforma,
      statement:
          overlay.statement.hasBands ? overlay.statement : statement,
      extraDocs: {
        ...extraDocs,
        for (final entry in overlay.extraDocs.entries)
          if (entry.value.hasBands) entry.key: entry.value,
      },
    );
  }

  /// The stored bands of reminder [level] (1-based), or null when the
  /// owner never customized that level.
  ReportBands? reminderBands(int level) {
    if (level < 1 || level > reminders.length) return null;
    final bands = reminders[level - 1];
    return bands.hasBands ? bands : null;
  }

  /// Copy with reminder [level] (1-based) replaced; the list grows with
  /// empty sets as needed so levels can be edited in any order.
  InvoicePdfTemplate withReminder(int level, ReportBands bands) {
    final next = List<ReportBands>.of(reminders);
    while (next.length < level) {
      next.add(ReportBands.empty);
    }
    next[level - 1] = bands;
    return InvoicePdfTemplate(
      header: header,
      body: body,
      footer: footer,
      reminders: next,
      proforma: proforma,
      statement: statement,
      extraDocs: extraDocs,
      translations: translations,
    );
  }

  InvoicePdfTemplate copyWith({
    ReportBands? invoice,
    ReportBands? proforma,
    ReportBands? statement,
  }) =>
      InvoicePdfTemplate(
        header: invoice?.header ?? header,
        body: invoice?.body ?? body,
        footer: invoice?.footer ?? footer,
        reminders: reminders,
        proforma: proforma ?? this.proforma,
        statement: statement ?? this.statement,
        extraDocs: extraDocs,
        translations: translations,
      );

  Map<String, Object> toJson() => {
        keyHeader: header,
        keyBody: body,
        keyFooter: footer,
        keyReminders: [for (final r in reminders) r.toJson()],
        keyProforma: proforma.toJson(),
        keyStatement: statement.toJson(),
        keyDocs: {
          for (final entry in extraDocs.entries)
            entry.key: entry.value.toJson(),
        },
        if (translations.isNotEmpty)
          keyI18n: {
            for (final entry in translations.entries)
              entry.key: entry.value.toJson(),
          },
      };
}
