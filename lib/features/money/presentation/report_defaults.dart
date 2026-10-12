// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Shipped localized report templates. Legal facts come from the qualified
// data projection; a layout alone is not evidence of country compliance.
import 'package:meta/meta.dart';

import '../../../l10n/app_localizations.dart';
import '../domain/analytics_report_bands.dart';
import '../domain/configuration_report_bands.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/report_kind.dart';
import 'professional_report_bands.dart';
// The three #671 documents (CoA preview, badge sheet, space codes) live
// in their own file; they are re-exported so every caller keeps
// resolving document defaults from one import.
import 'report_defaults_batch.dart';
import 'vat_declaration_report_defaults.dart';

export 'report_defaults_batch.dart';
// The preview fixture is a different concern from the shipped templates
// — sample text, never live data — and lives on its own.
export 'report_sample_data.dart';

/// The seller's statutory identity block, shared by every preset's
/// header: name, legal form & capital, address, trade register and VAT
/// number — each line only when the workspace declared it.
String _sellerBlock(AppLocalizations l10n) => '''
{{ workspace }}
{% if seller_legal_form != "" %}> {{ seller_legal_form }}{% endif %}
> {{ workspace_address }}
{% if site_name != "" %}> {{ site_name }} — {{ site_address }}{% endif %}
{% if seller_registration != "" %}> {{ seller_registration }}{% endif %}
{% if seller_vat_id != "" %}> ${l10n.legalIdentityVatId}: {{ seller_vat_id }}{% endif %}''';

/// The statutory payment-clause footer every invoice-like document must
/// carry: payment terms + escompte, penalty + recovery indemnity, then
/// the optional insurance and special-regime mentions.
String _legalFooter(AppLocalizations l10n) => '''
> {{ payment_terms }}{% if escompte != "" %} — {{ escompte }}{% endif %}
{% if late_penalty != "" %}> {{ late_penalty }}{% endif %}
{% if recovery_indemnity != "" %}> {{ recovery_indemnity }}{% endif %}
{% if insurance != "" %}> {{ insurance }}{% endif %}
{% if special_mentions != "" %}> {{ special_mentions }}{% endif %}''';

/// The built-in invoice layout as editable bands — the CLASSIC preset,
/// legally complete (#480).
@visibleForTesting
InvoicePdfTemplate defaultInvoiceTemplate(AppLocalizations l10n) {
  final classic = _invoicePresetBands(l10n, 'classic');
  return InvoicePdfTemplate(
    header: classic.header,
    body: classic.body,
    footer: classic.footer,
  );
}

