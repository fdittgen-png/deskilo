// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 (ADR 0047 §9) — a link into the demo that says where to start:
// `#/demo?space=leipzig&persona=owner&to=/setup` (the older `#/auth?demo=1` form still works). The demo still
// explains itself first and still asks; the link only chooses the space,
// the viewpoint and the screen once the visitor agreed. The screen is one
// of [demoLinkRoutes], never a free path (no open redirect), and anything
// the link does not name stays as the demo starts.
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'demo_persona.dart';
import 'seed/demo_london_seed.dart';
import 'seed/demo_second_space_seed.dart';

part 'demo_link.g.dart';

/// The screens a link may open in the demo.
@visibleForTesting
const demoLinkRoutes = {
  '/reserve',
  '/setup',
  '/workspace-settings',
  '/settings', // #3077 — the settings' resume banner, for a tester
  '/workspace-overview',
  '/vat-declarations',
  '/features',
  '/calendar',
  '/members',
  '/events',
  '/money',
  '/editor',
  '/billing',
  '/reports',
  // #2872 — every screen a setup step opens, for its "Try it in the demo".
  '/availability',
  '/roles',
  '/workspace-code',
  '/services',
  '/payment-methods',
  '/payment-config',
  '/validation',
  '/nfc-config',
  '/money/purchases',
  '/settings/colours',
  '/settings/public-page',
  '/legal-identity',
  '/vat',
  '/settings/number-sequences',
  '/einvoice-config',
  '/settings/payment-terms',
  '/settings/assistant-setup',
};

/// A screen the demo may start on: one of [demoLinkRoutes], or a setup
/// step's own page (`/setup/step/<id>`, #2870).
bool _demoLinkAllows(String? to) =>
    to != null &&
    (demoLinkRoutes.contains(to) || RegExp(r'^/setup/step/[a-z_]+$').hasMatch(to));

/// Where a link asks the demo to start.
class DemoLink {
  const DemoLink({this.persona, this.workspaceId, this.to});

  /// From the auth link's query: `persona` by name, `space` as `pezenas`
  /// `leipzig` or `london`, `to` only when [_demoLinkAllows] it.
  factory DemoLink.parse(Map<String, String> query) => DemoLink(
    persona: DemoPersona.values
        .where((p) => p.name == query['persona'])
        .firstOrNull,
    workspaceId: switch (query['space']) {
      'pezenas' => demoFirstSpaceId,
      'leipzig' => demoSecondSpaceId,
      'london' => demoLondonSpaceId,
      _ => null,
    },
    to: _demoLinkAllows(query['to']) ? query['to'] : null,
  );

  /// The link a setup step's example uses from inside the app (#3235): the
  /// owner of the complete space, at [to] when the demo allows it.
  factory DemoLink.example({String? to}) => DemoLink(
    persona: DemoPersona.owner,
    workspaceId: demoFirstSpaceId,
    to: _demoLinkAllows(to) ? to : null,
  );

  final DemoPersona? persona;
  final String? workspaceId;
  final String? to;

  bool get isEmpty => persona == null && workspaceId == null && to == null;

  /// The query that names exactly this link (#3235): only what [parse]
  /// accepts, so a redirect built from it carries nothing else.
  Map<String, String> toQuery() => {
    'space': ?switch (workspaceId) {
      null => null,
      demoSecondSpaceId => 'leipzig',
      demoLondonSpaceId => 'london',
      _ => 'pezenas',
    },
    'persona': ?persona?.name,
    'to': ?to,
  };
}

/// The link the visitor arrived with, until the demo has applied it. It
/// lives above the demo scope, like the session.
@Riverpod(keepAlive: true)
class PendingDemoLink extends _$PendingDemoLink {
  @override
  DemoLink? build() => null;

  void hold(DemoLink link) => state = link.isEmpty ? null : link;

  /// The link, once: applying it twice would undo a visitor's own moves.
  DemoLink? take() {
    final link = state;
    state = null;
    return link;
  }
}
