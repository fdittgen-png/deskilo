// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- German invoice mentions: the law adds no line to an
// invoice beyond the Directive's list here, but declares the family of its
// payment-clause rules (the owner's own wording prints, nothing automatic).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this add-on states.
const deInvoiceMentionsImplementationVersion = '1';

/// The German invoice mentions.
class DeInvoiceMentions extends InvoiceMentionsContribution {
  const DeInvoiceMentions();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'de.invoice_mentions',
    implementationVersion: deInvoiceMentionsImplementationVersion,
    contractVersion: invoiceMentionsContractVersion,
    formatVersion: 'clauses-no-mention',
    capabilityId: 'invoice_mentions.DE',
  );

  @override
  String get profileFamily => 'de';

  @override
  List<String> mentions(InvoiceMentionContext context) => const [];
}
