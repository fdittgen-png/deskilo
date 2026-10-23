// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 — a demo link, applied: the visitor reads the explanation, agrees,
// and the demo opens in the space the link named, as the persona it named,
// on the screen it named. The sheet applies the persona; `DemoWorkspace`
// applies the space and the screen after its first frame. Both halves run
// here as the app runs them, with the real router and its guards.
import 'package:deskilo/app/app.dart';
import 'package:deskilo/app/router.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/demo_session.dart';
import 'package:deskilo/core/demo/presentation/demo_entry_sheet.dart';
import 'package:deskilo/core/demo/presentation/demo_workspace.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/workspace/providers/workspace_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Where the demo stands once the link is applied.
typedef _Landed = ({DemoPersona persona, String? space, String path});

/// Follows [query] as the auth screen does: offers the demo with the
/// link, agrees, then mounts the demo the way the app root does.
Future<_Landed> _follow(WidgetTester tester, Map<String, String> query) async {
  await tester.binding.setSurfaceSize(const Size(900, 1600));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  final outer = ProviderContainer();
  addTearDown(outer.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: outer,
      child: MaterialApp(
        home: Consumer(
          builder: (context, ref, _) => TextButton(
            key: const ValueKey('offer'),
            onPressed: () =>
                offerDemoEntry(context, ref, link: DemoLink.parse(query)),
            child: const SizedBox.square(dimension: 48),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.byKey(const ValueKey('offer')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('demo-entry-start')));
  await tester.pumpAndSettle();
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
  return (
    persona: outer.read(demoSessionControllerProvider).persona,
    space: demo.read(currentWorkspaceProvider).value?.id,
    path: demo
        .read(routerProvider)
        .routerDelegate
        .currentConfiguration
        .uri
        .path,
  );
}

void main() {
  const cases = <(Map<String, String>, _Landed)>[
    (
      {'demo': '1', 'space': 'leipzig', 'persona': 'owner', 'to': '/setup'},
      (persona: DemoPersona.owner, space: demoSecondSpaceId, path: '/setup'),
    ),
    (
      {
        'demo': '1',
        'space': 'pezenas',
        'persona': 'owner',
        'to': '/setup/step/places',
      },
      (persona: DemoPersona.owner, space: 'ws-1', path: '/setup/step/places'),
    ),
    (
      {'demo': '1', 'space': 'pezenas', 'persona': 'admin', 'to': '/members'},
      (persona: DemoPersona.admin, space: 'ws-1', path: '/members'),
    ),
    (
      {'demo': '1', 'space': 'leipzig', 'persona': 'member', 'to': '/reserve'},
      (persona: DemoPersona.member, space: demoSecondSpaceId, path: '/reserve'),
    ),
  ];
  for (final (query, expected) in cases) {
    testWidgets('a link opens ${query['space']} as ${query['persona']} at '
        '${query['to']}', (tester) async {
      expect(await _follow(tester, query), expected);
    });
  }

  testWidgets('the kiosk persona and a screen the demo does not allow: the '
      'persona applies, the screen is where the demo always starts', (
    tester,
  ) async {
    final landed = await _follow(tester, {
      'demo': '1',
      'space': 'pezenas',
      'persona': 'kiosk',
      'to': '/database/assistant-approvals',
    });
    expect(landed.persona, DemoPersona.kiosk);
    expect(landed.space, 'ws-1');
    expect(landed.path, isNot('/database/assistant-approvals'));
  });
}
