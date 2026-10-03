// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1881 — the frozen coverage manifest: every route the router
// registers, and what the task recorder does on it.
//
//   recorded  — instrumented: its own seams name the steps;
//   recorder  — the recorder's own screens: never recorded;
//   excluded  — a protected screen: one marker, its category, nothing of
//               its contents (sign-in, payment, messages, providers,
//               secrets, identity, the installation operator);
//   planned   — an ordinary or administrative form with no seams of its
//               own YET: since #2142 the generic layer notes it (the
//               screen, keyed taps, fields left, guarded commands), and
//               its precise steps are owned by the rollout named in
//               [RouteCoverage.owner] (#1881 A/B/C, #1884). A path no
//               row names is a visible "cannot describe" step.
//
// test/features/task_recorder/coverage_manifest_test.dart keeps this list
// and lib/app/route_classes.dart (itself kept in step with the router) in
// step both ways: a new route without a row fails, a row without a route
// fails, and every registered action must be named by some recorded
// route and called from some seam.

import 'action_registry.dart';

enum CoverageStatus { recorded, recorder, excluded, planned }

class RouteCoverage {
  const RouteCoverage(
    this.route,
    this.status, {
    this.category,
    this.owner,
    this.selfOpening = false,
  });

  /// The route pattern as the router registers it (`:name` = a segment).
  final String route;
  final CoverageStatus status;

  /// On an excluded route: which kind of protected screen it is.
  final ProtectedSurface? category;

  /// On a planned route: the rollout that instruments it.
  final String? owner;

  /// #2142 — on a recorded route: its screen notes its own opening.
  final bool selfOpening;

  bool matches(String path) {
    final want = route.split('/');
    final got = path.split('/');
    if (want.length != got.length) return false;
    for (var i = 0; i < want.length; i++) {
      if (want[i].startsWith(':')) {
        if (got[i].isEmpty) return false;
      } else if (want[i] != got[i]) {
        return false;
      }
    }
    return true;
  }
}

