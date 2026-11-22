// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 -- the engagements of the services ordered, one store per Demo space, built
// when first read and kept for the session: over the space's own quotes and invoices
// (it reads them and changes none). Kessler Conseil's training engagement is done
// before its invoice.
import 'data/fake_service_fulfilments.dart';
import 'demo_fixture.dart';
import 'demo_spaces.dart';
import 'seed/demo_freelancer_seed.dart';

final _made = Expando<Map<DemoSpaceKey, FakeServiceFulfilmentRepository>>('demo engagements');

/// The engagements of [key]'s space in [fixture]'s session.
FakeServiceFulfilmentRepository demoServiceFulfilments(DemoFixture fixture, DemoSpaceKey key) =>
    (_made[fixture] ??= {}).putIfAbsent(key, () {
      final stores = fixture.stores.at(key);
      return FakeServiceFulfilmentRepository(
        workspaceId: key.id,
        quotes: stores.customerQuotes,
        invoices: () => fixture.space(key).money.invoices,
        matches: () => fixture.space(key).money.invoiceMatchesStore,
        hasCustomer: (id) => stores.billingCustomers.of(key.id).any((p) => p.subjectId == id),
        actor: () => fixture.actor.memberId,
        clock: () => fixture.seededAt,
        seed: key == DemoSpaceKey.freelancer
            ? (r) => seedFreelancerEngagement(r, stores.customerQuotes)
            : null,
      );
    });
