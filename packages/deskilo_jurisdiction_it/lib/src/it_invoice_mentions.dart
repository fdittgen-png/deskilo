// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 (of #3328) -- what Italian law adds to an invoice: the EUR 2 stamp
// duty on a document whose amount not subject to VAT exceeds EUR 77.47
// (D.P.R. 642/1972, tariff art. 13). Moved from the invoice model with the
// statutory text unchanged (a parity golden pins it).
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// Bumped in the same commit as any change of the lines this add-on states.
const itInvoiceMentionsImplementationVersion = '1';

/// The stamp duty line.
const _stampDutyMention =
    'Imposta di bollo da \u20ac 2,00 assolta ai sensi del D.P.R. 642/1972.';

/// The Italian invoice mentions.
class ItInvoiceMentions implements InvoiceMentionsContribution {
  const ItInvoiceMentions();

  @override
  CapabilityDescriptor get descriptor => const CapabilityDescriptor(
    moduleId: 'it.invoice_mentions',
    implementationVersion: itInvoiceMentionsImplementationVersion,
    contractVersion: invoiceMentionsContractVersion,
    formatVersion: 'dpr-642-1972',
    capabilityId: 'invoice_mentions.IT',
  );

  @override
  List<String> mentions(InvoiceMentionContext context) => [
    // EUR only, and strictly above EUR 77.47 (7747 cents) not subject to VAT.
    if (context.currency.toUpperCase() == 'EUR' && context.untaxedMinor > 7747)
      _stampDutyMention,
  ];
}
