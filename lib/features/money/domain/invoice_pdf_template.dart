// SPDX-License-Identifier: 0BSD
import 'dart:collection';


import 'address_window.dart';

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
  const ReportBands({
    this.header = '',
    this.body = '',
    this.footer = '',
    this.continuation = '',
  });

  factory ReportBands.fromJson(Map<String, dynamic> json) => ReportBands(
    header: json['header'] as String? ?? '',
    body: json['body'] as String? ?? '',
    footer: json['footer'] as String? ?? '',
    continuation: json['continuation'] as String? ?? '',
  );

  final String header;
  final String body;
  final String footer;

  /// #872 — the header for pages TWO onwards.
  ///
  /// A letterhead belongs on the first sheet only: repeating the full
  /// address block, the number box and the recipient on every page
  /// wastes half of each one and reads as if a second document had
  /// started. A continuation page needs a strip saying which document
  /// this is. Empty falls back to that strip, built from the document's
  /// own title and number — a page 2 identifying nothing helps no one.
  final String continuation;

  static const ReportBands empty = ReportBands();

  bool get hasBands =>
      header.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      footer.trim().isNotEmpty ||
      continuation.trim().isNotEmpty;

  Map<String, String> toJson() => {
    'header': header,
    'body': body,
    'footer': footer,
    // Absent from every pre-#872 file; an empty band means "use the
    // built-in strip", so writing it always keeps that meaning.
    'continuation': continuation,
  };
}

class InvoicePdfTemplate {
  const InvoicePdfTemplate({
    this.header = '',
    this.body = '',
    this.footer = '',
    this.continuation = '',
    this.reminders = const [],
    this.proforma = ReportBands.empty,
    this.statement = ReportBands.empty,
    this.extraDocs = const {},
    this.translations = const {},
    this.addressWindow,
    this.layouts = const {},
    this.texts = const {},
  });

  factory InvoicePdfTemplate.fromJson(Map<String, dynamic> json) =>
      InvoicePdfTemplate(
        header:
            json[keyHeader] as String? ?? json[legacyKeyIntro] as String? ?? '',
        body: json[keyBody] as String? ?? '',
        footer: json[keyFooter] as String? ?? '',
        continuation: json[keyContinuation] as String? ?? '',
        reminders: [
          for (final r in json[keyReminders] as List<dynamic>? ?? const [])
            ReportBands.fromJson((r as Map).cast<String, dynamic>()),
        ],
        proforma: json[keyProforma] is Map
            ? ReportBands.fromJson(
                (json[keyProforma] as Map).cast<String, dynamic>(),
              )
            : ReportBands.empty,
        statement: json[keyStatement] is Map
            ? ReportBands.fromJson(
                (json[keyStatement] as Map).cast<String, dynamic>(),
              )
            : ReportBands.empty,
        extraDocs: {
          for (final entry in (json[keyDocs] as Map? ?? const {}).entries)
            if (entry.value is Map)
              entry.key as String: ReportBands.fromJson(
                (entry.value as Map).cast<String, dynamic>(),
              ),
        },
        translations: {
          for (final entry in (json[keyI18n] as Map? ?? const {}).entries)
            if (entry.value is Map)
              entry.key as String: InvoicePdfTemplate.fromJson(
                (entry.value as Map).cast<String, dynamic>(),
              ),
        },
        addressWindow: addressWindowFromWire(json[keyAddressWindow] as String?),
        layouts: {
          for (final entry in (json[keyLayouts] as Map? ?? const {}).entries)
            if (entry.value is String && (entry.value as String).isNotEmpty)
              entry.key as String: entry.value as String,
        },
        texts: {
          for (final entry in (json[keyTexts] as Map? ?? const {}).entries)
            if (entry.value is String) entry.key as String: entry.value as String,
        },
      );

  /// Band above the whole document (letterhead territory).
  final String header;

  /// The detail band: the invoice lines and totals.
  final String body;

  /// Band under the totals (payment terms, legal mentions…).
  final String footer;

  /// #872 — the invoice's continuation header, for pages 2+.
  final String continuation;

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

  /// #869 — where the recipient sits for a window envelope. `null`
  /// means FOLLOW THE COUNTRY: an unset workspace must not be pinned to
  /// one convention by a default, since the two conventions put the
  /// address on opposite sides of the sheet.
  final AddressWindow? addressWindow;

  /// #875 — positioned layouts by report kind id ('invoice',
  /// 'proforma', 'statement', a doc key, 'reminder-N'), each the XML of
  /// a `<report-layout>`. A kind with a layout is rendered by the
  /// positioned engine; without one, by its bands. The two coexist so a
  /// workspace moves one document at a time and nothing already
  /// designed changes until its owner says so.
  final Map<String, String> layouts;

