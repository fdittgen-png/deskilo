// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1916 — which payment clauses an invoice prints is decided by the law
// of the transaction and the customer's capacity, from facts frozen at
// issue; never by the reader's language or the seller's legal form.
//
// The facts are [LegalClauseSnapshot] (`invoices.legal_snapshot`, 0347):
// the owner's own clause texts plus the seller country and the buyer's
// capacity. [qualifyClauses] applies a small, bounded rule set:
//
//   * FR, business customer — the clauses art. L441-9 / L441-10 code de
//     commerce require on an invoice between professionals (late
//     penalties, the €40 fixed recovery indemnity of art. D441-5, the
//     discount conditions). The owner's text wins; without one the
//     workspace's existing default wording prints.
//   * DE, business customer — § 288 Abs. 2 and 5 BGB apply by law; § 14
//     Abs. 4 UStG does not make them an invoice mention, so nothing is
//     printed automatically. The owner's text prints.
//   * Consumer customer (FR or DE) — no automatic clause. The €40
//     indemnity is a claim against a business debtor only (art. L441-10
//     II code de commerce, § 288 Abs. 5 BGB), so it is never printed to
//     a consumer, even when typed. An owner's late penalty prints but
//     needs review: it may not override consumer protection.
//   * Capacity not stated — no automatic clause; the owner's texts print
//     and are flagged for review.
//   * Any other seller country — no reviewed profile: nothing automatic,
//     the owner's texts print flagged, and the EU recovery indemnity is
//     not printed outside the EU.
//
// Every profile is `requiresReview`: these rules are the documented
// statutory references, not an authoritative legal review. A profile
// becomes reviewed only when someone with that authority says so.
import 'invoice_legal.dart';
import 'payment_terms.dart';
import 'report_strings.dart';
import 'vat_compliance.dart';

/// Whether the customer acts as a business or as a consumer. Stated by
/// the seller (`members.customer_capacity`, the workspace default in
/// `invoice_legal`); never inferred from a VAT id or a company name. A
/// sole trader acting for their trade is [business].
enum CustomerCapacity {
  business('business'),
  consumer('consumer'),
  unknown('unknown');

  const CustomerCapacity(this.wire);
  final String wire;

  static CustomerCapacity fromWire(String? wire) => switch (wire) {
    'business' => business,
    'consumer' => consumer,
    _ => unknown,
  };
}

/// The rule set the clauses were qualified under.
enum LegalProfile {
  frBusiness,
  frConsumer,
  deBusiness,
  deConsumer,

  /// The seller's country has no profile here; nothing is automatic.
  unsupported,

  /// FR or DE with the capacity not stated.
  capacityUnknown,
}

/// Why a clause prints (or not).
enum ClauseBasis {
  /// The owner's own text, applicable under the profile.
  owner,

  /// The workspace's default wording of a clause the profile requires.
  statutoryDefault,

  /// Printed, but the profile cannot confirm it applies (capacity not
  /// stated, consumer late penalty, unsupported profile).
  requiresReview,

  /// Not printed: the clause does not apply to this transaction.
  notApplicable,

  /// Not printed: nothing written, nothing required.
  none,
}

/// One qualified clause: what prints ('' = nothing) and why.
class QualifiedClause {
  const QualifiedClause(this.text, this.basis);
  final String text;
  final ClauseBasis basis;

  @override
  bool operator ==(Object other) =>
      other is QualifiedClause && other.text == text && other.basis == basis;

  @override
  int get hashCode => Object.hash(text, basis);

  @override
  String toString() => 'QualifiedClause($basis, "$text")';
}

/// The four payment clauses of one document, qualified.
class QualifiedClauses {
  const QualifiedClauses({
    required this.profile,
    required this.paymentTerms,
    required this.latePenalty,
    required this.recoveryIndemnity,
    required this.escompte,
  });

  final LegalProfile profile;
  final QualifiedClause paymentTerms;
  final QualifiedClause latePenalty;
  final QualifiedClause recoveryIndemnity;
  final QualifiedClause escompte;

  /// No profile here has had an authoritative legal review.
  bool get requiresReview => true;

  /// The clauses a person should look at before relying on the document.
  List<String> get deficiencies => [
    if (profile == LegalProfile.capacityUnknown) 'capacity_unknown',
    if (profile == LegalProfile.unsupported) 'profile_unsupported',
    for (final (key, clause) in [
      ('payment_terms', paymentTerms),
      ('late_penalty', latePenalty),
      ('recovery_indemnity', recoveryIndemnity),
      ('escompte', escompte),
    ])
      if (clause.basis == ClauseBasis.requiresReview)
        '${key}_review'
      else if (clause.basis == ClauseBasis.notApplicable)
        '${key}_not_applicable',
  ];
}

