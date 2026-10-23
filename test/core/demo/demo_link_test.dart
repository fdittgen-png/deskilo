// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 — a link into the demo chooses the space, the viewpoint and the
// screen, and nothing else: an unknown persona or space is ignored, a
// screen outside the allow-list is never opened, and the link applies once.
import 'package:deskilo/app/route_classes.dart';
import 'package:deskilo/core/demo/demo_link.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/demo/seed/demo_second_space_seed.dart';
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

  test('the demo link names the space and the persona, and leaves out a '
      'screen the demo does not allow', () {
    final link = demoLinkUri(space: 'leipzig', to: '/nowhere');
    expect(link.toString(), startsWith('https://'));
    final query = Uri.parse(link.fragment).queryParameters;
    expect(query, {'demo': '1', 'space': 'leipzig', 'persona': 'owner'});
  });
}
