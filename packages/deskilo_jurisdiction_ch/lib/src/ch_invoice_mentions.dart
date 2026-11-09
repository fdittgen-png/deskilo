// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- Swiss invoice mentions: the law adds no line to an
// invoice beyond the Directive's list here, but declares the family of its
// payment-clause rules (the owner's own wording prints, nothing automatic).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart'
    show formatSwissUid, isValidSwissUid;

/// Bumped in the same commit as any change of what this add-on states.
const chInvoiceMentionsImplementationVersion = '1';

/// The Swiss invoice mentions.
class ChInvoiceMentions extends InvoiceMentionsContribution {
  const ChInvoiceMentions();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ch.invoice_mentions',
    implementationVersion: chInvoiceMentionsImplementationVersion,
    contractVersion: invoiceMentionsContractVersion,
    formatVersion: 'clauses-no-mention',
    capabilityId: 'invoice_mentions.CH',
  );

  @override
  String get profileFamily => 'ch';

  /// A valid Swiss UID prints the way art. 26 MWSTG shows it.
  @override
  String formatSellerVatId(String id) =>
      isValidSwissUid(id, requireSuffix: false) ? formatSwissUid(id) : id;

  @override
  List<String> mentions(InvoiceMentionContext context) => const [];
}