/// The manifest, in route_classes.dart's order.
const List<RouteCoverage> routeCoverage = [
  RouteCoverage('/me', CoverageStatus.planned, owner: '#1881 B'),
  RouteCoverage('/discover', CoverageStatus.planned, owner: '#1881 B'),
  RouteCoverage(
    '/connections',
    CoverageStatus.excluded,
    category: ProtectedSurface.provider,
  ),
  RouteCoverage(
    '/account-messages',
    CoverageStatus.excluded,
    category: ProtectedSurface.messenger,
  ),
  RouteCoverage(
    '/settings/public-page',
    CoverageStatus.planned,
    owner: '#1884',
  ),
  RouteCoverage(
    '/auth',
    CoverageStatus.excluded,
    category: ProtectedSurface.authentication,
  ),
  RouteCoverage('/help', CoverageStatus.planned, owner: '#1881 C'),
  RouteCoverage(
    '/privacy',
    CoverageStatus.excluded,
    category: ProtectedSurface.identity,
  ),
  RouteCoverage(
    '/server',
    CoverageStatus.excluded,
    category: ProtectedSurface.secrets,
  ),
  RouteCoverage(
    '/server-update',
    CoverageStatus.excluded,
    category: ProtectedSurface.operator,
  ),
  RouteCoverage(
    '/server/new-instance',
    CoverageStatus.excluded,
    category: ProtectedSurface.operator,
  ),
  RouteCoverage(
    '/consent',
    CoverageStatus.excluded,
    category: ProtectedSurface.authentication,
  ),
  RouteCoverage('/profiles', CoverageStatus.planned, owner: '#1881 B'),
  RouteCoverage(
    '/applications',
    CoverageStatus.excluded,
    category: ProtectedSurface.provider,
  ),
  RouteCoverage('/task-recorder', CoverageStatus.recorder),
  RouteCoverage('/task-workbench', CoverageStatus.recorder),
  RouteCoverage('/account-activity', CoverageStatus.planned, owner: '#1881 B'),
  RouteCoverage(
    '/linked-accounts',
    CoverageStatus.excluded,
    category: ProtectedSurface.authentication,
  ),
  RouteCoverage('/onboarding', CoverageStatus.planned, owner: '#1881 B'),
  RouteCoverage(
    '/scan-join',
    CoverageStatus.excluded,
    category: ProtectedSurface.authentication,
  ),
  RouteCoverage(
    '/mcp/confirm/:id',
    CoverageStatus.excluded,
    category: ProtectedSurface.provider,
  ),
  RouteCoverage(
    '/oauth/consent',
    CoverageStatus.excluded,
    category: ProtectedSurface.authentication,
  ),
  RouteCoverage(
    '/assistants',
    CoverageStatus.excluded,
    category: ProtectedSurface.provider,
  ),
  RouteCoverage(
    '/assistants/connect',
    CoverageStatus.excluded,
    category: ProtectedSurface.provider,
  ),
  RouteCoverage(
    '/database/assistant-approvals',
    CoverageStatus.excluded,
    category: ProtectedSurface.provider,
  ),
  RouteCoverage(
    '/installation/assistants',
    CoverageStatus.excluded,
    category: ProtectedSurface.operator,
  ),
  RouteCoverage(
    '/settings/assistants',
    CoverageStatus.excluded,
    category: ProtectedSurface.provider,
  ),
  RouteCoverage(
    '/settings/assistant-setup',
    CoverageStatus.excluded,
    category: ProtectedSurface.provider,
  ),
  RouteCoverage(
    '/kiosk-gate',
    CoverageStatus.excluded,
    category: ProtectedSurface.authentication,
  ),
  RouteCoverage(
    '/kiosk',
    CoverageStatus.excluded,
    category: ProtectedSurface.authentication,
  ),
  RouteCoverage('/pending', CoverageStatus.planned, owner: '#1881 B'),
  RouteCoverage(
    '/messages',
    CoverageStatus.excluded,
    category: ProtectedSurface.messenger,
  ),
  RouteCoverage('/calendar', CoverageStatus.planned, owner: '#1881 A'),
  RouteCoverage('/directory', CoverageStatus.planned, owner: '#1881 B'),
  RouteCoverage(
    '/money',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage('/reserve', CoverageStatus.recorded, selfOpening: true),
  RouteCoverage('/settings', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage(
    '/developer',
    CoverageStatus.excluded,
    category: ProtectedSurface.secrets,
  ),
  RouteCoverage('/formats', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/events', CoverageStatus.planned, owner: '#1881 A'),
  RouteCoverage('/plan', CoverageStatus.recorded),
  RouteCoverage(
    '/conversation/:conversationId',
    CoverageStatus.excluded,
    category: ProtectedSurface.messenger,
  ),
  RouteCoverage('/res/:id', CoverageStatus.recorded),
  RouteCoverage('/space/:kind/:id', CoverageStatus.planned, owner: '#1881 A'),
  RouteCoverage('/library', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/workspace-code', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage(
    '/nfc-config',
    CoverageStatus.excluded,
    category: ProtectedSurface.secrets,
  ),
  RouteCoverage(
    '/payment-config',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage(
    '/billing',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage(
    '/invoices',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage(
    '/invoice-register',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage(
    '/einvoice-config',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage('/documents', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage(
    '/invoicing/wizard',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage('/member/:memberId', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/report-editor', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/roles', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage(
    '/settings/personal-info',
    CoverageStatus.excluded,
    category: ProtectedSurface.identity,
  ),
  RouteCoverage(
    '/settings/payment-terms',
    CoverageStatus.planned,
    owner: '#1884',
  ),
  RouteCoverage('/settings/sites', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage(
    '/money/status',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage(
    '/money/repartition-wizard',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage('/settings/wording', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/settings/colours', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage(
    '/settings/roles-of-this-space',
    CoverageStatus.planned,
    owner: '#1884',
  ),
  RouteCoverage(
    '/settings/what-you-can-do',
    CoverageStatus.planned,
    owner: '#1884',
  ),
  RouteCoverage('/settings/questions', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/attention', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage(
    '/settings/number-sequences',
    CoverageStatus.planned,
    owner: '#1884',
  ),
  RouteCoverage('/members/managed', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage(
    '/payment-methods',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage(
    '/legal-identity',
    CoverageStatus.excluded,
    category: ProtectedSurface.identity,
  ),
  RouteCoverage(
    '/deployment',
    CoverageStatus.excluded,
    category: ProtectedSurface.secrets,
  ),
  RouteCoverage(
    '/vat-declarations',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage(
    '/vat',
    CoverageStatus.excluded,
    category: ProtectedSurface.payment,
  ),
  RouteCoverage('/services', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/accessories', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/features', CoverageStatus.recorded),
  RouteCoverage('/workspace-settings', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/validation', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/availability', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/bi', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/members', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage('/editor', CoverageStatus.planned, owner: '#1884'),
  RouteCoverage(
    '/editor/level/:levelId',
    CoverageStatus.planned,
    owner: '#1884',
  ),
];