  /// #880 — the owner's own texts, `key → value`, reachable from every
  /// band and layout as `{{ text.<key> }}`: a greeting, a seasonal
  /// note, a legal paragraph — wording changed without touching the
  /// design, and per language (an overlay's non-empty value wins,
  /// exactly as its documents do).
  final Map<String, String> texts;

  /// The layout for [kindId], or null when the kind still uses bands.
  String? layoutFor(String kindId) {
    final xml = layouts[kindId];
    return xml == null || xml.trim().isEmpty ? null : xml;
  }

  static const String keyHeader = 'header';
  static const String keyBody = 'body';
  static const String keyFooter = 'footer';
  static const String keyContinuation = 'continuation';
  static const String keyReminders = 'reminders';
  static const String keyProforma = 'proforma';
  static const String keyStatement = 'statement';
  static const String keyDocs = 'docs';
  static const String keyI18n = 'i18n';
  static const String keyAddressWindow = 'address_window';
  static const String keyLayouts = 'layouts';
  static const String keyTexts = 'texts';

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
    'credit_note',
    'refund_total',
    'iban',
    'bic',
    'bank_name',
    'bank_account',
    'bank_code',
    'account_holder',
    'payment_reference',
    'seller_legal_form',
    'seller_registration',
    'seller_vat_id',
    'seller_legal_id',
    'exemption_reason',
    // #886 — the client as the postal standard prints them.
    'client_name',
    'client_company',
    'client_phone',
    'client_email',
    'client_address',
    'client_vat_id',
    'client_legal_id',
    // #873 — the consumption report's figures and its records loop.
    'usage_paid',
    'usage_included_half_days',
    'usage_used_half_days',
    'usage_remaining_half_days',
    'usage_extra_half_days',
    'usage_overage',
    'usage_supplements',
    'usage_records',
    'payment_terms',
    // #881 — 'workspace' | 'member': whether the conditions are the member's own.
    'payment_terms_source',
    'late_penalty',
    'recovery_indemnity',
    'escompte',
    'insurance',
    'special_mentions',
  ];

  /// #875 — the VALUE an absent placeholder takes.
  ///
  /// Liquid resolves an unknown name to nil, and nil is not the empty
  /// string: `{% if iban != "" %}` therefore PASSES for a placeholder
  /// the document never supplied, and the band prints a label with
  /// nothing after it. That is how a real invoice went out reading
  /// "IBAN :", "BIC :", "Titulaire :" with no values — the guard was
  /// right and the engine was wrong.
  ///
  /// So every known placeholder is seeded before a band renders, and
  /// the type matters: seeding a flag with '' would make
  /// `{% if proforma %}` true, since '' is truthy in Liquid. Only nil
  /// and false are falsy there.
  static const List<String> _flagPlaceholders = [
    'voided',
    'proforma',
    'copy',
    'has_vat',
    'credit_note',
  ];

  static const List<String> _listPlaceholders = ['lines', 'vat', 'usage_records'];

  static Map<String, Object?> get placeholderDefaults => {
        // #880 — `text.<key>` answers '' for an unknown key, so a guard
        // `{% if text.note != "" %}` stays false (the nested twin of
        // the #875 nil bug). The caller's own texts replace this.
        'text': OwnerTexts(const {}),
        for (final key in placeholders)
          key: _flagPlaceholders.contains(key)
              ? false
              : _listPlaceholders.contains(key)
                  ? const <Object?>[]
                  : '',
      };

  bool get isEmpty => !hasBands;

  /// Whether ANY band carries content — the switch between the built-in
  /// layout and the report renderer.
  bool get hasBands =>
      header.trim().isNotEmpty ||
      body.trim().isNotEmpty ||
      footer.trim().isNotEmpty ||
      continuation.trim().isNotEmpty;

  /// The invoice document's own bands as a [ReportBands].
  ReportBands get invoiceBands => ReportBands(
    header: header,
    body: body,
    footer: footer,
    continuation: continuation,
  );

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
        continuation: continuation,
        reminders: reminders,
        proforma: proforma,
        statement: statement,
        extraDocs: {...extraDocs, docId: bands},
        translations: translations,
        addressWindow: addressWindow,
        layouts: layouts,
        texts: texts,
      );

  /// Copy with language [lang]'s overlay replaced (#496).
  InvoicePdfTemplate withTranslation(String lang, InvoicePdfTemplate overlay) =>
      InvoicePdfTemplate(
        header: header,
        body: body,
        footer: footer,
        continuation: continuation,
        reminders: reminders,
        proforma: proforma,
        statement: statement,
        extraDocs: extraDocs,
        translations: {...translations, lang: overlay},
        addressWindow: addressWindow,
        layouts: layouts,
        texts: texts,
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
      continuation: overlay.hasBands ? overlay.continuation : continuation,
      reminders: [
        for (var level = 1; level <= levels; level++)
          overlay.reminderBands(level) ??
              (level <= reminders.length
                  ? reminders[level - 1]
                  : ReportBands.empty),
      ],
      proforma: overlay.proforma.hasBands ? overlay.proforma : proforma,
      statement: overlay.statement.hasBands ? overlay.statement : statement,
      extraDocs: {
        ...extraDocs,
        for (final entry in overlay.extraDocs.entries)
          if (entry.value.hasBands) entry.key: entry.value,
      },
      addressWindow: overlay.addressWindow ?? addressWindow,
      // A language may carry its own positioned layout per kind; where
      // it does, that layout wins exactly as its bands would.
      layouts: {...layouts, ...overlay.layouts},
      texts: {
        ...texts,
        for (final entry in overlay.texts.entries)
          if (entry.value.isNotEmpty) entry.key: entry.value,
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
      continuation: continuation,
      reminders: next,
      proforma: proforma,
      statement: statement,
      extraDocs: extraDocs,
      translations: translations,
      addressWindow: addressWindow,
      layouts: layouts,
      texts: texts,
    );
  }

  InvoicePdfTemplate copyWith({
    ReportBands? invoice,
    ReportBands? proforma,
    ReportBands? statement,
    AddressWindow? addressWindow,
    Map<String, String>? layouts,
    Map<String, String>? texts,
  }) => InvoicePdfTemplate(
    header: invoice?.header ?? header,
    body: invoice?.body ?? body,
    footer: invoice?.footer ?? footer,
    continuation: invoice?.continuation ?? continuation,
    reminders: reminders,
    proforma: proforma ?? this.proforma,
    statement: statement ?? this.statement,
    extraDocs: extraDocs,
    translations: translations,
    addressWindow: addressWindow ?? this.addressWindow,
    layouts: layouts ?? this.layouts,
    texts: texts ?? this.texts,
  );

  Map<String, Object> toJson() => {
    keyHeader: header,
    keyBody: body,
    keyFooter: footer,
    keyContinuation: continuation,
    keyReminders: [for (final r in reminders) r.toJson()],
    keyProforma: proforma.toJson(),
    keyStatement: statement.toJson(),
    keyDocs: {
      for (final entry in extraDocs.entries) entry.key: entry.value.toJson(),
    },
    if (translations.isNotEmpty)
      keyI18n: {
        for (final entry in translations.entries)
          entry.key: entry.value.toJson(),
      },
    // Absent means FOLLOW THE COUNTRY — writing a default here
    // would pin the workspace to one convention forever.
    if (addressWindow != null)
      keyAddressWindow: addressWindowWire(addressWindow!),
    if (layouts.isNotEmpty) keyLayouts: layouts,
    if (texts.isNotEmpty) keyTexts: texts,
  };
}