ReportBands _invoicePresetBands(AppLocalizations l10n, String id) {
  final title =
      '{% if credit_note %}${l10n.invoicePdfCreditNote}{% elsif proforma %}${l10n.invoicePdfProforma}{% else %}${l10n.invoicePdfTitle}{% endif %}';
  // Row 1 of the facture layout (#482): brand left, document title +
  // reference/date block right.
  final brandRow = '''
:::
# {{ workspace }}
{% if seller_legal_form != "" %}> {{ seller_legal_form }}{% endif %}
|||
## $title
{{ number }}
> ${l10n.invoicePdfIssuedOn} {{ issued }} · {{ issued_by }}
{% if due_date != "" %}> ${l10n.invoicePdfDueOn} {{ due_date }}
{% endif %}{% if purchase_order != "" %}> ${l10n.invoicePdfPurchaseOrder} {{ purchase_order }}
{% endif %}{% if buyer_reference != "" %}> ${l10n.invoicePdfBuyerReference} {{ buyer_reference }}
{% endif %}
{% if replaces != "" %}> ${l10n.invoicePdfReplaces} {{ replaces }}{% endif %}
:::''';
  // Row 2: seller coordinates left, client box right.
  final addressRow = '''
:::
{{ workspace }}
> {{ workspace_address }}
{% if seller_registration != "" %}> {{ seller_registration }}{% endif %}
{% if seller_vat_id != "" %}> ${l10n.legalIdentityVatId}: {{ seller_vat_id }}{% endif %}
|||
${l10n.invoicePdfBilledTo}
{{ member }}
{% if client_address != "" %}> {{ client_address }}{% endif %}
{% if client_legal_id != "" %}> {{ client_legal_id }}{% endif %}
{% if client_member_number != "" %}> ${l10n.memberNumberLabel}: {{ client_member_number }}{% endif %}
{% if client_vat_id != "" %}> ${l10n.legalIdentityVatId}: {{ client_vat_id }}{% endif %}
> {{ period }}
:::''';
  // The line table with its column headers, then the right-aligned
  // totals block (empty first column pushes it right, like the model).
  final lineTable =
      '= ${l10n.invoicePdfDescription} | ${l10n.reportColUnitPrice} | ${l10n.reportColQty} | ${l10n.reportColTotal}\n'
      '{% for line in lines %}{{ line.label }} | {{ line.unit_price }} | {{ line.qty }} | {{ line.amount }}\n'
      '{% endfor %}';
  final totalsBlock = '''
:::
|||
${l10n.vatPdfNet} | {{ net_total }}
{% if has_vat %}{% for v in vat %}${l10n.vatPdfVat} {{ v.rate }} | {{ v.amount }}
{% endfor %}{% endif %}= ${l10n.invoiceBalance} | {{ total }}
:::''';
  const mentions = '''
{% if exemption_reason != "" %}> {{ exemption_reason }}
{% endif %}{% if vat_exigibility_mention != "" %}> {{ vat_exigibility_mention }}
{% endif %}> {{ payment_terms }}{% if escompte != "" %} — {{ escompte }}{% endif %}''';
  switch (id) {
    case 'simple':
      return ReportBands(
        header: '''
$brandRow
---
$addressRow''',
        body: '''
{% for line in lines %}{{ line.label }}{% if line.vat_rate != "" %} · ${l10n.vatPdfVat} {{ line.vat_rate }}{% endif %} | {{ line.amount }}
{% endfor %}---
$totalsBlock
$mentions''',
        footer: _legalFooter(l10n),
      );
    case 'verbose':
      return ReportBands(
        header: '''
$brandRow
---
$addressRow''',
        body: '''
= ${l10n.invoicePdfDescription} | ${l10n.reportColUnitPrice} | ${l10n.reportColQty} | ${l10n.vatPdfNet} | ${l10n.vatPdfVat} | ${l10n.reportColTotal}
{% for line in lines %}{{ line.label }} | {{ line.unit_price }} | {{ line.qty }} | {{ line.net }} | {{ line.vat_rate }} | {{ line.amount }}
{% endfor %}---
:::
|||
${l10n.invoicePdfCharges} | {{ charges }}
${l10n.invoicePdfPayments} | {{ payments }}
${l10n.vatPdfNet} | {{ net_total }}
{% if has_vat %}{% for v in vat %}${l10n.vatPdfVat} {{ v.rate }} | {{ v.amount }}
{% endfor %}${l10n.vatPdfVat} | {{ vat_total }}
{% endif %}= ${l10n.invoiceBalance} | {{ total }}
:::
$mentions''',
        footer: _legalFooter(l10n),
      );
    case 'formal':
      return ReportBands(
        header: '''
:::
{{ workspace }}
{% if seller_legal_form != "" %}> {{ seller_legal_form }}{% endif %}
> {{ workspace_address }}
{% if seller_registration != "" %}> {{ seller_registration }}{% endif %}
{% if seller_vat_id != "" %}> ${l10n.legalIdentityVatId}: {{ seller_vat_id }}{% endif %}
|||
{{ member }}
{% if client_address != "" %}> {{ client_address }}{% endif %}
{% if client_vat_id != "" %}> ${l10n.legalIdentityVatId}: {{ client_vat_id }}{% endif %}

> {{ issued }}
:::''',
        body: '''
## ${l10n.reportSubject}: $title {{ number }} — {{ period }}

{{ member }},

$lineTable---
$totalsBlock
$mentions''',
        footer: '''
${_legalFooter(l10n)}

${l10n.reportRegards},
{{ issued_by }}''',
      );
    default: // classic — the built-in default, the facture layout.
      return ReportBands(
        header: '''
$brandRow
---
$addressRow''',
        body: '''
$lineTable---
$totalsBlock
$mentions''',
        footer: _legalFooter(l10n),
      );
  }
}

