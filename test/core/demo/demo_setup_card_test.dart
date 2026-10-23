// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 — the setup guide, run inside the demo, says what the demo is: it
// keeps everything on the device, it resets, it names the space and the
// persona, and it switches between the space that is set up and the one
// half way, whose guide then reads as that space's. Outside the demo the
// card is not there.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/presentation/demo_setup_card.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/core/demo/seed/demo_people_seed.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _card = ValueKey('demo-setup-card');

String _cardText(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(of: find.byKey(_card), matching: find.byType(Text)),
    )
    .map((t) => t.data ?? '')
    .join(' | ');

void main() {
  testWidgets('in the demo the guide explains it, names the space and the '
      'persona, and switches to the space half way and back', (tester) async {
    await tester.binding.setSurfaceSize(const Size(900, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final outer = ProviderContainer();
    addTearDown(outer.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: outer,
        child: const DemoWorkspace(child: DeskiloApp()),
      ),
    );
    await tester.pumpAndSettle();
    final demo = ProviderScope.containerOf(
      tester.element(find.byType(DeskiloApp)),
    );
    demo.read(routerProvider).go('/setup');
    await tester.pumpAndSettle();

    expect(_cardText(tester), contains('leaves this device'));
    expect(_cardText(tester), contains('reset the demo'));
    expect(_cardText(tester), contains(demoSpaceName));
    expect(_cardText(tester), contains('The owner'));
    expect(_cardText(tester), contains('every step'));
    expect(find.byKey(const ValueKey('setup-guide-all-done')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('demo-setup-switch')));
    await tester.pumpAndSettle();
    expect(demo.read(currentWorkspaceProvider).value?.id, demoSecondSpaceId);
    expect(_cardText(tester), contains(demoSecondSpaceName));
    expect(_cardText(tester), contains('half way'));
    expect(
      find.byKey(const ValueKey('setup-guide-next-pricing')),
      findsOneWidget,
      reason: "the guide now reads Leipzig's own status",
    );

    await tester.tap(find.byKey(const ValueKey('demo-setup-switch')));
    await tester.pumpAndSettle();
    expect(demo.read(currentWorkspaceProvider).value?.id, 'ws-1');
    expect(find.byKey(const ValueKey('setup-guide-all-done')), findsOneWidget);

    final before = outer.read(demoSessionControllerProvider).scopeKey;
    await tester.tap(find.byKey(const ValueKey('demo-setup-reset')));
    await tester.pumpAndSettle();
    expect(
      outer.read(demoSessionControllerProvider).scopeKey,
      isNot(before),
      reason: "the card's reset is the demo bar's: a new session",
    );
    expect(find.text('The demo is back as it started.'), findsOneWidget);
  });

  testWidgets('outside the demo there is no card', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(home: Scaffold(body: DemoSetupCard())),
      ),
    );
    expect(find.byKey(_card), findsNothing);
  });
}
