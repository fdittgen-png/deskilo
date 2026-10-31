// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The real Leipzig demo gives its co-owner the setup resume banner and
// pricing door, its member the member card, and unknown membership neither
// card until the owner answer arrives. The hub reads the actual demo facts.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/data/local_setup_repository.dart';
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_scope.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/reservations/application/getting_started_hint.dart';
import 'package:deskilo/features/reservations/presentation/widgets/getting_started_card.dart';
import 'package:deskilo/features/workspace/domain/member.dart';
import 'package:deskilo/features/workspace/presentation/screens/setup_guide_screen.dart';
import 'package:deskilo/features/workspace/providers/local_setup_providers.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/demo_journey.dart';
import '../../helpers/mock_providers.dart';
import '../../helpers/screens/getting_started_card.dart';

const _banner = ValueKey('setup-resume-banner');
const _card = ValueKey('getting-started-card');

class _PendingMembership extends FakeWorkspaceRepository {
  _PendingMembership()
    : super.withWorkspace(featureFlags: const {'setupGuide': true});

  final answer = Completer<Member?>();

  @override
  Future<Member?> fetchMyMember(String workspaceId) => answer.future;
}

Future<ProviderContainer> _openLeipzig(
  WidgetTester tester,
  DemoPersona persona,
) async {
  tester.view.physicalSize = const Size(900, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final journey = DemoJourney.start(persona: persona);
  addTearDown(journey.dispose);
  journey.fixture.prefs.locale.languageCode = 'fr';
  journey.root
      .read(pendingDemoLinkProvider.notifier)
      .hold(
        DemoLink.parse({
          'space': 'leipzig',
          'persona': persona.name,
          'to': '/reserve',
        }),
      );
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
  expect(container.read(currentWorkspaceProvider).value?.id, demoSecondSpaceId);
  expect(
    container.read(routerProvider).routeInformationProvider.value.uri.path,
    '/reserve',
  );
  return container;
}

GettingStartedFacts _facts(WidgetTester tester) =>
    tester.widget<ReserveHelpHost>(find.byType(ReserveHelpHost)).facts;

void main() {
  testWidgets('Leipzig owner facts show the setup banner and resume pricing', (
    tester,
  ) async {
    final container = await _openLeipzig(tester, DemoPersona.owner);
    final member = container.read(myMemberProvider).value!;
    expect(member.isOwner, isFalse);
    expect(member.coOwner, CoOwnerStatus.active);
    expect(_facts(tester).membership.value, MembershipStanding.owner);
    expect(_facts(tester).membership.known, isTrue);
    expect(find.byKey(_banner), findsOneWidget);
    expect(find.byKey(_card), findsNothing);

    final status = await container.read(
      workspaceSetupStatusProvider(demoSecondSpaceId).future,
    );
    expect(status.nextMilestone?.milestone, 'money');
    expect(status.nextStep?.step, 'pricing');
    final l10n = lookupAppLocalizations(const Locale('fr'));
    expect(find.textContaining(l10n.setupStepTitle('pricing')), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('setup-resume-open')));
    await tester.tap(find.byKey(const ValueKey('setup-resume-open')));
    await tester.pumpAndSettle();
    expect(find.byType(SetupGuideScreen), findsOneWidget);
    expect(
      container.read(routerProvider).routeInformationProvider.value.uri.path,
      '/setup',
    );
    expect(
      find.byKey(const ValueKey('setup-guide-next-pricing')),
      findsOneWidget,
    );
  });

  testWidgets('a Leipzig member sees their own card instead of setup', (
    tester,
  ) async {
    await _openLeipzig(tester, DemoPersona.member);
    expect(_facts(tester).membership.value, MembershipStanding.member);
    expect(find.byKey(_card), findsOneWidget);
    expect(find.byKey(_banner), findsNothing);
  });

  testWidgets('unknown membership shows neither card, then the owner banner', (
    tester,
  ) async {
    final fixture = DemoFixture.build();
    final demo = ProviderContainer(overrides: demoOverrides(fixture));
    addTearDown(demo.dispose);
    final status = await demo
        .read(localSetupRepositoryProvider)
        .setupStatus(demoSecondSpaceId);
    final workspace = _PendingMembership();
    await pumpCard(
      tester,
      workspace: workspace,
      localSetup: FakeLocalSetupRepository(status: status),
    );
    expect(_facts(tester).membership.known, isFalse);
    expect(find.byKey(_card), findsNothing);
    expect(find.byKey(_banner), findsNothing);

    workspace.answer.complete(
      kOrdinaryMember.copyWith(coOwner: CoOwnerStatus.active),
    );
    await tester.pumpAndSettle();
    expect(_facts(tester).membership.value, MembershipStanding.owner);
    expect(find.byKey(_banner), findsOneWidget);
    expect(find.byKey(_card), findsNothing);
  });
}