/// The shipped letter for reminder [level] (1-based) — the CLASSIC
/// preset: level 1 is the friendly Zahlungserinnerung, higher levels
/// read firmer and carry the level number. All content is template
/// language over the reminder data — the owner edits any level
/// independently in the report editor.
ReportBands defaultReminderBands(int level, AppLocalizations l10n) =>
    _reminderPresetBands(level, l10n, 'classic');

String _reminderTitle(int level, AppLocalizations l10n) => level <= 1
    ? (l10n.reminderPdfTitleFriendly)
    : '${l10n.reminderPdfTitleFirm} $level';

String _reminderOpening(int level, AppLocalizations l10n) => level <= 1
    ? (l10n.reminderPdfOpeningFriendly)
    : (l10n.reminderPdfOpeningFirm);

ReportBands _reminderPresetBands(
    int level, AppLocalizations l10n, String id) {
  final title = _reminderTitle(level, l10n);
  final opening = _reminderOpening(level, l10n);
  final invoiceRecap = '''
## ${l10n.invoicePdfTitle}
{{ number }} · ${l10n.invoicePdfIssuedOn} {{ issued }} | {{ total }}
> ${l10n.reminderPdfDaysOpen} {{ days_open }} ${l10n.reminderPdfDays} · ${l10n.reminderPdfLevelLabel} {{ reminder_level }}''';
  final closing =
      '> ${l10n.reminderPdfClosing}';
  // A reminder cites the statutory late-payment clauses (#480) — on the
  // firm levels they are the point of the letter.
  // Guarded (#484): an association prints none of these by default.
  const clauses =
      '{% if late_penalty != "" %}> {{ late_penalty }}\n{% endif %}'
      '{% if recovery_indemnity != "" %}> {{ recovery_indemnity }}\n{% endif %}';
  switch (id) {
    case 'simple':
      return ReportBands(
        header: '# $title',
        body: '''
{{ member }} — {{ number }} ({{ issued }})
> ${l10n.reminderPdfDaysOpen} {{ days_open }} ${l10n.reminderPdfDays}
= ${l10n.invoiceBalance} | {{ total }}''',
        footer: '$clauses\n$closing',
      );
    case 'verbose':
      return ReportBands(
        header: '''
# $title
${_sellerBlock(l10n)}
> {{ reminder_date }}
---''',
        body: '''
{{ member }},
{% if client_address != "" %}> {{ client_address }}{% endif %}

$opening

$invoiceRecap
---
> {{ payment_terms }}
$clauses
= ${l10n.invoiceBalance} | {{ total }}''',
        footer: closing,
      );
    case 'formal':
      return ReportBands(
        header: '''
${_sellerBlock(l10n)}

{{ member }}
{% if client_address != "" %}> {{ client_address }}{% endif %}

> {{ reminder_date }}''',
        body: '''
## ${l10n.reportSubject}: $title — ${l10n.invoicePdfTitle} {{ number }}

{{ member }},

$opening

{{ number }} · {{ issued }} | {{ total }}
---
$clauses
= ${l10n.invoiceBalance} | {{ total }}''',
        footer: '''
$closing

${l10n.reportRegards},
{{ workspace }}''',
      );
    default: // classic
      return ReportBands(
        header: '''
# $title
${_sellerBlock(l10n)}
> {{ reminder_date }}
---''',
        body: '''
{{ member }},

$opening

$invoiceRecap
---
$clauses
= ${l10n.invoiceBalance} | {{ total }}''',
        footer: closing,
      );
  }
}

/// The built-in member-statement document (#476) as editable bands —
/// the CLASSIC preset.
ReportBands _defaultStatementBands(AppLocalizations l10n) =>
    _statementPresetBands(l10n, 'classic');

