// SPDX-License-Identifier: AGPL-3.0-or-later
import 'capability_descriptor.dart';
import 'generated_artifact.dart';
import 'invoice_document_context.dart';
import 'validation_result.dart';

/// A context an invoice profile validated. Public so an implementation can
/// make one, but it proves nothing by itself: `build` validates again.
class ValidatedInvoiceDocument {
  ValidatedInvoiceDocument(this.context);

  final InvoiceDocumentContext context;
}

/// One national invoice document profile (FatturaPA, KSeF FA(3), CIUS-RO…).
/// Pure: the same context gives the same bytes; it reads no clock, network or
/// repository.
abstract class InvoiceProfileContribution {
  CapabilityDescriptor get descriptor;

  /// Whether [context] can be rendered in this profile, as stable codes.
  ({ValidatedInvoiceDocument? document, ValidationResult result}) validate(
    InvoiceDocumentContext context,
  );

  /// The document of a validated [document]. An implementation validates it
  /// again and throws a [StateError] when its own [validate] would refuse it.
  GeneratedArtifact build(ValidatedInvoiceDocument document);
}
