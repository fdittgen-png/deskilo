// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3337 -- an invoice profile that exists only in a test: the host-path proof
// of the invoice profile contract. It writes one text line from the neutral
// context and is installed in a TEST composition, never in the application.
import 'dart:convert';

import 'package:deskilo/core/jurisdiction/jurisdiction_resolver.dart';
import 'package:deskilo_jurisdiction_api/deskilo_jurisdiction_api.dart';

/// A profile for [formatId] that writes FAKE, the number, the payable amount
/// and each VAT total; refuses a document without a buyer country as
/// `buyerCountry`.
class FakeInvoiceProfile implements InvoiceProfileContribution {
  const FakeInvoiceProfile(
    this.formatId, {
    this.contractVersion = invoiceProfileContractVersion,
  });

  final String formatId;
  final String contractVersion;

  @override
  CapabilityDescriptor get descriptor => CapabilityDescriptor(
    moduleId: 'fake.$formatId.invoice_profile',
    implementationVersion: '1',
    contractVersion: contractVersion,
    formatVersion: 'fake-text',
    capabilityId: invoiceProfileCapabilityId(formatId),
  );

  @override
  ({ValidatedInvoiceDocument? document, ValidationResult result}) validate(
    InvoiceDocumentContext context,
  ) {
    if (context.buyer.country.trim().isEmpty) {
      return (
        document: null,
        result: ValidationResult.refused(const [
          ValidationIssue('buyerCountry', field: 'buyer.country'),
        ]),
      );
    }
    return (
      document: ValidatedInvoiceDocument(context),
      result: const ValidationResult.ok(),
    );
  }

  @override
  GeneratedArtifact build(ValidatedInvoiceDocument document) {
    final context = document.context;
    if (!validate(context).result.isOk) {
      throw StateError('a document this profile would refuse');
    }
    final totals = [
      for (final t in context.vatBreakdown)
        '${t.percent}:${t.category}:${t.netMinor}:${t.vatMinor}',
    ].join(',');
    final text =
        'FAKE|$formatId|${context.number}|${context.currency}'
        '|${context.payableMinor}|$totals';
    return GeneratedArtifact(
      bytes: utf8.encode(text),
      mediaType: 'text/plain',
      fileName: '${context.number}.txt',
      provenance: descriptor.toProvenance(),
    );
  }
}
