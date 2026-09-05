// SPDX-License-Identifier: 0BSD
//
// #874 — every document sent to a person conforms to the letter
// standard (docs/AGENT_RULES.md, the window-envelope contract): the
// letterhead at 20/20 mm, the recipient at 110/45 mm inside the
// 85 × 40 mm aperture, the identification block resuming at 90 mm, a
// footer pinned to every page, a continuation strip on pages 2+. These
// are the DEFAULT positioned layouts (#875) a kind renders with when
// the owner designed none — one typography, one letterhead, one footer
// across all of them. The owner's own layout always wins.
import '../../../l10n/app_localizations.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/report_kind.dart';

/// The kinds a person receives — the ones the standard binds.
bool isPersonFacingKind(String kindId) =>
    const {'invoice', 'proforma', 'statement', 'agreement', 'payments', 'usage'}
        .contains(kindId) ||
    RegExp(r'^r\d+$').hasMatch(kindId);

/// The layout a document renders with: the owner's design for the kind,
/// else — when the letter standard is on and the kind is sent to a
/// person — its default positioned layout; null keeps the bands.
String? resolveLayoutXml({
  required InvoicePdfTemplate template,
  required String kindId,
  required bool letterStandard,
  AppLocalizations? l10n,
}) {
  final designed = template.layoutFor(kindId);
  if (designed != null) return designed;
  if (letterStandard && isPersonFacingKind(kindId)) {
    return defaultLetterLayoutXml(kindId, l10n);
  }
  return null;
}

String _esc(String s) => s
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');

