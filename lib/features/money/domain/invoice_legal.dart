// SPDX-License-Identifier: AGPL-3.0-or-later
import '../../../core/data/json_reader.dart';
import 'vat_declaration_period.dart';
import 'vat_tax_point.dart';

/// The workspace's LEGAL INVOICE MENTIONS (#480) — the free-text lines a
/// compliant professional invoice must (or may) print beyond the 0069
/// identity. Stored as `workspaces.invoice_legal` jsonb; every field is
/// optional. Which of the four payment clauses ([paymentTerms],
/// [latePenalty], [recoveryIndemnity], [escompte]) print, and whether a
/// default wording fills an empty one, is decided per transaction by
/// `qualifyClauses` (#1916) from the seller's country and the customer's
/// stated capacity — frozen on each invoice at issue.
class InvoiceLegal {
  const InvoiceLegal({
    this.sellerKind = '',
    this.customerCapacity = '',
    this.reverseChargeOptIn = true,
    this.vatTaxPoint,
    this.declarationPeriod,
    this.legalForm = '',
    this.registration = '',
    this.paymentTerms = '',
    this.latePenalty = '',
    this.recoveryIndemnity = '',
    this.escompte = '',
    this.insurance = '',
    this.specialMentions = '',
    this.einvoiceEndpointId = '',
    this.einvoiceEndpointScheme = '',
    this.subdivision = '',
    this.contactEmail = '',
    this.contactPhone = '',
    this.optionToTax = false,
    this.optionToTaxDate = '',
    this.optionToTaxReference = '',
    this.facilitiesPackage = false,
    this.lettingKind = '',
    this.quickMethod = false,
  });

  /// '' (company/business, the default) or 'association' (#484) — a
  /// non-profit under the French loi 1901 model. It names the seller's
  /// legal form and the wording of its positions; since #1916 it no
  /// longer decides which payment clauses apply (a non-profit can act as
  /// an undertaking) — the customer's capacity does.
  final String sellerKind;

  /// #1916 — the workspace's DEFAULT customer capacity: '' (not stated),
  /// 'business' or 'consumer'. A member's own `customer_capacity` wins.
  final String customerCapacity;

  /// #895 — the stored switch; read it through [reverseCharge].
  final bool reverseChargeOptIn;

  /// #2355 — WHEN the tax becomes due, as the owner chose it: the
  /// country's legal default, the invoice date (France's « option pour
  /// les débits ») or cash. Null when the workspace never chose — the
  /// country's default then applies, which in France is receipts. Read
  /// it through [taxPointBasis]: what a choice means depends on the
  /// seller's country (`vat_tax_point.dart`).
  ///
  /// Stored as `vat_tax_point`; the two-value `vat_exigibility` of #896
  /// is still read (`invoice` → the invoice date, `payment` → cash) and
  /// still written beside it for a non-default choice, because the SQL
  /// snapshot freezes that key on every issued invoice (0349, 0401).
  final VatTaxPointOption? vatTaxPoint;

  /// #2357 — how often the VAT return is filed; null when the workspace
  /// never chose ([VatDeclarationPeriod.fallback] then applies). Stored
  /// as `vat_declaration_period`.
  final VatDeclarationPeriod? declarationPeriod;

  /// The period the declarations screen offers.
  VatDeclarationPeriod get filingPeriod =>
      declarationPeriod ?? VatDeclarationPeriod.fallback;

  /// The basis a seller in [country] declares on.
  VatTaxPointBasis taxPointBasis(String country) =>
      vatTaxPointBasis(country, vatTaxPoint);

  /// The #896 two-value key for [country]: `payment` when the tax waits
  /// for the money, `invoice` otherwise — what the printed mention reads.
  String exigibilityIn(String country) =>
      taxPointBasis(country).onReceipts ? 'payment' : 'invoice';

  /// The legacy key written beside [vatTaxPoint] for a non-default
  /// choice; the server derives the default's from the country.
  static String? _legacyExigibility(VatTaxPointOption? option) =>
      switch (option) {
        VatTaxPointOption.invoice => 'invoice',
        VatTaxPointOption.cash => 'payment',
        _ => null,
      };

  /// Whether this seller is a non-profit association.
  bool get isAssociation => sellerKind == 'association';

  /// #895 — whether intra-EU B2B supplies are reverse-charged. On by
  /// law for a VAT-registered seller; a workspace that never invoices
  /// businesses abroad may turn it off.
  bool get reverseCharge => reverseChargeOptIn;

  /// 'SARL au capital de 7 500 €' — legal form and share capital.
  /// For an association: 'Association loi 1901'.
  final String legalForm;

  /// 'RCS Saint-Brieuc 680 357 910' — the trade-register line.
  final String registration;

  /// 'Payment on receipt', '30 days end of month'…
  final String paymentTerms;

  /// The late-payment penalty rate mention (N+1).
  final String latePenalty;

  /// The fixed €40 recovery-cost indemnity mention.
  final String recoveryIndemnity;

