// SPDX-License-Identifier: 0BSD
import '../../workspace/domain/payment_instructions.dart';
import '../../workspace/domain/workspace.dart';
import '../domain/invoice.dart';

/// Glue between the workspace's editable legal identity and the frozen
/// party an e-invoice needs — the domain stays free of workspace types.
InvoiceParty workspaceParty(Workspace workspace) => InvoiceParty(
      name: workspace.name,
      // The structured street when the owner filled it in, else the
      // free-text block the letterhead prints.
      street: workspace.street.isNotEmpty
          ? workspace.street
          : workspace.address,
      city: workspace.city,
      postalCode: workspace.postalCode,
      country: workspace.countryCode,
      vatId: workspace.vatId,
      legalId: workspace.legalId,
      vatRegime: workspace.vatRegime,
      taxExemptionReason: workspace.taxExemptionReason,
    );

/// The seller of [invoice]: its own snapshot when it has one (0069).
///
/// Pre-0069 invoices carry no identity — rather than making them
/// permanently unexportable, they borrow the workspace's CURRENT identity:
/// same legal entity, and the alternative is a file no validator accepts.
/// Every invoice issued from now on answers for itself.
InvoiceParty sellerOf(Invoice invoice, Workspace workspace) =>
    invoice.sellerParty ?? workspaceParty(workspace);

/// The customer of [invoice]. Legacy documents fall back to the flat
/// snapshot, with the workspace's country standing in for the unknown one
/// (BT-55 cannot be empty).
InvoiceParty buyerOf(Invoice invoice, Workspace workspace) =>
    invoice.buyerParty ??
    InvoiceParty(
      name: invoice.memberName,
      street: invoice.memberAddress,
      country: workspace.countryCode,
    );

/// BT-84 for the XML: the workspace's own IBAN, so the customer's system
/// knows where to transfer. '' when none is configured.
String workspaceIban(Workspace workspace) =>
    PaymentInstructions.fromDb(workspace.paymentInstructions).iban.trim();