/// #880 — the owner's texts as Liquid sees them: a map that answers ''
/// for a key nobody defined, so `{{ text.x }}` prints nothing and
/// `{% if text.x != "" %}` is false instead of true-on-nil.
class OwnerTexts extends MapBase<String, Object?> {
  OwnerTexts(Map<String, String> texts) : _texts = Map.of(texts);

  final Map<String, String> _texts;

  @override
  Object? operator [](Object? key) => _texts[key] ?? '';

  @override
  void operator []=(String key, Object? value) => _texts[key] = '$value';

  @override
  void clear() => _texts.clear();

  @override
  Iterable<String> get keys => _texts.keys;

  @override
  Object? remove(Object? key) => _texts.remove(key);

  @override
  bool containsKey(Object? key) => true;

  /// The same texts with every value passed through [f] — how the
  /// layout renderer XML-escapes them.
  OwnerTexts mapValues(String Function(String value) f) =>
      OwnerTexts({for (final e in _texts.entries) e.key: f(e.value)});
}

/// [data] with the owner's [texts] beside it under `text` — what every
/// render site passes so `{{ text.<key> }}` resolves.
Map<String, Object?> withOwnerTexts(
  Map<String, Object?> data,
  Map<String, String> texts,
) =>
    {...data, 'text': OwnerTexts(texts)};
