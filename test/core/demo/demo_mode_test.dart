// SPDX-License-Identifier: 0BSD
//
// #970 — demo mode: invented, consistent, empty-preserving substitutes
// for everything that identifies a person.
import 'package:deskilo/core/demo/demo_mode.dart';
import 'package:deskilo/features/money/domain/invoice.dart';
import 'package:deskilo/features/profile/domain/personal_info.dart';
import 'package:deskilo/features/profile/domain/profile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_pref_stores.dart';


void main() {
  test('a name becomes a different, natural one — the same every time, '
      'and empty stays empty', () {
    final a = demoName('Guilhem Martin');
    expect(a, isNot('Guilhem Martin'));
    expect(a, matches(RegExp(r'^[A-Z][a-z]+ [A-Z][a-z]+$')));
    expect(demoName('Guilhem Martin'), a, reason: 'deterministic');
    expect(demoName('guilhem martin '), a, reason: 'case and spaces do not matter');
    expect(demoName('Ana Lima'), isNot(a), reason: 'two people, two names');
    expect(demoName(''), '');
    expect(demoName('  '), '');
  });

  test('the e-mail follows the invented name; the address is invented; '
      'registrations keep their shape', () {
    expect(demoEmailOf('Camille Dubois'), 'camille.dubois@example.org');
    expect(demoEmailOf(''), '');
    final block = demoAddressBlock('anyone');
    expect(block.split('\n'), hasLength(2));
    expect(block, matches(RegExp(r'^\d+ .+\n\d{5} [A-ZÉ]+$')));
    expect(demoCompany('SASU KaloA'), startsWith('Société '));
    expect(demoCompany(''), '');
  });

  test('a personal info is scrubbed field by field, empties preserved', () {
    const real = PersonalInfo(
      firstName: 'Guilhem',
      lastName: 'Martin',
      company: 'SASU KaloA',
      street: '209 rue Jean Bart',
      postalCode: '31670',
      city: 'Labège',
      email: 'g@kaloa.fr',
      legalId: '123456789',
    );
    final fake = scrubPersonalInfo(real);
    expect(fake.firstName, isNot('Guilhem'));
    expect(fake.lastName, isNot('Martin'));
    expect(fake.company, isNot(contains('KaloA')));
    expect(fake.street, isNot(contains('Jean Bart')));
    expect(fake.city, isNot('Labège'));
    expect(fake.email, endsWith('@example.org'));
    expect(fake.legalId, '000000000');
    expect(fake.phone, '', reason: 'nothing invented where nothing was');
    expect(fake.vatId, '');
    expect(scrubPersonalInfo(PersonalInfo.empty), PersonalInfo.empty);
  });

  test('a profile and an invoice are scrubbed where they identify someone',
      () {
    const profile = Profile(
      id: 'u1',
      displayName: 'Flo',
      whatsapp: '+33600000000',
      address: '4 rue Silène',
    );
    final fake = scrubProfile(profile);
    expect(fake.displayName, isNot('Flo'));
    expect(fake.whatsapp, demoPhone());
    expect(fake.address, isNot(contains('Silène')));
    expect(fake.id, 'u1', reason: 'ids are not personal data');

    final invoice = Invoice(
      id: 'i1',
      workspaceId: 'ws',
      memberId: 'm1',
      number: 'INV-2026-0001',
      issuedAt: DateTime(2026, 9, 6),
      period: '2026-09',
      title: 'INV-2026-0001',
      lines: const [],
      totalCents: 0,
      currency: 'EUR',
      memberName: 'Guilhem Martin',
      memberAddress: '209 rue Jean Bart\n31670 LABÈGE',
      workspaceName: 'COWORKONTI',
      workspaceAddress: '4 avenue de Castelnau',
      issuerName: 'Flo',
      signature: '',
      buyerParty: const InvoiceParty(
          name: 'SASU KaloA', company: 'SASU KaloA', person: 'Guilhem MARTIN',
          street: '209 rue Jean Bart', legalId: '123456789'),
    );
    final out = scrubInvoice(invoice);
    expect(out.memberName, demoName('Guilhem Martin'));
    expect(out.memberAddress, isNot(contains('Jean Bart')));
    expect(out.issuerName, demoName('Flo'));
    expect(out.number, 'INV-2026-0001', reason: 'the document keeps its number');
    expect(out.workspaceName, 'COWORKONTI');
    expect(out.buyerParty!.name, isNot(contains('KaloA')));
    expect(out.buyerParty!.person, isNot(contains('MARTIN')));
    expect(out.buyerParty!.legalId, '000000000');
  });

  test('the controller reads "on" and persists a change', () async {
    final store = InMemoryDemoModeStore(value: 'on');
    final container = ProviderContainer(
        overrides: [demoModeStoreProvider.overrideWithValue(store)]);
    addTearDown(container.dispose);
    expect(await container.read(demoModeControllerProvider.future), isTrue);
    await container.read(demoModeControllerProvider.notifier).set(false);
    expect(store.value, isNull);
  });
}