ReportBands _statementPresetBands(AppLocalizations l10n, String id) {
  const lines = '{% for line in lines %}'
      '{{ line.label }} | {{ line.amount }}\n{% endfor %}';
  final balance = '= ${l10n.billBalance} | {{ total }}';
  switch (id) {
    case 'simple':
      return ReportBands(
        header: '# {{ member }} — {{ period }}',
        body: '$lines$balance',
      );
    case 'verbose':
      return ReportBands(
        header: '''
# ${l10n.billPdfTitle} — {{ period }}
${_sellerBlock(l10n)}
> {{ member }}
---''',
        body: '''
## ${l10n.invoicePdfDescription}
$lines---
${l10n.invoicePdfCharges} | {{ charges }}
${l10n.invoicePdfPayments} | {{ payments }}
$balance''',
      );
    case 'formal':
      return ReportBands(
        header: '''
${_sellerBlock(l10n)}

{{ member }}

> {{ period }}''',
        body: '''
## ${l10n.reportSubject}: ${l10n.billPdfTitle} — {{ period }}

{{ member }},

$lines---
$balance''',
        footer: '''
${l10n.reportRegards},
{{ workspace }}''',
      );
    default: // classic
      return ReportBands(
        header: '''
# ${l10n.billPdfTitle} — {{ period }}
{{ workspace }}
> {{ member }}
---''',
        body: '$lines---\n$balance',
      );
  }
}

/// The FINANCIAL AGREEMENT document (#494) as editable bands.
ReportBands _defaultAgreementBands(AppLocalizations l10n) =>
    _simpleDocPresetBands(
        l10n, 'classic', l10n.reportDocAgreement,
        subtitle: '{{ member }}');

/// The MONTHLY PAYMENTS document (#494) as editable bands.
ReportBands _defaultPaymentsBands(AppLocalizations l10n) =>
    _simpleDocPresetBands(
        l10n, 'classic', l10n.reportDocPayments,
        subtitle: '{{ member }} — {{ period }}',
        // #955 — the period's payments and the balance are two figures;
        // the template names both, and pending payments apart from
        // pending expense submissions.
        totalsLine:
            '= ${l10n.reportPaymentsPeriodTotal} | {{ validated_total }}\n'
            '{% if pending_payments_total != "" %}${l10n.reportPendingPayments} | {{ pending_payments_total }}\n{% endif %}'
            '{% if pending_expenses_total != "" %}${l10n.reportPendingExpenses} | {{ pending_expenses_total }}\n{% endif %}'
            '= ${l10n.billBalance} | {{ total }}');

/// The WORKSPACE STATUS (#934): what the workspace invoiced, collected,
/// reimbursed and shared out over a range of months, then the same per
/// member. Owners and admins only; the numbers are the database's.
ReportBands _defaultStatusBands(AppLocalizations l10n) => ReportBands(
      header: '''
# {{ workspace }}
> {{ workspace_address }}
> {{ issued }}

## ${l10n.reportDocStatus} — {{ status_from }} → {{ status_to }}''',
      body: '''
{% for line in lines %}{{ line.label }} | {{ line.amount }}
{% endfor %}= ${l10n.statusNet} | {{ status_net }}

### ${l10n.statusMembers}
{% for m in status_members %}{{ m.number }} {{ m.name }} ({{ m.pct }} %) | {{ m.invoiced }} / {{ m.paid }}
{% endfor %}''',
      footer: '> {{ workspace }}',
    );

/// The CONSUMPTION REPORT (#873): what the month's participation paid
/// for, what was actually consumed, what is left or exceeded — and the
/// records behind the numbers. Sent to the member at month end.
@visibleForTesting
ReportBands defaultUsageBands(AppLocalizations l10n) => ReportBands(
      header: '''
# {{ workspace }}
> {{ workspace_address }}
> {{ issued }}
---
# ${l10n.reportDocUsage}
> {{ member }} — {{ period }}''',
      body: '''
{% for line in lines %}{{ line.label }} | {{ line.amount }}
{% endfor %}
{% if usage_overage != "" %}> ${l10n.usageReportOverage} : {{ usage_overage }}{% endif %}

## ${l10n.usageReportRecordsHeading}
{% for r in usage_records %}{{ r.date }} | {{ r.space }} | {{ r.counted }}
{% endfor %}''',
      footer: _legalFooter(l10n),
    );

