// SPDX-License-Identifier: 0BSD
//
// #1532 — the VAT regime and the mentions that go on the invoice with it
// are one statement, so they are one write.
//
// The legal identity screen made three server calls from one Save:
// `setLegalIdentity`, `setInvoicePdfTemplate`, `setInvoiceLegal`. When
// the last failed, the VAT regime and the VAT id had already changed
// while the statutory mentions and the exigibility had not — and every
// invoice issued afterwards carried a legal block that contradicted
// itself, under a message saying the save had failed.
//
// That is the worst shape a partial save can take: it is silent, it is
// legal, and it is discovered by a customer or an auditor rather than by
// the person who pressed the button.
//
// The identity and the mentions are now one row update. The document
// template cannot join them — it is a different aggregate behind its own
// RPC — so it is written FIRST, where failing alone is harmless: a
// window saved without the identity is a cosmetic choice the next Save
// repeats.
import 'package:deskilo/core/demo/data/workspace_repository.dart';
import 'package:deskilo/features/money/domain/invoice_legal.dart';
import 'package:deskilo/features/workspace/domain/workspace.dart';
import 'package:flutter_test/flutter_test.dart';

const _id = 'ws-1';

FakeWorkspaceRepository _repo() {
  final repo = FakeWorkspaceRepository();
  repo.workspaces.add(
    const Workspace(
      id: _id,
      name: 'Space',
      countryCode: 'FR',
      currencyCode: 'EUR',
      timezone: 'Europe/Paris',
      inviteCode: 'CODE',
      vatRegime: 'not_subject',
      invoiceLegal: {'payment_terms': 'thirty days'},
    ),
  );
  return repo;
}

Future<void> _save(
  FakeWorkspaceRepository repo, {
  required String vatRegime,
  required Map<String, Object?> invoiceLegal,
}) =>
    repo.setLegalIdentity(
      _id,
      vatRegime: vatRegime,
      vatId: 'FR123',
      legalId: '',
      taxExemptionReason: '',
      street: '1 rue',
      city: 'Pézenas',
      postalCode: '34120',
      vatAccount: '',
      invoiceLegal: invoiceLegal,
    );

void main() {
  test('the regime and the mentions land in the same write', () async {
    final repo = _repo();

    await _save(
      repo,
      vatRegime: 'subject',
      invoiceLegal: const InvoiceLegal(
        paymentTerms: 'on receipt',
        vatExigibility: 'debits',
      ).toJson(),
    );

    final w = repo.workspaces.single;
    expect(w.vatRegime, 'subject');
    expect(w.invoiceLegal['payment_terms'], 'on receipt',
        reason: 'one call carries both, so the invoice can never quote a '
            'regime the mentions beside it contradict');
    expect(w.invoiceLegal['vat_exigibility'], 'debits');
  });

  test('the mentions are replaced wholesale, not merged', () async {
    final repo = _repo();

    await _save(repo, vatRegime: 'subject', invoiceLegal: const {});

    expect(repo.workspaces.single.invoiceLegal, isEmpty,
        reason: '0094: the mentions are one coherent statement, not a '
            'delta — clearing a field must clear it');
  });

  test('the repository exposes no way to write one without the other',
      () async {
    // The guard that keeps this fixed. `setInvoiceLegal` existed as its
    // own method, and its only caller used it as the third of three
    // writes in one Save. Removing it is what makes the atomicity
    // structural rather than a habit the next edit can drop.
    expect(
      // ignore: avoid_dynamic_calls
      () => (_repo() as dynamic).setInvoiceLegal(_id, const <String, Object?>{}),
      throwsNoSuchMethodError,
      reason: 'a separate mentions-only write is exactly how the three-'
          'call Save was built; there must not be one to reach for',
    );
  });
}
