// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4164 A2 -- the Demo's reference organisation invoices people and businesses
// that have no account, through the Demo's own composition: its home space lists
// three billing customers, a new one is created and edited under the server's
// rules (the revision check, the right), and another space starts with none --
// each space reads its own customers.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/core/failure/app_failure.dart';
import 'package:deskilo/features/money/domain/billing_customer.dart';
import 'package:deskilo/features/money/providers/billing_customer_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DemoFixture fixture;
  late ProviderContainer container;

  setUp(() {
    fixture = DemoFixture.build();
    container = ProviderContainer(overrides: demoOverrides(fixture))
      ..listen(currentWorkspaceProvider, (_, _) {});
  });
  tearDown(() => container.dispose());

  Future<String> enter() async {
    final workspace = await container.read(currentWorkspaceProvider.future);
    return workspace!.id;
  }

  test('the home space lists its three billing customers, none of them a '
      'member', () async {
    final id = await enter();
    final customers = await container.read(billingCustomersProvider(id).future);
    expect(customers.map((c) => c.displayName), [
      'Atelier Lumi',
      'Hanna Weiss',
      'Nordlicht GmbH',
    ]);
    expect(customers.every((c) => c.status == 'customer'), isTrue);
    final members = await container.read(workspaceMembersProvider.future);
    for (final c in customers) {
      expect(members.any((m) => m.id == c.subjectId), isFalse);
    }
  });

  test('a customer is created, then edited at the revision read; a stale '
      'edit changes nothing', () async {
    final id = await enter();
    final commands = container.read(billingCustomerCommandProvider);
    final created = await commands.create(
      id,
      const BillingPartyDraft(
        company: 'Studio Nord',
        city: 'Kiel',
        countryCode: 'de',
      ),
      capacity: 'business',
    );
    expect(created, isA<CommandDone<String>>());
    container.invalidate(billingCustomersProvider(id));
    final read = (await container.read(billingCustomersProvider(id).future))
        .firstWhere((c) => c.displayName == 'Studio Nord');
    expect(read.draft.countryCode, 'DE');
    expect(read.capacity, 'business');

    expect(
      await commands.save(
        id,
        read,
        const BillingPartyDraft(company: 'Studio Nord', city: 'Hamburg'),
      ),
      isA<CommandDone<String>>(),
    );
    final stale = await commands.save(
      id,
      read,
      const BillingPartyDraft(company: 'Studio Nord', city: 'Bremen'),
    );
    expect(((stale as CommandRefused<String>).refusal.cause! as BillingCustomerRefusal).kind, BillingCustomerRefusalKind.stale);
    container.invalidate(billingCustomersProvider(id));
    final now = (await container.read(billingCustomersProvider(id).future))
        .firstWhere((c) => c.subjectId == read.subjectId);
    expect(now.draft.city, 'Hamburg');
    expect(now.revision, 2);
  });

  test(
    'another space starts with none: each space reads its own customers',
    () async {
      await enter();
      container
          .read(activeWorkspaceIdProvider.notifier)
          .activate(demoSecondSpaceId);
      final other = await container.read(currentWorkspaceProvider.future);
      expect(other?.id, demoSecondSpaceId);
      expect(
        await container.read(billingCustomersProvider(other!.id).future),
        isEmpty,
      );
    },
  );
}
