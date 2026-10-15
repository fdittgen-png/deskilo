// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1061 / #1048 task 3.1 — the invoice data builders, in domain/ (the
// letters — statement, agreement, payments, workspace, reminder — are
// report_data_letters.dart).
//
// Every function here is a pure function of a `ReportStrings`, the
// facts it is handed and the invoice or statement it describes: no
// BuildContext, no WidgetRef, no Flutter. The gatherers that fill the
// facts from the providers are presentation/report_facts_of.dart; the
// widget boundary for the words is presentation/report_strings_l10n.dart.
import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

import '../../../core/i18n/money_format.dart';
import '../../../core/time/date_text.dart';
import '../../profile/domain/personal_info.dart';
import '../../workspace/domain/payment_instructions.dart';
import '../../workspace/domain/workspace.dart';
import 'invoice.dart';
import 'invoice_clauses.dart';
import 'invoice_legal.dart';
import 'invoice_line_text.dart';
import 'invoice_sales_tax.dart';
import 'payment_terms.dart';
import 'period_label.dart';
import 'report_strings.dart';
import 'vat_compliance.dart';
import 'vat_components.dart';
import 'vat_rate.dart';
import 'vat_regime.dart';

/// The LEGAL mention variables (#480) shared by every document's data
/// model: the seller's statutory lines and the payment clauses. Which
/// clauses print is qualified by `qualifyClauses` (#1916) from the law
/// of the transaction and the customer's capacity: an issued invoice
/// passes its [frozen] snapshot (0349), so later settings never rewrite
/// it; a [legacy] invoice (issued before 0349) keeps the rule it was
/// printed under; anything else qualifies the live settings, with the
/// [memberCapacity] over the workspace default. [seller] (the invoice's
/// frozen party) wins over the live [workspace] for the identity
/// numbers — the snapshot is what the signature covers.
Map<String, Object?> legalMentionData(
  ReportStrings strings,
  Workspace? workspace, {
  InvoiceParty? seller,
  InvoiceParty? buyer,
  String clientAddress = '',
  String clientName = '',
  /// #895 — the document is an intra-EU B2B supply: the customer owes
  /// the tax and the mention says so.
  bool reverseCharged = false,
  /// #985 — the counterparty's category when it decided (G, E).
  String counterpartyCategory = '',

  /// #2440 — BT-120 per VAT category: the distinct reasons the exempt
  /// subtotals froze, in order.
  List<String> rateExemptionReasons = const [],
  // #881 — the member's own conditions on top of the workspace's.
  PaymentTerms? memberTerms,
  /// #1916 — the invoice's legal facts as frozen at issue.
  LegalClauseSnapshot? frozen,
  /// #1916 — an issued invoice older than the snapshot.
  bool legacy = false,
  /// #1916 — the member's own stated capacity (wire), live documents.
  String? memberCapacity,
}) {
  final legal = InvoiceLegal.fromJson(workspace?.invoiceLegal ?? const {});
  final terms = PaymentTerms.ofLegal(legal).mergedWith(memberTerms);
  final sellerCountry = seller?.country ?? workspace?.countryCode ?? '';
  final clauses = frozen != null
      ? qualifyClauses(frozen, strings)
      : legacy
          ? legacyClauses(legal, terms, strings)
          : qualifyClauses(
              LegalClauseSnapshot.live(
                legal: legal,
                sellerCountry: sellerCountry,
                buyerCountry: buyer?.country ?? '',
                memberTerms: memberTerms,
                memberCapacity: memberCapacity,
              ),
              strings);
  // #871 — the bank block. A French (and German) invoice carries the
  // account it is to be paid into, and until now a designed report
  // could not print one: the details were stored but no placeholder
  // reached them, so the only way to show an IBAN was to type it into
  // the template and let it rot there when the account changed.
  final pay = PaymentInstructions.fromDb(
    workspace?.paymentInstructions ?? const {},
  );
  return <String, Object?>{
    'iban': pay.iban,
    'bic': pay.bic,
    'bank_name': pay.bankName,
    'bank_account': pay.accountNumber,
    'bank_code': pay.bankCode,
    // The holder is the seller; an invoice never asks to be paid to
    // anyone else, so this is not a separate field to get wrong.
    'account_holder': workspace?.name ?? '',
    'payment_reference': pay.reference,
    'seller_legal_form': frozen?.legalForm ?? legal.legalForm,
    'seller_registration': frozen?.registration ?? legal.registration,
    // #2360 — a Swiss UID prints the way art. 26 MWSTG shows it.
    'seller_vat_id': sellerCountry.trim().toUpperCase() == 'CH' &&
            isValidSwissUid(seller?.vatId ?? workspace?.vatId ?? '',
                requireSuffix: false)
        ? formatSwissUid(seller?.vatId ?? workspace?.vatId ?? '')
        // #2361 — a Canadian business number prints as 123456789 RT0001.
        : sellerCountry.trim().toUpperCase() == 'CA' &&
                isValidCanadianBn(seller?.vatId ?? workspace?.vatId ?? '')
            ? formatCanadianRegistration(seller?.vatId ?? workspace?.vatId ?? '')
            : seller?.vatId ?? workspace?.vatId ?? '',
    // #2361 — and Revenu Québec's number, kept here, as 1234567890 TQ0001.
    'seller_legal_id': sellerCountry.trim().toUpperCase() == 'CA' &&
            isValidQstNumber(seller?.legalId ?? workspace?.legalId ?? '')
        ? formatCanadianRegistration(seller?.legalId ?? workspace?.legalId ?? '')
        : seller?.legalId ?? workspace?.legalId ?? '',
    // #878/#895/#896 — the statutory mentions: why no tax is charged and
    // when it falls due (#2478: the texts are reference data).
    ...statutoryMentionData((
      workspace: workspace,
      seller: seller,
      buyer: buyer,
      reverseCharged: reverseCharged,
      counterpartyCategory: counterpartyCategory,
      rateExemptionReasons: rateExemptionReasons,
      frozen: frozen,
    )),
    // #886 — the client as the postal standard prints them: the full
    // name on its own line, the block (company · street · POSTAL CITY ·
    // country when abroad) beneath, the contacts beside.
    'client_name': clientName,
    'client_company': buyer?.company ?? '',
    'client_phone': buyer?.phone ?? '',
    'client_email': buyer?.email ?? '',
    'client_address': clientAddress,
    // #482 — the client's own identifiers on B2B documents.
    'client_vat_id': buyer?.vatId ?? '',
    'client_legal_id': buyer?.legalId ?? '',
    'client_member_number': buyer?.memberNumber ?? '',
    // #881 — whether anything printed is the member's own condition.
    'payment_terms_source': frozen?.termsSource ??
        (memberTerms == null ? 'workspace' : 'member'),
    // #1916 — qualified per transaction, never by the reader's language.
    'payment_terms': clauses.paymentTerms.text,
    'late_penalty': clauses.latePenalty.text,
    'recovery_indemnity': clauses.recoveryIndemnity.text,
    'escompte': clauses.escompte.text,
    'insurance': frozen?.insurance ?? legal.insurance,
    'special_mentions': frozen?.specialMentions ?? legal.specialMentions,
  };
}