/// The legal facts of one invoice as frozen at issue (0347, schema 1).
class LegalClauseSnapshot {
  const LegalClauseSnapshot({
    this.schema = 1,
    this.sellerKind = '',
    this.sellerCountry = '',
    this.buyerCountry = '',
    this.buyerCapacity = CustomerCapacity.unknown,
    this.capacitySource = 'none',
    this.termsSource = 'workspace',
    this.clauses = PaymentTerms.empty,
    this.legalForm = '',
    this.registration = '',
    this.insurance = '',
    this.specialMentions = '',
    this.vatExigibility = 'invoice',
    this.fingerprint = '',
  });

  final int schema;
  final String sellerKind;
  final String sellerCountry;
  final String buyerCountry;
  final CustomerCapacity buyerCapacity;

  /// `member`, `workspace` or `none`.
  final String capacitySource;

  /// `member` or `workspace` — whose payment conditions were in force.
  final String termsSource;

  /// The OWNER'S texts in force at issue; '' where none was written.
  final PaymentTerms clauses;
  final String legalForm;
  final String registration;
  final String insurance;
  final String specialMentions;
  final String vatExigibility;
  final String fingerprint;

  bool get onPaymentBasis => vatExigibility == 'payment';

  factory LegalClauseSnapshot.fromJson(Map<dynamic, dynamic> json) =>
      LegalClauseSnapshot(
        schema: (json['schema'] as num?)?.toInt() ?? 1,
        sellerKind: json['seller_kind'] as String? ?? '',
        sellerCountry: json['seller_country'] as String? ?? '',
        buyerCountry: json['buyer_country'] as String? ?? '',
        buyerCapacity: CustomerCapacity.fromWire(
          json['buyer_capacity'] as String?,
        ),
        capacitySource: json['capacity_source'] as String? ?? 'none',
        termsSource: json['terms_source'] as String? ?? 'workspace',
        clauses: PaymentTerms.fromJson(
          json['clauses'] as Map? ?? const <String, Object?>{},
        ),
        legalForm: json['legal_form'] as String? ?? '',
        registration: json['registration'] as String? ?? '',
        insurance: json['insurance'] as String? ?? '',
        specialMentions: json['special_mentions'] as String? ?? '',
        vatExigibility: json['vat_exigibility'] as String? ?? 'invoice',
        fingerprint: json['fingerprint'] as String? ?? '',
      );

  /// The same facts read from the LIVE settings — for documents that are
  /// not an issued invoice (statements, letters, previews). The member's
  /// own capacity wins over the workspace default, as in the SQL twin.
  factory LegalClauseSnapshot.live({
    required InvoiceLegal legal,
    required String sellerCountry,
    String buyerCountry = '',
    PaymentTerms? memberTerms,
    String? memberCapacity,
  }) {
    final member = CustomerCapacity.fromWire(memberCapacity);
    final fallback = CustomerCapacity.fromWire(legal.customerCapacity);
    final capacity = member != CustomerCapacity.unknown ? member : fallback;
    return LegalClauseSnapshot(
      sellerKind: legal.sellerKind,
      sellerCountry: sellerCountry.trim().toUpperCase(),
      buyerCountry: buyerCountry.trim().toUpperCase(),
      buyerCapacity: capacity,
      capacitySource: member != CustomerCapacity.unknown
          ? 'member'
          : capacity == CustomerCapacity.unknown
          ? 'none'
          : 'workspace',
      termsSource: memberTerms == null ? 'workspace' : 'member',
      clauses: PaymentTerms.ofLegal(legal).mergedWith(memberTerms),
      legalForm: legal.legalForm,
      registration: legal.registration,
      insurance: legal.insurance,
      specialMentions: legal.specialMentions,
      vatExigibility: legal.vatExigibility,
    );
  }
}

/// The profile [snapshot] falls under: the seller's country (where the
/// supply is made from — the transaction law this bounded set knows) and
/// the buyer's stated capacity.
LegalProfile legalProfileOf(LegalClauseSnapshot snapshot) {
  final country = snapshot.sellerCountry.trim().toUpperCase();
  if (country != 'FR' && country != 'DE') return LegalProfile.unsupported;
  return switch ((country, snapshot.buyerCapacity)) {
    ('FR', CustomerCapacity.business) => LegalProfile.frBusiness,
    ('FR', CustomerCapacity.consumer) => LegalProfile.frConsumer,
    ('DE', CustomerCapacity.business) => LegalProfile.deBusiness,
    ('DE', CustomerCapacity.consumer) => LegalProfile.deConsumer,
    _ => LegalProfile.capacityUnknown,
  };
}

