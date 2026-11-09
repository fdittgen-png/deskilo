// SPDX-License-Identifier: AGPL-3.0-or-later
import 'capability_descriptor.dart';

/// What a country's own law needs to know about an invoice to say what it adds
/// to it. Neutral: no invoice model, no tax reference, no clock.
class InvoiceMentionContext {
  const InvoiceMentionContext({
    required this.sellerVatRegistered,
    required this.currency,
    required this.untaxedMinor,
    required this.correction,
    this.rectifies = '',
    this.correctionReason = '',
    this.sellerVatId = '',
    this.sellerLegalId = '',
    this.qstCharged = false,
  });

  /// Whether the seller charges VAT under the ordinary regime.
  final bool sellerVatRegistered;

  /// The document currency (ISO 4217, any case).
  final String currency;

  /// The gross of the supplies that carry no VAT other than a reverse charge,
  /// in minor units of [currency].
  final int untaxedMinor;

  /// A credit note or a replacement.
  final bool correction;

  /// The number of the document a correction rectifies; '' when none.
  final String rectifies;

  /// The correction reason code the document froze; '' when none.
  final String correctionReason;
  final String sellerVatId;
  final String sellerLegalId;

  /// Whether the Quebec sales tax is charged on the document.
  final bool qstCharged;
}

/// One country's mentions: the lines its own law adds to an invoice beyond the
/// Directive's list, in the seller's language, exactly as printed. Pure: the
/// same context gives the same lines; it reads no clock, network or
/// repository. The country is the one in the capability id
/// (`invoice_mentions.IT`).
abstract class InvoiceMentionsContribution {
  const InvoiceMentionsContribution();

  CapabilityDescriptor get descriptor;

  /// The lines for [context], in print order; empty when the law adds none.
  List<String> mentions(InvoiceMentionContext context);

  /// The correction reason codes the country's law asks a correcting invoice
  /// to carry, in the order they are offered (Spain: R1-R5); empty when it
  /// asks none. Additive: the contract stays at version 1.
  List<String> get correctionReasonCodes => const [];

  /// The family of the payment-clause rules the country's law gives an
  /// invoice (`fr`, `de`, `gb`, `ch`, `ca`, `us`: the name the host's legal
  /// profile carries, followed by `Business` or `Consumer`); empty when the
  /// country has no family of its own and the host's fallback applies.
  /// Additive: the contract stays at version 1.
  String get profileFamily => '';

  /// The payment clauses a BUSINESS customer's invoice prints in the host's
  /// default wording when the owner wrote none, by clause id
  /// (`latePenalty`, `recoveryIndemnity`, `escompte`); empty when the law
  /// makes none automatic. The wording stays the host's, in the reader's
  /// language. Additive: the contract stays at version 1.
  Set<String> get automaticClauses => const {};
}
