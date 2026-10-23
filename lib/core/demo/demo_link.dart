// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2872 (ADR 0047 §9) — a link into the demo that says where to start:
// `#/auth?demo=1&space=leipzig&persona=owner&to=/setup`. The demo still
// explains itself first and still asks; the link only chooses the space,
// the viewpoint and the screen once the visitor agreed. The screen is one
// of [demoLinkRoutes], never a free path (no open redirect), and anything
// the link does not name stays as the demo starts.
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../instance/instance_builder.dart';
import 'demo_persona.dart';
import 'seed/demo_second_space_seed.dart';

part 'demo_link.g.dart';

/// The screens a link may open in the demo.
@visibleForTesting
const demoLinkRoutes = {
  '/reserve',
  '/setup',
  '/workspace-settings',
  '/workspace-overview',
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

/// #2872 — the public demo opened at [to], as [persona], in [space]
/// (`pezenas`, where everything is set up, or `leipzig`, half way): what a
/// setup step's "Try it in the demo" opens. A [to] the demo does not allow
/// is left out, so the demo starts where it always does.
Uri demoLinkUri({
  String space = 'pezenas',
  DemoPersona persona = DemoPersona.owner,
  String? to,
}) => Uri.parse(
  '${InstanceAuthConfig.siteUrl}#/auth?demo=1&space=$space'
  '&persona=${persona.name}'
  '${_demoLinkAllows(to) ? '&to=$to' : ''}',
);

/// Where a link asks the demo to start.
class DemoLink {
  const DemoLink({this.persona, this.workspaceId, this.to});

  /// From the auth link's query: `persona` by name, `space` as `pezenas`
  /// or `leipzig`, `to` only when [_demoLinkAllows] it.
  factory DemoLink.parse(Map<String, String> query) => DemoLink(
    persona: DemoPersona.values
        .where((p) => p.name == query['persona'])
        .firstOrNull,
    workspaceId: switch (query['space']) {
      'pezenas' => 'ws-1',
      'leipzig' => demoSecondSpaceId,
      _ => null,
    },
    to: _demoLinkAllows(query['to']) ? query['to'] : null,
  );

  final DemoPersona? persona;
  final String? workspaceId;
  final String? to;

  bool get isEmpty => persona == null && workspaceId == null && to == null;
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
