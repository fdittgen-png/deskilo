// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1532 — a member's address and tax identity are one write.
//
// The address sheet called `updateAddress` and then `updateTaxIdentity`
// from one Save. Both feed the same block on the invoice — the customer
// the document is addressed to — so a failure on the second billed the
// member at their new address under their old VAT identity, and the
// sheet said only that something had gone wrong.
//
// The repository already stated the principle one method away:
// `updatePersonalInfo` is documented as "the whole structured identity
// in one write (the form saves every field together, so a half-saved
// address cannot exist)" (#886). This applies it to the fields that
// sheet actually saves.
import 'package:deskilo/core/demo/data/profile_repository.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter_test/flutter_test.dart';

FakeProfileRepository _repo() => FakeProfileRepository(
      profiles: [
        const Profile(
          id: 'user-1',
          displayName: 'Dov',
          address: '1 rue ancienne',
          countryCode: 'FR',
          vatId: 'FR000',
        ),
      ],
    );

void main() {
  test('the address and the tax identity land in the same write', () async {
    final repo = _repo();

    await repo.updateInvoiceIdentity(
      address: '2 rue nouvelle',
      countryCode: 'be',
      vatId: 'BE999',
    );

    final me = repo.profiles.single;
    expect(me.address, '2 rue nouvelle');
    expect(me.countryCode, 'BE', reason: 'the country is upper-cased, as '
        'the 0069 column check requires');
    expect(me.vatId, 'BE999',
        reason: 'one call carries all three, so an invoice can never be '
            'addressed to the new address under the old VAT identity');
  });

  test('a failure leaves every field as it was', () async {
    final repo = _repo()..failing = true;

    await expectLater(
      repo.updateInvoiceIdentity(
        address: '2 rue nouvelle',
        countryCode: 'BE',
        vatId: 'BE999',
      ),
      throwsA(isA<StateError>()),
    );

    final me = repo.profiles.single;
    expect('${me.address}|${me.countryCode}|${me.vatId}',
        '1 rue ancienne|FR|FR000',
        reason: 'nothing may be half-written: the whole point is that the '
            'invoice block moves together or not at all');
  });

  test('the repository exposes no way to write one without the other',
      () async {
    // The guard that keeps this fixed. Two separate methods existed and
    // their only caller used them as two writes in one Save; removing
    // them is what makes the atomicity structural rather than a habit
    // the next edit can drop.
    for (final gone in ['updateAddress', 'updateTaxIdentity']) {
      expect(
        () => switch (gone) {
          // ignore: avoid_dynamic_calls
          'updateAddress' => (_repo() as dynamic).updateAddress('x'),
          // ignore: avoid_dynamic_calls
          _ => (_repo() as dynamic)
              .updateTaxIdentity(countryCode: 'FR', vatId: ''),
        },
        throwsNoSuchMethodError,
        reason: '$gone is exactly how the two-call Save was built; there '
            'must not be one to reach for',
      );
    }
  });
}