  /// The early-payment discount clause ('No discount…').
  final String escompte;

  /// Professional insurance (insurer, coverage area) — artisans.
  final String insurance;

  /// Special regime / CGV / retention-of-title clauses.
  final String specialMentions;

  /// #2358 — the space's electronic address on the e-invoicing networks
  /// (BT-34) and its EAS scheme: frozen as the seller's `endpoint_id` /
  /// `endpoint_scheme` on every invoice (0414).
  final String einvoiceEndpointId;
  final String einvoiceEndpointScheme;

  /// #2358 — BT-39, the county or province (CIUS-RO, the Italian Sede).
  final String subdivision;

  /// #2358 — BG-6, the seller's contact, which XRechnung requires.
  final String contactEmail;
  final String contactPhone;

  /// #2359 — United Kingdom: land is exempt unless the owner opted to tax
  /// the building (VAT Notice 742). The date the option took effect (ISO,
  /// empty: always), HMRC's notification reference, and whether the
  /// workspace sells a serviced package of facilities, which is standard
  /// rated either way. The server reads them in `workspace_taxes_land`.
  final bool optionToTax;
  final String optionToTaxDate;
  final String optionToTaxReference;
  final bool facilitiesPackage;

  /// #2360 — Switzerland: '' (a package of services, taxed at the normal
  /// rate, the ESTV's view of a business centre) or 'bare' (rooms only:
  /// exempt under art. 21 Abs. 2 Ziff. 21 MWSTG unless [optionToTax],
  /// art. 22, is in force). Read by `workspace_taxes_land`.
  final String lettingKind;

  /// #2361 — Canada: the registrant elected the quick method of accounting
  /// for GST/HST (ETA s. 227; remits a fixed share of the tax-included
  /// sales instead of the difference). The return flags it; the remittance
  /// rate is the CRA's, not computed here.
  final bool quickMethod;

  /// The same identity with the UK land-taxation choice replaced.
  InvoiceLegal withLandTaxation({
    required bool optionToTax,
    required String optionToTaxDate,
    required String optionToTaxReference,
    required bool facilitiesPackage,
    String lettingKind = '',
    bool quickMethod = false,
  }) => InvoiceLegal(
    sellerKind: sellerKind,
    customerCapacity: customerCapacity,
    reverseChargeOptIn: reverseChargeOptIn,
    vatTaxPoint: vatTaxPoint,
    declarationPeriod: declarationPeriod,
    legalForm: legalForm,
    registration: registration,
    paymentTerms: paymentTerms,
    latePenalty: latePenalty,
    recoveryIndemnity: recoveryIndemnity,
    escompte: escompte,
    insurance: insurance,
    specialMentions: specialMentions,
    einvoiceEndpointId: einvoiceEndpointId,
    einvoiceEndpointScheme: einvoiceEndpointScheme,
    subdivision: subdivision,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    optionToTax: optionToTax,
    optionToTaxDate: optionToTaxDate,
    optionToTaxReference: optionToTaxReference,
    facilitiesPackage: facilitiesPackage,
    lettingKind: lettingKind,
    quickMethod: quickMethod,
  );

  /// The same identity with the e-invoicing address fields replaced.
  InvoiceLegal withEInvoiceAddress({
    required String endpointId,
    required String endpointScheme,
    required String subdivision,
    required String contactEmail,
    required String contactPhone,
  }) => InvoiceLegal(
    sellerKind: sellerKind,
    customerCapacity: customerCapacity,
    reverseChargeOptIn: reverseChargeOptIn,
    vatTaxPoint: vatTaxPoint,
    declarationPeriod: declarationPeriod,
    legalForm: legalForm,
    registration: registration,
    paymentTerms: paymentTerms,
    latePenalty: latePenalty,
    recoveryIndemnity: recoveryIndemnity,
    escompte: escompte,
    insurance: insurance,
    specialMentions: specialMentions,
    einvoiceEndpointId: endpointId,
    einvoiceEndpointScheme: endpointScheme,
    subdivision: subdivision,
    contactEmail: contactEmail,
    contactPhone: contactPhone,
    optionToTax: optionToTax,
    optionToTaxDate: optionToTaxDate,
    optionToTaxReference: optionToTaxReference,
    facilitiesPackage: facilitiesPackage,
    lettingKind: lettingKind,
    quickMethod: quickMethod,
  );

  /// Client-side cap per field — these are printed lines, not essays.
  static const int maxFieldLength = 300;