/// The VAT REPORT (#878): every position of the period by rate, the
/// subtotals per rate and category, the period totals — what the
/// accountant reconciles against the declaration boxes.
@visibleForTesting
ReportBands defaultVatBands(AppLocalizations l10n) => ReportBands(
      header: '''
# {{ workspace }}
> {{ workspace_address }}
> {{ issued }}
---
# ${l10n.reportDocVat}
> {{ vat_period }}
> {{ vat_basis_note }}''',
      body: '''
## ${l10n.vatReportPositions}
{% for p in vat_positions %}{{ p.number }} · {{ p.date }} · {{ p.customer }}{% if p.reverses != "" %} ⟲ {{ p.reverses }}{% endif %} | {{ p.rate }} {{ p.category }} | {{ p.net }} | {{ p.vat }} | {{ p.gross }}
{% endfor %}
## ${l10n.vatReportByRate}
{% for t in vat_rate_totals %}{{ t.rate }} {{ t.category }} · {{ t.count }} | {{ t.net }} | {{ t.vat }} | {{ t.gross }}
{% endfor %}---
= ${l10n.vatReportTotals} | {{ vat_period_net }} | {{ vat_period_vat }} | {{ vat_period_gross }}''',
      footer: _legalFooter(l10n),
    );

/// The WORKSPACE REPORT document (#494) as editable bands.
ReportBands _defaultWorkspaceBands(AppLocalizations l10n) => ReportBands(
      header: '''
# {{ workspace }}
{% if seller_legal_form != "" %}> {{ seller_legal_form }}{% endif %}
> {{ workspace_address }}
> {{ issued }}
---''',
      body: '''
{{ country }} · {{ currency }} · {{ timezone }}
> {{ members_count }} · {{ levels_count }} / {{ offices_count }} / {{ desks_count }} / {{ seats_count }}
> {{ open_days }} · {{ work_hours }}

## ${l10n.reportSectionFeatures}
{% for f in features %}{{ f.label }}
{% endfor %}
## ${l10n.reportSectionPrices}
{% for line in lines %}{{ line.label }} | {{ line.amount }}
{% endfor %}''',
      footer: _legalFooter(l10n),
    );

/// The shared letter shape of the simple per-member documents (#494):
/// title + recipient, the lines, an optional totals row, the legal
/// footer. [totalsLine] defaults to the plain balance row.
ReportBands _simpleDocPresetBands(
  AppLocalizations l10n,
  String id,
  String title, {
  required String subtitle,
  String? totalsLine,
}) {
  final totals =
      totalsLine ?? '= ${l10n.billBalance} | {{ total }}';
  const lines = '{% for line in lines %}'
      '{{ line.label }} | {{ line.amount }}\n{% endfor %}';
  switch (id) {
    case 'simple':
      return ReportBands(
        header: '# $title\n$subtitle',
        body: '$lines$totals',
      );
    case 'verbose':
      return ReportBands(
        header: '''
# $title
${_sellerBlock(l10n)}
> $subtitle · {{ issued }}
---''',
        body: '$lines---\n$totals',
        footer: _legalFooter(l10n),
      );
    case 'formal':
      return ReportBands(
        header: '''
${_sellerBlock(l10n)}

{{ member }}

> {{ issued }}''',
        body: '''
## ${l10n.reportSubject}: $title

{{ member }},

$lines---
$totals''',
        footer: '''
${l10n.reportRegards},
{{ workspace }}''',
      );
    default: // classic
      return ReportBands(
        header: '''
# $title
{{ workspace }}
> $subtitle
> {{ issued }}
---''',
        body: '$lines---\n$totals',
        footer: _legalFooter(l10n),
      );
  }
}

/// One ready-made report the owner can pick and then extend (#474).
class ReportPreset {
  const ReportPreset({
    required this.id,
    required this.name,
    required this.bands,
  });

  final String id;
  final String name;
  final ReportBands bands;
}

/// The four preset ids every document ships (#480). The FIRST is the
/// built-in default the uncustomized document renders with.
@visibleForTesting
const List<String> reportPresetIds = ['classic', 'simple', 'verbose', 'formal'];

String _presetName(String id, AppLocalizations l10n) => switch (id) {
      'simple' => l10n.reportPresetSimple,
      'verbose' => l10n.reportPresetVerbose,
      'formal' => l10n.reportPresetFormalLetter,
      _ => l10n.reportPresetClassic,
    };