/// The four payment clauses [snapshot] prints. [strings] only supplies
/// the wording of a default in the reader's language — it never decides
/// whether a clause applies.
QualifiedClauses qualifyClauses(
  LegalClauseSnapshot snapshot,
  ReportStrings strings,
) {
  final profile = legalProfileOf(snapshot);
  final own = snapshot.clauses;
  QualifiedClause owned(String text, {required String orDefault}) {
    if (text.trim().isNotEmpty) {
      return QualifiedClause(text.trim(), ClauseBasis.owner);
    }
    return orDefault.isEmpty
        ? const QualifiedClause('', ClauseBasis.none)
        : QualifiedClause(orDefault, ClauseBasis.statutoryDefault);
  }

  QualifiedClause review(String text) => text.trim().isEmpty
      ? const QualifiedClause('', ClauseBasis.none)
      : QualifiedClause(text.trim(), ClauseBasis.requiresReview);

  const notApplicable = QualifiedClause('', ClauseBasis.notApplicable);
  final businessOnlyIndemnity = own.recoveryIndemnity.trim().isEmpty
      ? const QualifiedClause('', ClauseBasis.none)
      : notApplicable;

  // The payment terms are a contractual statement, the same in every
  // profile: the owner's text or the workspace's default wording.
  final terms = owned(own.paymentTerms, orDefault: strings.paymentTermsDefault);

  return switch (profile) {
    LegalProfile.frBusiness => QualifiedClauses(
      profile: profile,
      paymentTerms: terms,
      latePenalty: owned(
        own.latePenalty,
        orDefault: strings.latePenaltyDefault,
      ),
      recoveryIndemnity: owned(
        own.recoveryIndemnity,
        orDefault: strings.recoveryDefault,
      ),
      escompte: owned(own.escompte, orDefault: strings.escompteDefault),
    ),
    LegalProfile.deBusiness => QualifiedClauses(
      profile: profile,
      paymentTerms: terms,
      latePenalty: owned(own.latePenalty, orDefault: ''),
      recoveryIndemnity: owned(own.recoveryIndemnity, orDefault: ''),
      escompte: owned(own.escompte, orDefault: ''),
    ),
    LegalProfile.frConsumer || LegalProfile.deConsumer => QualifiedClauses(
      profile: profile,
      paymentTerms: terms,
      latePenalty: review(own.latePenalty),
      recoveryIndemnity: businessOnlyIndemnity,
      escompte: owned(own.escompte, orDefault: ''),
    ),
    LegalProfile.capacityUnknown => QualifiedClauses(
      profile: profile,
      paymentTerms: terms,
      latePenalty: review(own.latePenalty),
      recoveryIndemnity: review(own.recoveryIndemnity),
      escompte: review(own.escompte),
    ),
    LegalProfile.unsupported => QualifiedClauses(
      profile: profile,
      paymentTerms: terms,
      latePenalty: review(own.latePenalty),
      recoveryIndemnity: isEuCountry(snapshot.sellerCountry)
          ? review(own.recoveryIndemnity)
          : businessOnlyIndemnity,
      escompte: review(own.escompte),
    ),
  };
}

/// #1916 — the clauses a LEGACY document (issued before 0347, no
/// snapshot) prints: exactly the pre-0344 rule — the workspace defaults
/// unless the seller is an association. Kept so an old invoice renders
/// as it always did; its evidence is unknown and nothing is reissued.
QualifiedClauses legacyClauses(
  InvoiceLegal legal,
  PaymentTerms terms,
  ReportStrings strings,
) {
  QualifiedClause pick(String value, String fallback, {bool b2b = true}) {
    if (value.trim().isNotEmpty) {
      return QualifiedClause(value.trim(), ClauseBasis.owner);
    }
    if (b2b && legal.isAssociation) {
      return const QualifiedClause('', ClauseBasis.none);
    }
    return QualifiedClause(fallback, ClauseBasis.statutoryDefault);
  }

  return QualifiedClauses(
    profile: LegalProfile.unsupported,
    paymentTerms: pick(
      terms.paymentTerms,
      strings.paymentTermsDefault,
      b2b: false,
    ),
    latePenalty: pick(terms.latePenalty, strings.latePenaltyDefault),
    recoveryIndemnity: pick(terms.recoveryIndemnity, strings.recoveryDefault),
    escompte: pick(terms.escompte, strings.escompteDefault),
  );
}
