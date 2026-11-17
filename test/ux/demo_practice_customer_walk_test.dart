// SPDX-License-Identifier: AGPL-3.0-or-later
//
// One selectable customer discovers and contacts the practice and coworking
// business through the Demo repositories, then pays their invoices through
// My finances. Publication and invoices share the practice's own catalogue;
// selections stay within one business and balances stay in each currency.
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/directory/domain/discovery_paging.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/providers/directory_providers.dart';
import 'package:deskilo/features/directory/providers/messenger_providers.dart';
import 'package:deskilo/features/money/domain/finance_overview.dart';
import 'package:deskilo/features/money/providers/finance_overview_provider.dart';
import 'package:deskilo/features/money/providers/finance_selection_provider.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart';
import '../helpers/screens/desk_calendar.dart' show goTo;

Future<void> _tap(WidgetTester tester, String key) async {
  final target = find.byKey(ValueKey(key));
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Bruno finds, contacts and pays the practice and coworking '
      'business as the same customer', (tester) async {
    final journey = await pumpDemo(
      tester,
      persona: DemoPersona.member,
      openHub: false,
      size: const Size(1440, 1600),
    );
    final fixture = journey.fixture;
    final container = ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    );
    final directory = container.read(publicDiscoveryRepositoryProvider);
    const source = DirectorySource(kDemoServerOrigin, '');
    final practices = await directory.workspaces(source, '', kind: 'practice');
    expect(practices.cards.map((w) => w.id), contains(demoPracticeSpaceId));
    final practice = practices.cards.singleWhere(
      (w) => w.id == demoPracticeSpaceId,
    );
    expect(practice.name, 'Lindner Beratung');
    expect(practice.takesInquiries, isTrue);
    final publication = await container
        .read(publicationRepositoryProvider)
        .ownPage(practice.id);
    expect(publication['published'], isTrue);
    expect((publication['document'] as Map)['name'], practice.name);
    final consultation = practice.services.singleWhere(
      (s) => s.name == 'Consultation hour',
    );
    expect(consultation.durationMinutes, 60);
    expect(consultation.priceMinor, 9000);
    expect(consultation.currency, 'EUR');
    expect(consultation.taxTreatment, PublicTaxTreatment.included);
    final coworking = await directory.workspaces(source, '', kind: 'coworking');
    expect(coworking.cards.map((w) => w.id), contains(demoFirstSpaceId));
    expect(coworking.cards.map((w) => w.id), isNot(contains(practice.id)));

    final messenger = container.read(
      messengerRepositoryProvider(source: kDemoServerOrigin),
    );
    for (final id in [practice.id, demoFirstSpaceId]) {
      expect(await messenger.hostRoster(id), isNotEmpty);
      final inquiry = await messenger.startInquiry(id, 'A question about $id');
      final messages = await messenger.inquiryMessages(inquiry);
      expect(messages.single.body, 'A question about $id');
      expect(messages.single.mine, isTrue);
    }
    expect(
      (await container.read(myWorkspacesProvider.future)).map((w) => w.id),
      containsAll([practice.id, demoFirstSpaceId]),
    );
    final people = fixture.practice.workspaces;
    expect(people.myMember.id, DemoPersona.member.memberId);
    expect(
      people.otherMembers.where((m) => m.id.startsWith('practice-member-')),
      hasLength(4),
    );
    expect(
      fixture.practice.money.invoices.where(
        (i) => i.memberId == DemoPersona.owner.memberId,
      ),
      isEmpty,
    );

    await goTo(tester, '/me/data?view=finances');
    FinanceOverview overview() =>
        container.read(financeOverviewProvider).requireValue;
    final before = Map<String, int>.from(overview().owedByCurrency);
    final practiceInvoice = overview().invoices.singleWhere(
      (i) => i.workspaceId == practice.id && i.payable,
    );
    final practiceDue = practiceInvoice.stillDueCents!;
    const atelierIds = ['demo-invoice-bruno', 'demo-usage-bruno'];
    expect(
      overview().invoices
          .where((i) => atelierIds.contains(i.id))
          .fold<int>(0, (total, i) => total + i.stillDueCents!),
      12480,
    );
    await _tap(tester, 'finances-select-${practiceInvoice.id}');
    // The actual other-business checkbox cannot expand this selection.
    await _tap(tester, 'finances-select-${atelierIds.first}');
    expect(container.read(financeSelectionProvider).invoices.map((i) => i.id), [
      practiceInvoice.id,
    ]);
    await _tap(tester, 'finances-selection-pay');
    await _tap(tester, 'finances-confirm-send');
    await _tap(tester, 'demo-provider-pay');
    expect(
      overview().invoices.singleWhere((i) => i.id == practiceInvoice.id).state,
      FinanceState.paid,
    );
    expect(overview().owedByCurrency, {
      ...before,
      'EUR': before['EUR']! - practiceDue,
    });

    for (final id in atelierIds) {
      await _tap(tester, 'finances-select-$id');
    }
    await _tap(tester, 'finances-selection-pay');
    await _tap(tester, 'finances-confirm-send');
    await _tap(tester, 'demo-provider-pay');
    expect(overview().owedByCurrency, {
      ...before,
      'EUR': before['EUR']! - practiceDue - 12480,
    });
    for (final id in atelierIds) {
      expect(
        overview().invoices.singleWhere((i) => i.id == id).state,
        FinanceState.paid,
      );
    }
  });
}