/// The client's postal block as the document prints it — one line per
/// element, the same renderer as the profile form and the SQL twin
/// (#886) — from the frozen buyer party (0069) or the flat snapshot on
/// legacy invoices.
String clientAddressOf(
    Invoice invoice, Workspace? workspace, ReportStrings strings) {
  final buyer = invoice.buyerParty;
  if (buyer == null) return invoice.memberAddress;
  final person = buyer.person.trim();
  return PersonalInfo(
    company: buyer.company,
    // #912 — the person inside the organisation, rebuilt into the two
    // halves the block renders from. Only the rendering cares which is
    // which, and the frozen party keeps the name whole.
    firstName: person,
    street: buyer.street,
    postalCode: buyer.postalCode,
    city: buyer.city,
    countryCode: buyer.country,
  ).postalBlock(
    workspaceCountry: workspace?.countryCode ?? '',
    // #910 — the name the document prints above this block. When the
    // client IS the company, the block drops it rather than saying it
    // twice; when a person is named, the company stays where it belongs.
    nameAbove: clientNameOf(invoice),
    // #912 — in the reader's language, from the code the party froze.
    courtesyWord: strings.courtesyWord(Courtesy.fromWire(buyer.courtesy)),
  );
}

/// [legalMentionData] of an invoice: its frozen parties and clauses, and the
/// statutory texts in force on the day it was issued (#2478), so a text
/// changed later never reaches a document issued before.
Map<String, Object?> _invoiceLegalMentionData(
  ReportStrings strings,
  Invoice invoice,
  Workspace? workspace, {
  PaymentTerms? memberTerms,
  String? memberCapacity,
}) {
  final rateReasons = {
    for (final t in invoice.vatTotals)
      if (t.exemptionReason.isNotEmpty) t.exemptionReason,
  }.toList();
  return {
    ...legalMentionData(
      strings,
      workspace,
      seller: invoice.sellerParty,
      buyer: invoice.buyerParty,
      clientAddress: clientAddressOf(invoice, workspace, strings),
      clientName: clientNameOf(invoice),
      reverseCharged: invoice.isReverseCharged,
      counterpartyCategory: invoice.counterpartyCategory,
      rateExemptionReasons: rateReasons,
      memberTerms: memberTerms,
      frozen: invoice.legalClauses,
      legacy: isLegacyInvoice(invoice),
      memberCapacity: memberCapacity,
    ),
    ...statutoryMentionData((
      workspace: workspace,
      seller: invoice.sellerParty,
      buyer: invoice.buyerParty,
      reverseCharged: invoice.isReverseCharged,
      counterpartyCategory: invoice.counterpartyCategory,
      rateExemptionReasons: rateReasons,
      frozen: invoice.legalClauses,
    ), asOf: isoDay(invoice.issuedAt)),
  };
}

