// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- American invoice mentions: the law adds no line to an
// invoice beyond the Directive's list here, but declares the family of its
// payment-clause rules (the owner's own wording prints, nothing automatic).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of what this add-on states.
const usInvoiceMentionsImplementationVersion = '1';

/// The American invoice mentions.
class UsInvoiceMentions extends InvoiceMentionsContribution {
  const UsInvoiceMentions();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'us.invoice_mentions',
    implementationVersion: usInvoiceMentionsImplementationVersion,
    contractVersion: invoiceMentionsContractVersion,
    formatVersion: 'clauses-no-mention',
    capabilityId: 'invoice_mentions.US',
  );

  @override
  String get profileFamily => 'us';

  @override
  List<String> mentions(InvoiceMentionContext context) => const [];
}
