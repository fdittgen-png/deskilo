// SPDX-License-Identifier: 0BSD

/// The workspace's LEGAL INVOICE MENTIONS (#480) — the free-text lines a
/// compliant professional invoice must (or may) print beyond the 0069
/// identity. Stored as `workspaces.invoice_legal` jsonb; every field is
/// optional, and the four the law requires on every French invoice
/// ([paymentTerms], [latePenalty], [recoveryIndemnity], [escompte])
/// fall back to localized statutory defaults at render time — an owner
/// who configures nothing still issues a valid document.
class InvoiceLegal {
  const InvoiceLegal({
    this.legalForm = '',
    this.registration = '',
    this.paymentTerms = '',
    this.latePenalty = '',
    this.recoveryIndemnity = '',
    this.escompte = '',
    this.insurance = '',
    this.specialMentions = '',
  });

  /// 'SARL au capital de 7 500 €' — legal form and share capital.
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
      other.legalForm == legalForm &&
      other.registration == registration &&
      other.paymentTerms == paymentTerms &&
      other.latePenalty == latePenalty &&
      other.recoveryIndemnity == recoveryIndemnity &&
      other.escompte == escompte &&
      other.insurance == insurance &&
      other.specialMentions == specialMentions;

  @override
  int get hashCode => Object.hash(legalForm, registration, paymentTerms,
      latePenalty, recoveryIndemnity, escompte, insurance, specialMentions);
}