/// The client's full name: the frozen buyer party, else the snapshot,
/// else the frozen company (#910).
String clientNameOf(Invoice invoice) => invoice.clientName;

String _rateText(double percent) =>
    '${percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent} %';

/// One position of the invoice as the placeholders of a design read it.
Map<String, Object?> _lineData(ReportStrings strings, Invoice invoice,
    InvoiceLine line, MoneyFormat currency,
    {required bool association}) {
  // #2362 -- a sales-tax line quotes its net price; its tax is stated below.
  final quoted = invoice.quotedCents(line);
  return {
    'label': invoiceLineText(strings, line,
        association: association, period: invoice.period),
    // #1002 — what the line IS, its percentage and its month, so a design
    // composes its own wording for the recurring position.
    'kind': line.kind,
    'pct': line.kind == 'subscription' ? line.label : '',
    'month': monthNameOf(strings.localeName, invoice.period),
    'amount': currency.formatMinor(quoted),
    'negative': line.amountCents < 0,
    // #480 — quantity, unit price and per-line VAT so a template can print
    // the statutory line detail.
    'qty': '${line.quantity}',
    'unit_price': currency
        .formatMinor(line.quantity > 1 ? quoted ~/ line.quantity : quoted),
    'vat_rate': line.vatPercent > 0 && !invoice.isSalesTax
        ? _rateText(line.vatPercent)
        : '',
    'net': currency.formatMinor(invoice.isSalesTax
        ? quoted
        : vatSplit(line.amountCents, line.vatPercent).netCents),
  };
}

