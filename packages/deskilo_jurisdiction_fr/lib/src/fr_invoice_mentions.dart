// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- what French law adds to an invoice: the category of the
// operation (CGI ann. II art. 242 nonies A, since the 2026 e-invoicing reform).
// A workspace supplies services. Moved from the invoice model, text unchanged.
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of the lines this add-on states.
const frInvoiceMentionsImplementationVersion = '1';

/// The French invoice mentions.
class FrInvoiceMentions implements InvoiceMentionsContribution {
  const FrInvoiceMentions();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'fr.invoice_mentions',
    implementationVersion: frInvoiceMentionsImplementationVersion,
    contractVersion: invoiceMentionsContractVersion,
    formatVersion: 'cgi-242-nonies-a',
    capabilityId: 'invoice_mentions.FR',
  );

  @override
  List<String> mentions(InvoiceMentionContext context) => [
    if (context.sellerVatRegistered)
      "Cat\u00e9gorie de l'op\u00e9ration : prestation de services.",
  ];
}
