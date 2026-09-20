// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 / #1234 — saving the legal identity is a decision about ORDER.
//
// One Save touches two aggregates that cannot be one transaction: the
// invoice PDF template, behind its own RPC, and the workspace's legal
// identity together with the statutory mentions, which are one row
// update (#1532).
//
// So one of the two can always fail alone, and which one is the rule:
//
//   the template goes FIRST, because a window saved without the
//   identity is a cosmetic choice the next Save repeats, while an
//   identity saved without its mentions is an invoice that contradicts
//   itself — the worst shape a partial save takes, because it is
//   silent, legal, and found by a customer or an auditor rather than by
//   the person who pressed the button.
//
// It lived in `_save` on the screen, where the only way to exercise it
// was to pump a widget. ADR 0024's shape, like `Payments` beside it:
// a class with its repositories handed in, behind a provider, so the
// screen asks for the decision instead of resolving the repositories
// and performing it.
import '../../workspace/domain/workspace_repository.dart';
import '../domain/address_window.dart';
import '../domain/invoice_pdf_template.dart';
import '../domain/money_repository.dart';

/// Everything one Save of the legal identity carries.
///
/// A record rather than fourteen parameters, like `book_seat.dart`'s
/// request: the screen holds a controller per field, and the command
/// should not grow an argument each time the form does.
typedef LegalIdentityRequest = ({
  String workspaceId,
  String vatRegime,
  String vatId,
  String legalId,
  String taxExemptionReason,
  String street,
  String city,
  String postalCode,
  String vatAccount,
  Map<String, Object?> invoiceLegal,

  /// The envelope window, which lives in the document template rather
  /// than on the workspace row.
  AddressWindow? addressWindow,
});

/// The legal identity of the workspace, as one decision.
class LegalIdentity {
  const LegalIdentity(this._money, this._workspace);

  final MoneyRepository _money;
  final WorkspaceRepository _workspace;

  /// Writes the template, then the identity and its mentions.
  ///
  /// [currentTemplate] is read-modify-written rather than replaced, so a
  /// design saved from the report editor is not clobbered by a screen
  /// that only means to move the address window (#869).
  ///
  /// Throws whatever the repositories throw: the caller reports it. What
  /// this owns is the ORDER, and the guarantee that comes with it — when
  /// the identity write fails, the only thing left behind is a window.
  Future<void> save(
    LegalIdentityRequest request, {
    required InvoicePdfTemplate currentTemplate,
  }) async {
    await _money.setInvoicePdfTemplate(
      request.workspaceId,
      currentTemplate.copyWith(addressWindow: request.addressWindow),
    );
    await _workspace.setLegalIdentity(
      request.workspaceId,
      vatRegime: request.vatRegime,
      vatId: request.vatId,
      legalId: request.legalId,
      taxExemptionReason: request.taxExemptionReason,
      street: request.street,
      city: request.city,
      postalCode: request.postalCode,
      vatAccount: request.vatAccount,
      invoiceLegal: request.invoiceLegal,
    );
  }
}
