// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- what Canadian law adds to an invoice: the registrant's
// numbers (ETA s. 169(4); the Act respecting the QST, s. 425), in both
// languages -- the customer's decides which is read, the law asks for the
// number. Moved from the invoice model, text unchanged.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';
import 'package:deskilo_jurisdiction_standards/deskilo_jurisdiction_standards.dart'
    show formatCanadianRegistration;

/// Bumped in the same commit as any change of the lines this add-on states.
const caInvoiceMentionsImplementationVersion = '1';

/// The Canadian invoice mentions.
class CaInvoiceMentions extends InvoiceMentionsContribution {
  const CaInvoiceMentions();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'ca.invoice_mentions',
    implementationVersion: caInvoiceMentionsImplementationVersion,
    contractVersion: invoiceMentionsContractVersion,
    formatVersion: 'eta-169-4',
    capabilityId: 'invoice_mentions.CA',
  );

  @override
  String get profileFamily => 'ca';

  @override
  List<String> mentions(InvoiceMentionContext context) => [
    // The two numbers are independent: the QST one needs its own number and
    // the tax charged, never the GST/HST one.
    if (context.sellerVatRegistered && context.sellerVatId.trim().isNotEmpty)
      'GST/HST No. \u00b7 N\u00b0 de TPS/TVH : '
          '${formatCanadianRegistration(context.sellerVatId)}',
    if (context.sellerVatRegistered &&
        context.qstCharged &&
        context.sellerLegalId.trim().isNotEmpty)
      'QST No. \u00b7 N\u00b0 de TVQ : '
          '${formatCanadianRegistration(context.sellerLegalId)}',
  ];
}
