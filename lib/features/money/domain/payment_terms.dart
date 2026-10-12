// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #881 — the payment conditions a document prints: the workspace's
// default (invoice_legal), a member's own keys on top. The member sees
// theirs and cannot change them; an authorised admin REQUESTS a change
// that goes through validation (payment_terms_change) — mirrored by
// `effective_payment_terms` / `payment_terms_clean` in SQL (0154).
import '../../../core/data/json_reader.dart';
import 'invoice_legal.dart';

class PaymentTerms {
  const PaymentTerms({
    this.paymentTerms = '',
    this.escompte = '',
    this.latePenalty = '',
    this.recoveryIndemnity = '',
  });

  static const PaymentTerms empty = PaymentTerms();

  final String paymentTerms;
  final String escompte;
  final String latePenalty;
  final String recoveryIndemnity;

  static const String keyPaymentTerms = 'payment_terms';
  static const String keyEscompte = 'escompte';
  static const String keyLatePenalty = 'late_penalty';
  static const String keyRecoveryIndemnity = 'recovery_indemnity';
  static const List<String> keys = [
    keyPaymentTerms, keyEscompte, keyLatePenalty, keyRecoveryIndemnity,
  ];

  factory PaymentTerms.fromJson(Map<dynamic, dynamic> json) {
    final r = JsonReader.of(json, context: 'payment_terms');
    return PaymentTerms(
      paymentTerms: r.stringOr(keyPaymentTerms),
      escompte: r.stringOr(keyEscompte),
      latePenalty: r.stringOr(keyLatePenalty),
      recoveryIndemnity: r.stringOr(keyRecoveryIndemnity),
    );
  }

  /// The workspace's conditions as [PaymentTerms].
  factory PaymentTerms.ofLegal(InvoiceLegal legal) => PaymentTerms(
        paymentTerms: legal.paymentTerms,
        escompte: legal.escompte,
        latePenalty: legal.latePenalty,
        recoveryIndemnity: legal.recoveryIndemnity,
      );

  /// Only the non-empty keys, trimmed — what `payment_terms_clean`
  /// stores; `{}` means "inherit everything".
  Map<String, String> toJson() => {
        if (paymentTerms.trim().isNotEmpty) keyPaymentTerms: paymentTerms.trim(),
        if (escompte.trim().isNotEmpty) keyEscompte: escompte.trim(),
        if (latePenalty.trim().isNotEmpty) keyLatePenalty: latePenalty.trim(),
        if (recoveryIndemnity.trim().isNotEmpty)
          keyRecoveryIndemnity: recoveryIndemnity.trim(),
      };

  bool get isEmpty => toJson().isEmpty;

  /// [override]'s non-empty keys on top of this — `effective_payment_terms`.
  PaymentTerms mergedWith(PaymentTerms? override) => override == null
      ? this
      : PaymentTerms(
          paymentTerms: override.paymentTerms.trim().isNotEmpty
              ? override.paymentTerms.trim()
              : paymentTerms,
          escompte: override.escompte.trim().isNotEmpty
              ? override.escompte.trim()
              : escompte,
          latePenalty: override.latePenalty.trim().isNotEmpty
              ? override.latePenalty.trim()
              : latePenalty,
          recoveryIndemnity: override.recoveryIndemnity.trim().isNotEmpty
              ? override.recoveryIndemnity.trim()
              : recoveryIndemnity,
        );

  PaymentTerms copyWith({
    String? paymentTerms,
    String? escompte,
    String? latePenalty,
    String? recoveryIndemnity,
  }) =>
      PaymentTerms(
        paymentTerms: paymentTerms ?? this.paymentTerms,
        escompte: escompte ?? this.escompte,
        latePenalty: latePenalty ?? this.latePenalty,
        recoveryIndemnity: recoveryIndemnity ?? this.recoveryIndemnity,
      );

  @override
  bool operator ==(Object other) =>
      other is PaymentTerms &&
      other.paymentTerms == paymentTerms &&
      other.escompte == escompte &&
      other.latePenalty == latePenalty &&
      other.recoveryIndemnity == recoveryIndemnity;

  @override
  int get hashCode =>
      Object.hash(paymentTerms, escompte, latePenalty, recoveryIndemnity);
}
