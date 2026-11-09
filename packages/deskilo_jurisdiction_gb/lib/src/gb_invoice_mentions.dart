// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- British invoice mentions: the law adds no line to an
// invoice beyond the Directive's list here, but declares the family of its
// payment-clause rules (the owner's own wording prints, nothing automatic).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this add-on states.
const gbInvoiceMentionsImplementationVersion = '1';

/// The British invoice mentions.
class GbInvoiceMentions extends InvoiceMentionsContribution {
  const GbInvoiceMentions();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'gb.invoice_mentions',
    implementationVersion: gbInvoiceMentionsImplementationVersion,
    contractVersion: invoiceMentionsContractVersion,
    formatVersion: 'clauses-no-mention',
    capabilityId: 'invoice_mentions.GB',
  );

  @override
  String get profileFamily => 'gb';

  @override
  List<String> mentions(InvoiceMentionContext context) => const [];
}