/// Presets for a STRING document id (#476/#480): 'invoice', 'proforma',
/// 'statement', or 'rN' for reminder level N. Proforma shares the
/// invoice presets (its `{% if proforma %}` branches flip the title).
/// Every document offers the same four: Classic · Simple · Verbose ·
/// Formal.
List<ReportPreset> presetsForDoc(String docId, AppLocalizations l10n) {
  // #1154 — the kind registry decides what [docId] is; the old ladder
  // read anything it did not know as a reminder level (#864's finding,
  // surviving here). An unknown id now gets EMPTY bands, which the
  // designer shows as such, instead of silently editing reminder 1.
  final kind = reportKindById(docId, reminderLevels: kMaxReminderLevels);
  ReportBands bands(String id) => switch (kind?.slot) {
        ReportRootSlot() || ReportProformaSlot() =>
          _invoicePresetBands(l10n, id),
        ReportStatementSlot() => _statementPresetBands(l10n, id),
        // #494 — the further documents share the letter shape.
        ReportDocSlot(key: 'agreement') => _simpleDocPresetBands(
            l10n, id, l10n.reportDocAgreement,
            subtitle: '{{ member }}'),
        ReportDocSlot(key: 'payments') => _defaultPaymentsBands(l10n),
        ReportDocSlot(key: 'usage') => defaultUsageBands(l10n),
        ReportDocSlot(key: 'workspace') => _defaultWorkspaceBands(l10n),
        // One shipped layout each. These documents are structural — a
        // chart, a grid of cards, a table — so the presets that make
        // sense for an invoice (Classic / Formal letter) would only
        // offer ways to break them.
        ReportDocSlot() => defaultBandsForDoc(docId, l10n),
        ReportReminderSlot(:final level) =>
          _reminderPresetBands(level, l10n, id),
        null => ReportBands.empty,
      };

  return [
    if (kind != null)
      ReportPreset(
        id: 'professional',
        name: l10n.reportPresetProfessional,
        bands: defaultBandsForDoc(docId, l10n),
      ),
    for (final id in reportPresetIds)
      ReportPreset(id: id, name: _presetName(id, l10n), bands: bands(id)),
  ];
}

/// The default bands for a STRING document id (#476) — what Reset
/// inserts and what an uncustomized document renders with.
ReportBands defaultBandsForDoc(String docId, AppLocalizations l10n) {
  final kind = reportKindById(docId, reminderLevels: kMaxReminderLevels);
  if (kind == null) return ReportBands.empty;
  return professionalReportBands(
    kind: kind, content: _completeBandsForDoc(docId, l10n), l10n: l10n);
}

ReportBands _completeBandsForDoc(String docId, AppLocalizations l10n) =>
    switch (reportKindById(docId, reminderLevels: kMaxReminderLevels)?.slot) {
      ReportRootSlot() || ReportProformaSlot() =>
        defaultInvoiceTemplate(l10n).invoiceBands,
      ReportStatementSlot() => _defaultStatementBands(l10n),
      ReportDocSlot(key: 'agreement') => _defaultAgreementBands(l10n),
      ReportDocSlot(key: 'payments') => _defaultPaymentsBands(l10n),
      ReportDocSlot(key: 'usage') => defaultUsageBands(l10n),
      ReportDocSlot(key: 'workspace') => _defaultWorkspaceBands(l10n),
      ReportDocSlot(key: 'status') => _defaultStatusBands(l10n),
      ReportDocSlot(key: 'bi_analytics') => analyticsReportBands(l10n.biPdfTitle),
      ReportDocSlot(key: 'workspace_configuration') => configurationReportBands(l10n.workspaceConfigPdfTitle),
      ReportDocSlot(key: 'vat_declaration') => vatDeclarationBandsOf(l10n),
      ReportDocSlot(key: 'vat') => defaultVatBands(l10n),
      ReportDocSlot(key: 'coa') => defaultCoaBands(l10n),
      ReportDocSlot(key: 'badges') => defaultBadgeSheetBands(l10n),
      ReportDocSlot(key: 'space_codes') => defaultSpaceCodesBands(l10n),
      // A doc the registry knows but this ladder does not is a bug to
      // hear about, not a reminder to render.
      ReportDocSlot(:final key) =>
        throw StateError('no default bands for report kind $key'),
      ReportReminderSlot(:final level) => defaultReminderBands(level, l10n),
      // #1154 — an unknown id used to fall through to reminder level 1.
      null => ReportBands.empty,
    };
