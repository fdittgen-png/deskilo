// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- the reference organisation's billing customers: a business with a
// VAT number, a person who buys for themselves, and a business abroad, so the
// customer list reads like a freelancer's. They are synthetic and belong to the
// Demo's seller space alone.
import '../../../features/money/domain/billing_customer.dart';
import '../data/fake_billing_customers.dart';

const _customers = <BillingParty>[
  BillingParty(
    subjectId: 'demo-customer-lumi',
    revision: 2,
    capacity: 'business',
    draft: BillingPartyDraft(
      company: 'Atelier Lumi',
      street: '1 rue du Port',
      postalCode: '34120',
      city: 'Pezenas',
      countryCode: 'FR',
      vatId: 'FR12345678901',
      email: 'compta@lumi.example',
    ),
  ),
  BillingParty(
    subjectId: 'demo-customer-weiss',
    revision: 1,
    capacity: 'consumer',
    draft: BillingPartyDraft(
      courtesy: 'Dr.',
      firstName: 'Hanna',
      lastName: 'Weiss',
      street: '12 Lindenstrasse',
      postalCode: '04109',
      city: 'Leipzig',
      countryCode: 'DE',
      email: 'hanna.weiss@example.test',
    ),
  ),
  BillingParty(
    subjectId: 'demo-customer-nordlicht',
    revision: 1,
    capacity: 'business',
    draft: BillingPartyDraft(
      company: 'Nordlicht GmbH',
      street: '4 Hafenstrasse',
      postalCode: '20457',
      city: 'Hamburg',
      countryCode: 'DE',
      vatId: 'DE123456789',
    ),
  ),
];

FakeBillingCustomerRepository seedDemoBillingCustomers(String workspaceId) {
  final repo = FakeBillingCustomerRepository();
  for (final customer in _customers) {
    repo.seed(workspaceId, customer);
  }
  return repo;
}