/// The report data model (#470/#474) — every value the Liquid bands
/// can reference, resolved where formatting is at hand. Amounts arrive
/// pre-formatted in the workspace currency; the flags feed
/// `{% if %}` conditions. Shared by the PDF render AND the in-app
/// quick preview. [workspace] feeds the legal mention variables (#480);
/// null leaves the seller lines empty and the clauses on their
/// localized statutory defaults.
Map<String, Object?> invoiceReportData(
  ReportStrings strings,
  Invoice invoice, {
  required bool proforma,
  required bool copy,
  Workspace? workspace,
  PaymentTerms? memberTerms,
  /// #910 — the day the settlement is due. A French invoice must carry
  /// it (art. L441-9 code de commerce), and until now the document said
  /// only "à 30 jours" in prose while the app showed a date computed
  /// from the reminder delay: two deadlines, neither of them stated on
  /// the paper. Null leaves the placeholder empty.
  DateTime? dueAt,
  /// #1916 — the member's stated capacity, for an unissued document.
  String? memberCapacity,
}) {
  final currency = moneyFormat(invoice.currency);
  final dateFormat = DateFormat.yMMMd(strings.dateLocale);
  // #870 — an association's positions are participations, not
  // subscriptions; the same word everywhere the document is produced.
  final association = InvoiceLegal.fromJson(
    workspace?.invoiceLegal ?? const {},
  ).isAssociation;
  final legalData = _invoiceLegalMentionData(strings, invoice, workspace,
      memberTerms: memberTerms, memberCapacity: memberCapacity);
  // #2356 — what the seller's own law adds (IT stamp duty, ES correcting
  // invoice, FR category of the operation), after the owner's mentions.
  final national = nationalInvoiceMentions(
    sellerCountry: invoice.sellerParty?.country ?? workspace?.countryCode ?? '',
    regime: vatRegimeFromWire(
        invoice.sellerParty?.vatRegime ?? workspace?.vatRegime ?? 'not_subject'),
    currency: invoice.currency,
    untaxedCents: invoice.vatTotals
        .where((t) => t.vatCents == 0 && t.category != 'AE')
        .fold(0, (sum, t) => sum + t.grossCents),
    correction: invoice.isCreditNote || invoice.replacesNumber.isNotEmpty,
    rectifies: invoice.replacesNumber,
    correctionReason: invoice.correctionReason,
    sellerVatId: invoice.sellerParty?.vatId ?? workspace?.vatId ?? '',
    sellerLegalId: invoice.sellerParty?.legalId ?? workspace?.legalId ?? '',
    qstCharged: invoice.vatTotals.any(
        (t) => t.components.any((c) => c.scheme == 'QST' && c.taxCents != 0)),
  );
  return <String, Object?>{
    'workspace': invoice.workspaceName,
    'workspace_address': invoice.workspaceAddress,
    // #946 — the site the document concerns, when it is not the default
    // one, and the other sites the month's attendance stood at.
    'site_name': siteNameOf(invoice),
    'site_address': siteAddressOf(invoice),
    'usage_sites': usageSitesOf(invoice),
    'member': invoice.clientName,
    'number': invoice.number,
    'period': invoicePeriodLabelOf(strings.dateLocale, invoice),
    // #1002 — the month's name and the year on their own, for a designed
    // label such as « {{ period_month }} 100 % ».
    'period_month': monthNameOf(strings.localeName, invoice.period),
    'period_year': invoice.period?.split('-').first ?? '',
    'issued': dateFormat.format(invoice.issuedAt),
    // #910 — the settlement date, on the document itself.
    'due_date': dueAt == null || invoice.number.isEmpty
        ? ''
        : dateFormat.format(dueAt),
    // #922 — what Chorus Pro reads from the XML, said on the paper too.
    'purchase_order': invoice.buyerParty?.orderReference ?? '',
    'buyer_reference': invoice.buyerParty?.reference ?? '',
    'issued_by': invoice.issuerName,
    'replaces': invoice.replacesNumber,
    'total': currency.formatMinor(invoice.totalCents),
    'charges': currency.formatMinor(invoice.chargesCents),
    'payments': currency.formatMinor(
      invoice.lines
          .where((l) => l.amountCents < 0)
          .fold(0, (sum, l) => sum + l.amountCents),
    ),
    // #480 — total HT / total TVA beside the TTC the bands always had.
    'net_total': currency.formatMinor(invoice.netCents),
    'vat_total': currency.formatMinor(invoice.vatCents),
    'voided': invoice.isVoided,
    'proforma': proforma,
    'copy': copy,
    // #508 — a negative document is a credit note the workspace pays.
    'credit_note': invoice.totalCents < 0,
    'refund_total': currency.formatMinor(-invoice.totalCents),
    'has_vat': invoice.vatTotals.any((t) => t.vatCents > 0),
    'lines': [
      for (final line in invoice.lines)
        _lineData(strings, invoice, line, currency, association: association),
    ],
    'vat': [
      for (final t in invoice.vatTotals.where((t) => t.vatCents > 0))
        // #2361 — a Canadian total states its GST / HST / QST apart, each on
        // its own base: GST 5 % 50.00, QST 9,975 % 99.75.
        if (t.components.isEmpty)
          {
            'rate': _rateText(t.percent),
            'net': currency.formatMinor(t.netCents),
            'amount': currency.formatMinor(t.vatCents),
          }
        else
          for (final c in t.components)
            {
              // #2362 -- a sales tax goes by the jurisdiction that levies it.
              'rate': '${c.name.isNotEmpty ? c.name : taxSchemeName(c.scheme, strings.localeName ?? '')} '
                  '${_rateText(c.percent)}',
              'net': currency.formatMinor(c.baseCents),
              'amount': currency.formatMinor(c.taxCents),
            },
    ],
    ...legalData,
    if (national.isNotEmpty)
      'special_mentions': [
        '${legalData['special_mentions'] ?? ''}'.trim(),
        ...national,
      ].where((m) => m.isNotEmpty).join('\n'),
  };
}

