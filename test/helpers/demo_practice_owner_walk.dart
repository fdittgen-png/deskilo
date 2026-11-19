// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3547 — the walk the two postures share: the Demo practice (Berlin, no
// places) as its owner: Overview does not say that switched-on features "wait
// for Bookable places", the guide's next step and its services step name the
// practice's own task (its prices, its services with their duration and
// price) and not a place, a membership, coffee, printing or lockers, and the
// stored flags are the same after the walk as before it. A coworking space
// (Leipzig) is the control: its guide keeps the words of its places.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_space_ids.dart';
import 'package:deskilo/features/workspace/domain/attention.dart';
import 'package:deskilo/features/workspace/providers/attention_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:deskilo/l10n/dictionary_labels.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'demo_journey.dart';

final _words = AppLocalizationsEn();

/// Fixed frames: a page that keeps a progress spinner never settles.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 6; i++) {
    await tester.pump(const Duration(milliseconds: 500));
  }
}

/// What the guide said before this change, for a business with places.
final _placeHints = [
  _words.setupStepHint('pricing'),
  _words.setupStepHint('services'),
];

Future<(DemoJourney, ProviderContainer, GoRouter)> openDemoSpaceAsOwner(
  WidgetTester tester, {
  required String space,
  required Size size,
  String persona = 'owner',
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start(
    persona: DemoPersona.values.byName(persona),
  );
  addTearDown(journey.dispose);
  journey.root
      .read(pendingDemoLinkProvider.notifier)
      .hold(DemoLink.parse({'space': space, 'persona': persona}));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: journey.root,
      child: const DeskiloRoot(),
    ),
  );
  await tester.pumpAndSettle();
  final container = ProviderScope.containerOf(
    tester.element(find.byType(DeskiloApp)),
  );
  return (journey, container, container.read(routerProvider));
}

Future<void> walkPracticeOwnerSetup(WidgetTester tester, Size size) async {
  final (_, container, router) = await openDemoSpaceAsOwner(
    tester,
    space: 'practice',
    size: size,
  );
  expect(
    container.read(currentWorkspaceProvider).value?.id,
    demoPracticeSpaceId,
  );
  final flagsBefore = {
    ...container.read(currentWorkspaceProvider).value!.featureFlags,
  };

  // Overview: no line of a feature waiting for the places.
  router.go('/workspace-overview');
  await _settle(tester);
  final lines = await container.read(attentionProvider.future);
  expect(
    [
      for (final a in lines)
        if (a.action == AttentionAction.unblock) a.subject,
    ],
    isEmpty,
    reason: 'the practice keeps its places off by its own kind',
  );
  expect(find.textContaining('waits for'), findsNothing);
  expect(find.textContaining('wait for'), findsNothing);

  // The guide: the next step says the practice's own task.
  router.go('/setup');
  await _settle(tester);
  final next = find.byKey(const ValueKey('setup-guide-next'));
  expect(next, findsOneWidget);
  for (final hint in _placeHints) {
    expect(find.text(hint), findsNothing, reason: hint);
  }
  expect(
    find.descendant(
      of: next,
      matching: find.text(_words.noPlacesSetupPricingHint),
    ),
    findsOneWidget,
    reason: 'the practice\'s next step is its prices and plans',
  );

  // Its services: the existing ones with their price, no coffee or lockers.
  router.go('/setup/step/services');
  await _settle(tester);
  expect(find.text(_words.noPlacesSetupServicesHint), findsOneWidget);
  for (final hint in _placeHints) {
    expect(find.text(hint), findsNothing, reason: hint);
  }
  final service = container
      .read(currentWorkspaceProvider)
      .value!
      .name; // the practice's own name keeps the walk honest
  expect(service, isNotEmpty);

  expect(
    container.read(currentWorkspaceProvider).value!.featureFlags,
    flagsBefore,
    reason: 'visiting Overview and the guide writes no flag',
  );
  // unmounted, so what the guide's pages keep running does not reach the
  // next walk of this file
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump();
}
