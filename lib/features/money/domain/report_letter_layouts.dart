// SPDX-License-Identifier: 0BSD
//
// #874 — the DEFAULT positioned layouts every person-facing document
// renders with when the owner designed none: the letter standard
// (docs/AGENT_RULES.md, the window-envelope contract) — letterhead at
// 20/20 mm, recipient at 110/45 mm inside the 85 × 40 mm aperture, the
// identification block resuming at 90 mm, a footer on every page, a
// continuation strip on pages 2+. Pure Dart: the CLI prints them too;
// the app passes its localized [LetterStrings].
import 'invoice_pdf_template.dart';
import 'report_kind.dart';

/// The words a default layout needs, in the reader's language.
class LetterStrings {
  const LetterStrings({
    this.invoice = 'Invoice',
    this.proforma = 'Proforma',
    this.statement = 'Statement',
    this.agreement = 'Financial agreement',
    this.payments = 'Payments report',
    this.usage = 'Consumption report',
    this.reminder = 'Reminder',
    this.issuedOn = 'Issued on',
    this.dueOn = 'Due on',
    this.description = 'Description',
    this.qty = 'Qty',
    this.unitPrice = 'Unit price',
    this.total = 'Total',
    this.paymentsLabel = 'Payments',
    this.balance = 'Balance due',
    this.regards = 'Kind regards',
    this.page = 'Page',
    this.records = 'What was consumed',
  });

  final String invoice, proforma, statement, agreement, payments, usage,
      reminder, issuedOn, dueOn, description, qty, unitPrice, total,
      paymentsLabel,
      balance, regards, page, records;
}

/// The kinds a person receives — the ones the standard binds.
bool isPersonFacingKind(String kindId) =>
    const {'invoice', 'proforma', 'statement', 'agreement', 'payments', 'usage'}
        .contains(kindId) ||
    RegExp(r'^r\d+$').hasMatch(kindId);

/// The layout a document renders with: the owner's positioned design
/// for the kind wins; a kind the owner designed as BANDS keeps them;
/// otherwise — with the letter standard on and a person-facing kind —
/// the default positioned layout; null keeps the built-in bands.
String? resolveLayoutXml({
  required InvoicePdfTemplate template,
  required String kindId,
  required bool letterStandard,
  bool bandsDesigned = false,
  LetterStrings strings = const LetterStrings(),
}) {
  final designed = template.layoutFor(kindId);
  if (designed != null) return designed;
  if (letterStandard && !bandsDesigned && isPersonFacingKind(kindId)) {
    return defaultLetterLayoutXml(kindId, strings);
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
String defaultLetterLayoutXml(String kindId, LetterStrings s) {
  final kind = reportKindById(kindId, reminderLevels: 9);
  final level = switch (kind?.slot) {
    ReportReminderSlot(:final level) => level,
    _ => 0,
  };
  final title = _esc(switch (kindId) {
    'invoice' => s.invoice,
    'proforma' => s.proforma,
    'statement' => s.statement,
    'agreement' => s.agreement,
    'payments' => s.payments,
    'usage' => s.usage,
    _ => '${s.reminder} $level',
  });
  final issuedOn = _esc(s.issuedOn);
  final dueOn = _esc(s.dueOn);
  final description = _esc(s.description);
  final colQty = _esc(s.qty);
  final colUnit = _esc(s.unitPrice);
  final colTotal = _esc(s.total);
  final payments = _esc(s.paymentsLabel);
  final balance = _esc(s.balance);
  final regards = _esc(s.regards);
  final page = _esc(s.page);
  final records = _esc(s.records);

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
    {% if vat_exigibility_mention != "" %}<text style="small">{{ vat_exigibility_mention }}</text>{% endif %}
    {% if payment_terms != "" %}<text style="small">{{ payment_terms }}</text>{% endif %}
    {% if escompte != "" %}<text style="small">{{ escompte }}</text>{% endif %}
    {% if late_penalty != "" %}<text style="small">{{ late_penalty }}</text>{% endif %}
    {% if recovery_indemnity != "" %}<text style="small">{{ recovery_indemnity }}</text>{% endif %}''';

  final body = switch (kindId) {
    'invoice' || 'proforma' => '''
    <text style="heading">{% if proforma %}${_esc(s.proforma)}{% else %}$title{% endif %} {{ number }}</text>
    <text style="small">$issuedOn {{ issued }}</text>
    {% if due_date != "" %}<text style="small">$dueOn {{ due_date }}</text>{% endif %}
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
    {% if due_date != "" %}<text style="small">$dueOn {{ due_date }}</text>{% endif %}
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

  return '''<report-layout version="1" page="A4" margin="20mm" margin-top="8mm" margin-bottom="8mm">

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
