// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1449 — the order of the legal-identity Save, provable without a
// screen.
//
// Two aggregates, one button: the invoice PDF template behind its own
// RPC, and the identity plus its statutory mentions as one row update
// (#1532). They cannot be one transaction, so one of them can always be
// left behind — and which one is a rule with a reason:
//
//   a window saved without the identity is a cosmetic choice the next
//   Save repeats; an identity saved without its mentions is an invoice
//   that contradicts itself.
//
// That rule lived in `_save` on the screen, where the only way to reach
// it was to pump a widget — and `legal_identity_atomic_test.dart` next
// door tests the repository's half while saying nothing about the
// order. This is the other half.
import 'package:deskilo/core/demo/data/money_repository.dart';
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/money/application/save_legal_identity.dart';
import 'package:deskilo/features/money/domain/address_window.dart';
import 'package:deskilo/features/money/domain/invoice_pdf_template.dart';
import 'package:flutter_test/flutter_test.dart';

const _request = (
  workspaceId: 'ws-1',
  vatRegime: 'subject',
  vatId: 'FR123',
  legalId: '',
  taxExemptionReason: '',
  street: '1 rue',
  city: 'Pézenas',
  postalCode: '34120',
  vatAccount: '',
  invoiceLegal: <String, Object?>{'payment_terms': 'on receipt'},
  addressWindow: AddressWindow.left,
);

/// A workspace repository whose identity write refuses, so the order
/// becomes observable.
class _IdentityRefuses extends FakeWorkspaceRepository {
  _IdentityRefuses() : super.withWorkspace();

  @override
  Future<void> setLegalIdentity(
    String workspaceId, {
    required String vatRegime,
    required String vatId,
    required String legalId,
    required String taxExemptionReason,
    required String street,
    required String city,
    required String postalCode,
    required String vatAccount,
    required Map<String, Object?> invoiceLegal,
  }) =>
      throw StateError('the identity was refused');
}

void main() {
  test('the template is written first, so a refused identity leaves only '
      'a window', () async {
    final money = FakeMoneyRepository();
    final workspace = _IdentityRefuses();
    final command = LegalIdentity(money, workspace);

    await expectLater(
      command.save(_request, currentTemplate: InvoicePdfTemplate.empty),
      throwsA(isA<StateError>()),
    );

    expect(
      money.pdfTemplate.addressWindow,
      AddressWindow.left,
      reason: 'the cosmetic half landed and the legal half did not, '
          'which is the direction the rule chooses deliberately',
    );
    expect(workspace.workspaces.single.vatRegime, isNot('subject'),
        reason: 'nothing of the identity was written');
  });

  test('the happy path writes both', () async {
    final money = FakeMoneyRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace();

    await LegalIdentity(money, workspace)
        .save(_request, currentTemplate: InvoicePdfTemplate.empty);

    expect(money.pdfTemplate.addressWindow,
        AddressWindow.left);
    final w = workspace.workspaces.single;
    expect(w.vatRegime, 'subject');
    expect(w.invoiceLegal['payment_terms'], 'on receipt',
        reason: 'identity and mentions in the same row update (#1532)');
  });

  test('the template is read-modify-written, not replaced', () async {
    final money = FakeMoneyRepository();
    final workspace = FakeWorkspaceRepository.withWorkspace();

    // #869 — a design saved from the report editor must survive a screen
    // that only means to move the envelope window.
    const existing = InvoicePdfTemplate(header: 'Association Pézenas');

    await LegalIdentity(money, workspace)
        .save(_request, currentTemplate: existing);

    final written = money.pdfTemplate;
    expect(written.addressWindow, AddressWindow.left);
    expect(written.header, 'Association Pézenas',
        reason: 'the rest of the design is carried through, or this '
            'screen silently discards the editor\'s work');
  });
}
