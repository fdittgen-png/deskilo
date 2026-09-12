// SPDX-License-Identifier: 0BSD
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

import '../../../core/i18n/money_format.dart';
import '../../profile/domain/personal_info.dart';
import '../../workspace/domain/payment_instructions.dart';
import '../../workspace/domain/workspace.dart';
import 'invoice.dart';
import 'invoice_legal.dart';
import 'invoice_line_text.dart';
import 'payment_terms.dart';
import 'period_label.dart';
import 'report_strings.dart';
import 'vat_compliance.dart';
import 'vat_rate.dart';
import 'vat_regime.dart';

/// The LEGAL mention variables (#480) shared by every document's data
/// model: the seller's statutory lines and the payment-condition
/// mentions French law requires on a professional invoice. The four
/// mandatory clauses fall back to localized statutory defaults when the
/// owner configured nothing, so an untouched workspace still issues a
/// compliant document. [seller] (the invoice's frozen party) wins over
/// the live [workspace] for the identity numbers — the snapshot is what
/// the signature covers.
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
  // #881 — the member's own conditions on top of the workspace's.
  PaymentTerms? memberTerms,
}) {
  final legal = InvoiceLegal.fromJson(workspace?.invoiceLegal ?? const {});
  final terms = PaymentTerms.ofLegal(legal).mergedWith(memberTerms);
  // #871 — the bank block. A French (and German) invoice carries the
  // account it is to be paid into, and until now a designed report
  // could not print one: the details were stored but no placeholder
  // reached them, so the only way to show an IBAN was to type it into
  // the template and let it rot there when the account changed.
  final pay = PaymentInstructions.fromDb(
    workspace?.paymentInstructions ?? const {},
  );
  String orDefault(String value, String fallback) =>
      value.trim().isNotEmpty ? value.trim() : fallback;
  // #484 — the B2B-only clauses (mandatory between professionals) have
  // NO default on an association's documents; explicit text still wins.
  String orB2bDefault(String value, String fallback) =>
      legal.isAssociation ? value.trim() : orDefault(value, fallback);
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
    'seller_legal_form': legal.legalForm,
    'seller_registration': legal.registration,
    'seller_vat_id': seller?.vatId ?? workspace?.vatId ?? '',
    'seller_legal_id': seller?.legalId ?? workspace?.legalId ?? '',
    // #878 — BR-E-10: an exempt (or out-of-scope) seller's document
    // carries the statutory mention of its member state when the owner
    // wrote none; a VAT-charging seller prints nothing here.
    // #896 — WHEN the tax falls due, said on the document.
    'vat_exigibility_mention': exigibilityMention(
      regime: vatRegimeFromWire(
          seller?.vatRegime ?? workspace?.vatRegime ?? 'not_subject'),
      sellerCountry: seller?.country ?? workspace?.countryCode ?? '',
      onPaymentBasis: legal.onPaymentBasis,
    ),
    // #895 — a reverse-charged supply states WHY no tax is charged, and
    // that mention is statutory: it wins over the seller's own text.
    'exemption_reason': reverseCharged
        ? reverseChargeMention(seller?.country ?? workspace?.countryCode ?? '')
        : counterpartyCategory == 'G'
            ? exportMention(seller?.country ?? workspace?.countryCode ?? '')
            : counterpartyCategory == 'E' &&
                    (buyer?.taxExemptionReason.trim().isNotEmpty ?? false)
                ? buyer!.taxExemptionReason.trim()
                : orDefault(
            seller?.taxExemptionReason ?? workspace?.taxExemptionReason ?? '',
            defaultExemptionMention(
              seller?.country ?? workspace?.countryCode ?? '',
              vatRegimeFromWire(
                  seller?.vatRegime ?? workspace?.vatRegime ?? 'not_subject'),
            ),
          ),
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
    'payment_terms_source': memberTerms == null ? 'workspace' : 'member',
    'payment_terms': orDefault(
      terms.paymentTerms,
      strings.paymentTermsDefault,
    ),
    'late_penalty': orB2bDefault(
      terms.latePenalty,
      strings.latePenaltyDefault,
    ),
    'recovery_indemnity': orB2bDefault(
      terms.recoveryIndemnity,
      strings.recoveryDefault,
    ),
    'escompte': orB2bDefault(
      terms.escompte,
      strings.escompteDefault,
    ),
    'insurance': legal.insurance,
    'special_mentions': legal.specialMentions,
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

/// The client's full name: the frozen buyer party, else the snapshot,
/// else the frozen company (#910).
String clientNameOf(Invoice invoice) => invoice.clientName;

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
}) {
  final currency = moneyFormat(invoice.currency);
  final dateFormat = DateFormat.yMMMd(strings.dateLocale);
  String money(int cents) => currency.formatMinor(cents);
  // #870 — an association's positions are participations, not
  // subscriptions; the same word everywhere the document is produced.
  final association = InvoiceLegal.fromJson(
    workspace?.invoiceLegal ?? const {},
  ).isAssociation;
  String rate(double percent) =>
      '${percent == percent.roundToDouble() ? percent.toStringAsFixed(0) : percent} %';
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
    'total': money(invoice.totalCents),
    'charges': money(invoice.chargesCents),
    'payments': money(
      invoice.lines
          .where((l) => l.amountCents < 0)
          .fold(0, (sum, l) => sum + l.amountCents),
    ),
    // #480 — total HT / total TVA beside the TTC the bands always had.
    'net_total': money(invoice.netCents),
    'vat_total': money(invoice.vatCents),
    'voided': invoice.isVoided,
    'proforma': proforma,
    'copy': copy,
    // #508 — a negative document is a credit note the workspace pays.
    'credit_note': invoice.totalCents < 0,
    'refund_total': money(-invoice.totalCents),
    'has_vat': invoice.vatTotals.any((t) => t.vatCents > 0),
    'lines': [
      for (final line in invoice.lines)
        {
          'label': invoiceLineText(strings, line,
              association: association, period: invoice.period),
          // #1002 — what the line IS, its percentage and its month, so
          // a design composes its own wording for the recurring position.
          'kind': line.kind,
          'pct': line.kind == 'subscription' ? line.label : '',
          'month': monthNameOf(strings.localeName, invoice.period),
          'amount': money(line.amountCents),
          'negative': line.amountCents < 0,
          // #480 — quantity, unit price and per-line VAT so a template
          // can print the statutory line detail.
          'qty': '${line.quantity}',
          'unit_price': money(
            line.quantity > 1
                ? line.amountCents ~/ line.quantity
                : line.amountCents,
          ),
          'vat_rate': line.vatPercent > 0 ? rate(line.vatPercent) : '',
          'net': money(vatSplit(line.amountCents, line.vatPercent).netCents),
        },
    ],
    'vat': [
      for (final t in invoice.vatTotals.where((t) => t.vatCents > 0))
        {
          'rate': rate(t.percent),
          'net': money(t.netCents),
          'amount': money(t.vatCents),
        },
    ],
    ...legalMentionData(
      strings,
      workspace,
      seller: invoice.sellerParty,
      buyer: invoice.buyerParty,
      clientAddress: clientAddressOf(invoice, workspace, strings),
      clientName: clientNameOf(invoice),
      reverseCharged: invoice.isReverseCharged,
      counterpartyCategory: invoice.counterpartyCategory,
      memberTerms: memberTerms,
    ),
  };
}

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
