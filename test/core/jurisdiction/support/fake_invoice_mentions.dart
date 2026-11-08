// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3429 -- a mentions add-on that exists only in a test: the host-path proof of
// the invoice mentions contract. Installed in a TEST composition, never in the
// application.
import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// States `FAKE <number of cents>` for [country], and a second line for a
/// correction.
class FakeInvoiceMentions implements InvoiceMentionsContribution {
  const FakeInvoiceMentions(
    this.country, {
    this.contractVersion = invoiceMentionsContractVersion,
  });

  final String country;
  final String contractVersion;

  @override
  CapabilityDescriptor get descriptor => CapabilityDescriptor(
    moduleId: 'fake.$country.invoice_mentions',
    implementationVersion: '1',
    contractVersion: contractVersion,
    formatVersion: 'fake-text',
    capabilityId: invoiceMentionsCapabilityId(country),
  );

  @override
  List<String> mentions(InvoiceMentionContext context) => [
    'FAKE ${context.untaxedMinor}',
    if (context.correction) 'FAKE correction of ${context.rectifies}',
  ];
}
