// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3553 — the Demo walked in its reference business, Atelier du Marché: the
// owner marks its services public in Services (the inactive Locker too, which
// stays off the page: only an active service is published); the public page's
// preview shows it with the business's kind and its tax word; an anonymous
// reader finds Atelier by the service's name and by its kind; and the Zurich
// house stands beside it, each price in its own currency with its own tax
// word, nothing added or converted.
import 'package:deskilo/core/demo/data/connected_installations.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/directory/domain/discovery_paging.dart';
import 'package:deskilo/features/directory/domain/public_workspace.dart';
import 'package:deskilo/features/directory/providers/directory_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/screens/demo_journeys.dart';
import '../helpers/screens/desk_calendar.dart' show goTo;

void main() {
  testWidgets('the owner publishes a service; the page shows it; a stranger '
      'finds it by name and by kind, Zurich beside it in francs', (
    tester,
  ) async {
    await pumpDemo(tester, openHub: false, size: const Size(1440, 900));

    // Services: the owner marks each service public.
    Future<void> markPublic(String name) async {
      await goTo(tester, '/services');
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      final public = find.byKey(const ValueKey('services-public'));
      await tester.ensureVisible(public);
      await tester.tap(public);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('services-save')));
      await tester.pumpAndSettle();
    }

    for (final name in ['Coffee', 'Printing', 'Locker']) {
      await markPublic(name);
    }

    // The public page's preview says what the page publishes.
    await goTo(tester, '/settings/public-page');
    final offer = find.byKey(const ValueKey('public-page-offer'));
    await tester.ensureVisible(offer);
    expect(find.text('Kind: Coworking space'), findsOneWidget);
    String line(int i) => tester
        .widget<Text>(find.byKey(ValueKey('public-page-offer-service-$i')))
        .data!;
    // The business's own order; each price with its tax word.
    expect(line(0), allOf(startsWith('Coffee · '), endsWith(' · tax included')));
    expect(line(1), allOf(startsWith('Printing · '), endsWith(' · tax included')));
    expect(
      find.byKey(const ValueKey('public-page-offer-service-2')),
      findsNothing,
      reason: 'the inactive Locker is not published, marked public or not',
    );
    expect(find.textContaining('Locker'), findsNothing);

    // A stranger's search, on the Demo's own installation.
    final repository = ProviderScope.containerOf(tester.element(offer))
        .read(publicDiscoveryRepositoryProvider);
    const source = DirectorySource(kDemoServerOrigin, '');
    Future<List<PublicWorkspace>> search(String q, {String? kind}) async =>
        (await repository.workspaces(source, q, kind: kind)).cards;

    final byName = await search('printing');
    expect(byName.map((w) => w.id), contains('ws-1'));
    final atelier = byName.firstWhere((w) => w.id == 'ws-1');
    expect(atelier.services.map((s) => s.name), ['Coffee', 'Printing']);
    expect(atelier.services.map((s) => s.currency).toSet(), {'EUR'});
    expect(
      atelier.services.map((s) => s.taxTreatment).toSet(),
      {PublicTaxTreatment.included},
    );
    expect(await search('locker'), isEmpty,
        reason: 'an inactive service is not found either');

    final coworking = await search('', kind: 'coworking');
    expect(coworking.map((w) => w.id), containsAll(['ws-1', 'demo-zurich']));
    // #3554 — the practice nearby is found by its kind, and not among the
    // coworking spaces.
    expect(
      (await search('', kind: 'practice')).map((w) => w.id),
      unorderedEquals(['demo-practice-garrigue', demoPracticeSpaceId]),
    );
    expect(coworking.map((w) => w.id), isNot(contains('demo-practice-garrigue')));
    final zurich = coworking.firstWhere((w) => w.id == 'demo-zurich');
    expect(zurich.services.map((s) => s.currency).toSet(), {
      'CHF',
    }, reason: 'its own currency, never converted');
    expect(zurich.services.first.taxTreatment, PublicTaxTreatment.included);
  });
}