/// #1916 — an ISSUED invoice that carries no legal snapshot: issued
/// before 0349, its evidence is unknown and it renders as it always did.
/// An unnumbered document (a preview) is not legacy: it qualifies live.
bool isLegacyInvoice(Invoice invoice) =>
    invoice.legalSnapshot == null && invoice.number.isNotEmpty;

/// #946 — the site a document concerns, when it is not the default one.
String siteNameOf(Invoice invoice) {
  final seller = invoice.sellerParty;
  return seller == null || seller.siteDefault ? '' : seller.site;
}

/// #946 — that site's address on one line, '' at the default site.
String siteAddressOf(Invoice invoice) {
  final seller = invoice.sellerParty;
  if (seller == null || seller.siteDefault) return '';
  return [seller.street, '${seller.postalCode} ${seller.city}'.trim()]
      .where((l) => l.isNotEmpty)
      .join(', ');
}

/// #946 — the other sites the month's attendance stood at.
String usageSitesOf(Invoice invoice) {
  final home = invoice.sellerParty?.site ?? '';
  return invoice.attendance
      .map((a) => a.site)
      .where((s) => s.isNotEmpty && s != home)
      .toSet()
      .join(', ');
}

// #2478 (C2 of #2476) -- the two statutory lines of a document: WHY no tax is
// charged (BT-120) and WHEN it falls due. The texts are reference data
// (`exemption_text` rows); [asOf] is the day of the document.
/// What decides the mentions: the live workspace, overridden by the frozen
/// parties and snapshot of an issued document.
@visibleForTesting
typedef StatutoryMentionInput = ({
  Workspace? workspace,
  InvoiceParty? seller,
  InvoiceParty? buyer,
  bool reverseCharged,
  String counterpartyCategory,
  List<String> rateExemptionReasons,
  LegalClauseSnapshot? frozen,
});

/// `vat_exigibility_mention` and `exemption_reason` of a document.
@visibleForTesting
Map<String, Object?> statutoryMentionData(StatutoryMentionInput c, {String? asOf}) {
  final country = c.seller?.country ?? c.workspace?.countryCode ?? '';
  final regime = vatRegimeFromWire(
      c.seller?.vatRegime ?? c.workspace?.vatRegime ?? 'not_subject');
  final legal = InvoiceLegal.fromJson(c.workspace?.invoiceLegal ?? const {});
  // #895 — a reverse-charged supply states WHY no tax is charged, and that
  // mention is statutory: it wins over the seller's own text.
  final buyerReason = c.buyer?.taxExemptionReason.trim() ?? '';
  final own = (c.seller?.taxExemptionReason ?? c.workspace?.taxExemptionReason ?? '').trim();
  final reason = c.reverseCharged
      ? reverseChargeMention(country, asOf: asOf)
      : c.counterpartyCategory == 'G'
          ? exportMention(country, asOf: asOf)
          : c.counterpartyCategory == 'E' && buyerReason.isNotEmpty
              ? buyerReason
              // #2440 — BT-120 per VAT category: each exempt subtotal
              // states its own rate's reason, once.
              : c.rateExemptionReasons.isNotEmpty
                  ? c.rateExemptionReasons.join('\n')
                  : own.isNotEmpty
                      ? own
                      : defaultExemptionMention(
                          country,
                          regime,
                          vatId: c.seller?.vatId ?? c.workspace?.vatId ?? '',
                          asOf: asOf,
                        );
  return {
    // #896 — WHEN the tax falls due, said on the document.
    'vat_exigibility_mention': exigibilityMention(
      regime: regime,
      sellerCountry: country,
      onPaymentBasis:
          c.frozen?.onPaymentBasis ?? legal.taxPointBasis(country).onReceipts,
      asOf: asOf,
    ),
    'exemption_reason': reason,
  };
}