/// The default positioned layout of [kindId] (the reminders share one
/// body, the level printed from the data).
String defaultLetterLayoutXml(String kindId, AppLocalizations? l10n) {
  final kind = reportKindById(kindId, reminderLevels: 9);
  final level = switch (kind?.slot) {
    ReportReminderSlot(:final level) => level,
    _ => 0,
  };
  final title = _esc(switch (kindId) {
    'invoice' => l10n?.invoicePdfTitle ?? 'Invoice',
    'proforma' => l10n?.invoicePdfProforma ?? 'Proforma',
    'statement' => l10n?.invoiceTemplateDocStatement ?? 'Statement',
    'agreement' => l10n?.reportDocAgreement ?? 'Financial agreement',
    'payments' => l10n?.reportDocPayments ?? 'Payments report',
    // The usage kind's own label arrives with #873.
    'usage' => 'Consumption report',
    _ => l10n?.invoiceTemplateDocReminder(level) ?? 'Reminder $level',
  });
  final issuedOn = _esc(l10n?.invoicePdfIssuedOn ?? 'Issued on');
  final description = _esc(l10n?.invoicePdfDescription ?? 'Description');
  final colQty = _esc(l10n?.reportColQty ?? 'Qty');
  final colUnit = _esc(l10n?.reportColUnitPrice ?? 'Unit price');
  final colTotal = _esc(l10n?.reportColTotal ?? 'Total');
  final payments = _esc(l10n?.invoicePdfPayments ?? 'Payments');
  final balance = _esc(l10n?.invoiceBalance ?? 'Balance due');
  final regards = _esc(l10n?.reportRegards ?? 'Kind regards');
  final page = _esc(l10n?.invoicePdfPage ?? 'Page');
  const records = 'What was consumed';

  final linesTable = '''
    <table>
      <col w="55%"/>
      <col w="10%" align="right"/>
      <col w="17%" align="right"/>
      <col w="18%" align="right"/>
      <row bold="true"><cell>$description</cell><cell>$colQty</cell><cell>$colUnit</cell><cell>$colTotal</cell></row>
      {% for line in lines %}
      <row><cell>{{ line.label }}</cell><cell>{{ line.qty }}</cell><cell>{{ line.unit_price }}</cell><cell>{{ line.amount }}</cell></row>
      {% endfor %}
    </table>''';
  const simpleLines = '''
    <table>
      <col w="70%"/>
      <col w="30%" align="right"/>
      {% for line in lines %}
      <row><cell>{{ line.label }}</cell><cell>{{ line.amount }}</cell></row>
      {% endfor %}
    </table>''';
  const mentions = '''
    <spacer size="6mm"/>
    {% if payment_terms != "" %}<text style="small">{{ payment_terms }}</text>{% endif %}
    {% if escompte != "" %}<text style="small">{{ escompte }}</text>{% endif %}
    {% if late_penalty != "" %}<text style="small">{{ late_penalty }}</text>{% endif %}
    {% if recovery_indemnity != "" %}<text style="small">{{ recovery_indemnity }}</text>{% endif %}''';

  final body = switch (kindId) {
    'invoice' || 'proforma' => '''
    <text style="heading">{% if proforma %}${_esc(l10n?.invoicePdfProforma ?? 'Proforma')}{% else %}$title{% endif %} {{ number }}</text>
    <text style="small">$issuedOn {{ issued }}</text>
    <text style="small">{{ period }}</text>
    {% if client_legal_id != "" %}<text style="small">{{ client_legal_id }}</text>{% endif %}
    <spacer size="4mm"/>
$linesTable
    <rule/>
    <columns>
      <column>
        {% if exemption_reason != "" %}<text style="small">{{ exemption_reason }}</text>{% endif %}
      </column>
      <column>
        <table>
          <col w="60%"/><col w="40%" align="right"/>
          {% if has_vat %}<row><cell>{{ net_total }}</cell><cell>{{ vat_total }}</cell></row>{% endif %}
          <row><cell>$payments</cell><cell>{{ payments }}</cell></row>
          <row bold="true"><cell>$balance</cell><cell>{{ total }}</cell></row>
        </table>
      </column>
    </columns>
$mentions''',
    'statement' => '''
    <text style="heading">$title — {{ period }}</text>
    <text style="small">$issuedOn {{ issued }}</text>
    <spacer size="4mm"/>
$simpleLines
    <rule/>
    <table>
      <col w="70%"/><col w="30%" align="right"/>
      <row><cell>$payments</cell><cell>{{ payments }}</cell></row>
      <row bold="true"><cell>$balance</cell><cell>{{ total }}</cell></row>
    </table>''',
    'agreement' => '''
    <text style="heading">$title</text>
    <text style="small">{{ member }} · {{ issued }}</text>
    <spacer size="4mm"/>
$simpleLines
    <spacer size="6mm"/>
    <text>$regards</text>
    <text>{{ issued_by }}</text>''',
    'payments' => '''
    <text style="heading">$title — {{ period }}</text>
    <text style="small">{{ member }} · {{ issued }}</text>
    <spacer size="4mm"/>
$simpleLines
    <rule/>
    <table>
      <col w="70%"/><col w="30%" align="right"/>
      <row bold="true"><cell>$payments</cell><cell>{{ payments }}</cell></row>
    </table>''',
    'usage' => '''
    <text style="heading">$title — {{ period }}</text>
    <text style="small">{{ member }} · {{ issued }}</text>
    <spacer size="4mm"/>
$simpleLines
    {% if usage_overage != "" %}<text style="small">{{ usage_overage }}</text>{% endif %}
    <spacer size="4mm"/>
    <text style="subheading">$records</text>
    <table>
      <col w="40%"/><col w="35%"/><col w="25%" align="right"/>
      {% for r in usage_records %}
      <row><cell>{{ r.date }}</cell><cell>{{ r.space }}</cell><cell>{{ r.counted }}</cell></row>
      {% endfor %}
    </table>''',
    _ => '''
    <text style="heading">$title — {{ number }}</text>
    <text style="small">{{ reminder_date }} · {{ days_open }}</text>
    <spacer size="4mm"/>
$linesTable
    <rule/>
    <table>
      <col w="70%"/><col w="30%" align="right"/>
      <row bold="true"><cell>$balance</cell><cell>{{ total }}</cell></row>
    </table>
$mentions''',
  };

  return '''<report-layout version="1" page="A4" margin="20mm">

  <header height="25mm">
    <image name="logo" x="0" y="0" h="12mm" fit="contain"/>
    <text x="0" y="13mm" style="heading">{{ workspace }}</text>
    <text x="0" y="20mm" style="small">{% if seller_legal_form != "" %}{{ seller_legal_form }} · {% endif %}{{ workspace_address }}</text>
  </header>

  <continuation height="8mm">
    <text style="small">{{ workspace }} · $title {{ number }}</text>
    <rule/>
  </continuation>

  <recipient window="fr"/>

  <body y="90mm">
$body
  </body>

  <footer height="30mm">
    <rule/>
    {% if special_mentions != "" %}<text style="small">{{ special_mentions }}</text>{% endif %}
    <columns>
      <column>
        <text style="small">{{ workspace }}</text>
        <text style="small">{{ workspace_address }}</text>
        {% if seller_registration != "" %}<text style="small">{{ seller_registration }}</text>{% endif %}
      </column>
      <column>
        {% if iban != "" %}<text style="small">IBAN {{ iban }}</text>{% endif %}
        {% if bic != "" %}<text style="small">BIC {{ bic }}</text>{% endif %}
        {% if account_holder != "" %}<text style="small">{{ account_holder }}</text>{% endif %}
      </column>
      <column>
        <text style="small">$page</text>
        <text style="small">{{ number }}</text>
      </column>
    </columns>
  </footer>

</report-layout>
''';
}
