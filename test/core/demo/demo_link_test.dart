// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 — a link into the demo chooses the space, the viewpoint and the
// screen, and nothing else: an unknown persona or space is ignored, a
// screen outside the allow-list is never opened, and the link applies once.
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
import 'package:deskilo/features/workspace/domain/setup_level_demo.dart';
import 'package:deskilo/features/workspace/domain/setup_levels.dart';
import 'package:deskilo/features/workspace/domain/setup_steps.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a link names the space, the persona and the screen', () {
    final link = DemoLink.parse({
      'demo': '1',
      'space': 'leipzig',
      'persona': 'owner',
      'to': '/setup',
    });
    expect(link.workspaceId, demoSecondSpaceId);
    expect(link.persona, DemoPersona.owner);
    expect(link.to, '/setup');
  });

  test('what the link may not choose is ignored', () {
    final link = DemoLink.parse({
      'space': 'paris',
      'persona': 'root',
      'to': 'https://example.com',
    });
    expect(link.isEmpty, isTrue);
    expect(DemoLink.parse({'to': '/database/assistant-approvals'}).to, isNull);
  });

  test('every screen a link may open is a route of the app', () {
    final known = {for (final r in routeRules) r.pattern};
    expect(demoLinkRoutes.difference(known), isEmpty);
  });

  test('the link applies once', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container
        .read(pendingDemoLinkProvider.notifier)
        .hold(DemoLink.parse({'to': '/setup'}));
    expect(
      container.read(pendingDemoLinkProvider.notifier).take()?.to,
      '/setup',
    );
    expect(container.read(pendingDemoLinkProvider.notifier).take(), isNull);
  });

  test('every setup step can be tried in the demo, at its own screen', () {
    for (final step in setupSteps) {
      final link = demoLinkUri(to: step.route);
      final query = Uri.parse(link.fragment).queryParameters;
      expect(DemoLink.parse(query).to, step.route, reason: step.id);
    }
  });

  test('#2868 — every level that adds something can be seen in the demo, '
      'at a screen the link allows; a level that adds nothing has none', () {
    for (final MapEntry(key: process, value: levels) in setupLevels.entries) {
      for (final level in levels) {
        final route = setupLevelDemoRoute(process, level.id);
        final where = '${process.name}.${level.id}';
        if (level.features.isEmpty) {
          expect(route, isNull, reason: where);
          continue;
        }
        expect(route, isNotNull, reason: where);
        final link = demoLinkUri(to: route);
        final query = Uri.parse(link.fragment).queryParameters;
        expect(DemoLink.parse(query).to, route, reason: where);
        expect(query['space'], 'pezenas', reason: where);
      }
    }
  });

  test('the demo link names the space and the persona, and leaves out a '
      'screen the demo does not allow', () {
    final link = demoLinkUri(space: 'leipzig', to: '/nowhere');
    expect(link.toString(), startsWith('https://'));
    final query = Uri.parse(link.fragment).queryParameters;
    expect(query, {'demo': '1', 'space': 'leipzig', 'persona': 'owner'});
  });

  test('every persona in either space survives the round trip', () {
    for (final persona in DemoPersona.values) {
      for (final (space, id) in [
        ('pezenas', 'ws-1'),
        ('leipzig', demoSecondSpaceId),
      ]) {
        final uri = demoLinkUri(space: space, persona: persona, to: '/calendar');
        final link = DemoLink.parse(Uri.parse(uri.fragment).queryParameters);
        expect(
          (link.persona, link.workspaceId, link.to),
          (persona, id, '/calendar'),
          reason: '$space as ${persona.name}',
        );
      }
    }
  });

  test("a setup step's page opens; a path that only looks like one does "
      'not', () {
    expect(
      DemoLink.parse({'to': '/setup/step/member_rights'}).to,
      '/setup/step/member_rights',
    );
    for (final to in [
      '/setup/step/',
      '/setup/step/Places',
      '/setup/step/places/../../database',
      '//example.com/setup/step/places',
      '/reserve?next=https://example.com',
    ]) {
      expect(DemoLink.parse({'to': to}).to, isNull, reason: to);
    }
  });

  test('a screen the demo does not allow is ignored, and the rest of the '
      'link still applies', () {
    final link = DemoLink.parse({
      'demo': '1',
      'space': 'pezenas',
      'persona': 'kiosk',
      'to': '/database/assistant-approvals',
    });
    expect(link.persona, DemoPersona.kiosk);
    expect(link.workspaceId, 'ws-1');
    expect(link.to, isNull);
  });
}