  factory InvoiceLegal.fromJson(Map<dynamic, dynamic> json) {
    final r = JsonReader.of(json, context: 'invoice_legal');
    return InvoiceLegal(
      sellerKind: r.stringOr('seller_kind'),
      customerCapacity: switch (r.stringOrNull('customer_capacity')) {
        final String c when c == 'business' || c == 'consumer' => c,
        _ => '',
      },
      reverseChargeOptIn: r.boolOr('reverse_charge', fallback: true),
      vatTaxPoint:
          VatTaxPointOption.fromWire(r.stringOrNull('vat_tax_point')) ??
              switch (r.stringOrNull('vat_exigibility')) {
                'invoice' => VatTaxPointOption.invoice,
                'payment' => VatTaxPointOption.cash,
                _ => null,
              },
      declarationPeriod: VatDeclarationPeriod.fromWire(
        r.stringOrNull('vat_declaration_period'),
      ),
      legalForm: r.stringOr('legal_form'),
      registration: r.stringOr('registration'),
      paymentTerms: r.stringOr('payment_terms'),
      latePenalty: r.stringOr('late_penalty'),
      recoveryIndemnity: r.stringOr('recovery_indemnity'),
      escompte: r.stringOr('escompte'),
      insurance: r.stringOr('insurance'),
      specialMentions: r.stringOr('special_mentions'),
      einvoiceEndpointId: r.stringOr('einvoice_endpoint_id'),
      einvoiceEndpointScheme: r.stringOr('einvoice_endpoint_scheme'),
      subdivision: r.stringOr('subdivision'),
      contactEmail: r.stringOr('contact_email'),
      contactPhone: r.stringOr('contact_phone'),
      optionToTax: r.boolOr('option_to_tax', fallback: false),
      optionToTaxDate: r.stringOr('option_to_tax_date'),
      optionToTaxReference: r.stringOr('option_to_tax_reference'),
      facilitiesPackage: r.boolOr('facilities_package', fallback: false),
      lettingKind: r.stringOr('letting_kind'),
      quickMethod: r.boolOr('quick_method', fallback: false),
    );
  }

  Map<String, Object?> toJson() => {
        'seller_kind': sellerKind,
        'customer_capacity': customerCapacity,
        'reverse_charge': reverseChargeOptIn,
        'vat_tax_point': ?vatTaxPoint?.name,
        'vat_exigibility': ?_legacyExigibility(vatTaxPoint),
        'vat_declaration_period': ?declarationPeriod?.name,
        'legal_form': legalForm.trim(),
        'registration': registration.trim(),
        'payment_terms': paymentTerms.trim(),
        'late_penalty': latePenalty.trim(),
        'recovery_indemnity': recoveryIndemnity.trim(),
        'escompte': escompte.trim(),
        'insurance': insurance.trim(),
        'special_mentions': specialMentions.trim(),
        'einvoice_endpoint_id': einvoiceEndpointId.trim(),
        'einvoice_endpoint_scheme': einvoiceEndpointScheme.trim(),
        'subdivision': subdivision.trim(),
        'contact_email': contactEmail.trim(),
        'contact_phone': contactPhone.trim(),
        if (optionToTax || facilitiesPackage || lettingKind.isNotEmpty) ...{
          'option_to_tax': optionToTax,
          'option_to_tax_date': optionToTax ? optionToTaxDate.trim() : '',
          'option_to_tax_reference': optionToTax ? optionToTaxReference.trim() : '',
          'facilities_package': facilitiesPackage,
          'letting_kind': lettingKind,
        },
        if (quickMethod) 'quick_method': true,
      };

  @override
  bool operator ==(Object other) =>
      other is InvoiceLegal &&
      other.sellerKind == sellerKind &&
      other.customerCapacity == customerCapacity &&
      other.reverseChargeOptIn == reverseChargeOptIn &&
      other.vatTaxPoint == vatTaxPoint &&
      other.declarationPeriod == declarationPeriod &&
      other.legalForm == legalForm &&
      other.registration == registration &&
      other.paymentTerms == paymentTerms &&
      other.latePenalty == latePenalty &&
      other.recoveryIndemnity == recoveryIndemnity &&
      other.escompte == escompte &&
      other.insurance == insurance &&
      other.specialMentions == specialMentions &&
      other.einvoiceEndpointId == einvoiceEndpointId &&
      other.einvoiceEndpointScheme == einvoiceEndpointScheme &&
      other.subdivision == subdivision &&
      other.contactEmail == contactEmail &&
      other.contactPhone == contactPhone &&
      other.optionToTax == optionToTax &&
      other.optionToTaxDate == optionToTaxDate &&
      other.optionToTaxReference == optionToTaxReference &&
      other.facilitiesPackage == facilitiesPackage &&
      other.lettingKind == lettingKind &&
      other.quickMethod == quickMethod;

  @override
  int get hashCode => Object.hashAll([
        vatTaxPoint, declarationPeriod, reverseChargeOptIn, sellerKind,
        customerCapacity, legalForm, registration, paymentTerms, latePenalty,
        recoveryIndemnity, escompte, insurance, specialMentions,
        einvoiceEndpointId, einvoiceEndpointScheme, subdivision, contactEmail,
        contactPhone, optionToTax, optionToTaxDate, optionToTaxReference,
        facilitiesPackage, lettingKind, quickMethod,
      ]);
}
