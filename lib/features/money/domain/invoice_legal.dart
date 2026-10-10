// SPDX-License-Identifier: AGPL-3.0-or-later
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
    this.legalForm = '',
    this.registration = '',
    this.paymentTerms = '',
    this.latePenalty = '',
    this.recoveryIndemnity = '',
    this.escompte = '',
    this.insurance = '',
    this.specialMentions = '',
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

  /// Client-side cap per field — these are printed lines, not essays.
  static const int maxFieldLength = 300;

  factory InvoiceLegal.fromJson(Map<dynamic, dynamic> json) => InvoiceLegal(
        sellerKind: json['seller_kind'] as String? ?? '',
        customerCapacity: switch (json['customer_capacity']) {
          final String c when c == 'business' || c == 'consumer' => c,
          _ => '',
        },
        reverseChargeOptIn: json['reverse_charge'] as bool? ?? true,
        vatTaxPoint:
            VatTaxPointOption.fromWire(json['vat_tax_point'] as String?) ??
                switch (json['vat_exigibility']) {
                  'invoice' => VatTaxPointOption.invoice,
                  'payment' => VatTaxPointOption.cash,
                  _ => null,
                },
        legalForm: json['legal_form'] as String? ?? '',
        registration: json['registration'] as String? ?? '',
        paymentTerms: json['payment_terms'] as String? ?? '',
        latePenalty: json['late_penalty'] as String? ?? '',
        recoveryIndemnity: json['recovery_indemnity'] as String? ?? '',
        escompte: json['escompte'] as String? ?? '',
        insurance: json['insurance'] as String? ?? '',
        specialMentions: json['special_mentions'] as String? ?? '',
      );

  Map<String, Object?> toJson() => {
        'seller_kind': sellerKind,
        'customer_capacity': customerCapacity,
        'reverse_charge': reverseChargeOptIn,
        'vat_tax_point': ?vatTaxPoint?.name,
        'vat_exigibility': ?_legacyExigibility(vatTaxPoint),
        'legal_form': legalForm.trim(),
        'registration': registration.trim(),
        'payment_terms': paymentTerms.trim(),
        'late_penalty': latePenalty.trim(),
        'recovery_indemnity': recoveryIndemnity.trim(),
        'escompte': escompte.trim(),
        'insurance': insurance.trim(),
        'special_mentions': specialMentions.trim(),
      };

  @override
  bool operator ==(Object other) =>
      other is InvoiceLegal &&
      other.sellerKind == sellerKind &&
      other.customerCapacity == customerCapacity &&
      other.reverseChargeOptIn == reverseChargeOptIn &&
      other.vatTaxPoint == vatTaxPoint &&
      other.legalForm == legalForm &&
      other.registration == registration &&
      other.paymentTerms == paymentTerms &&
      other.latePenalty == latePenalty &&
      other.recoveryIndemnity == recoveryIndemnity &&
      other.escompte == escompte &&
      other.insurance == insurance &&
      other.specialMentions == specialMentions;

  @override
  int get hashCode => Object.hash(vatTaxPoint, reverseChargeOptIn, sellerKind, customerCapacity, legalForm, registration,
      paymentTerms, latePenalty, recoveryIndemnity, escompte, insurance,
      specialMentions);
}
