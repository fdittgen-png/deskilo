// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1865 — what a recording says when the person navigates to a screen.
//
// Three answers, decided from the route PATH alone (never its query, its
// ids or anything on the screen):
//   * an instrumented surface: say nothing here, its own seams speak;
//   * a protected surface: one "excluded step" marker with its category,
//     and nothing of its contents, ever;
//   * anything else: a visible "the recorder cannot describe this" step,
//     so an uninstrumented screen never passes for covered.

import '../domain/action_registry.dart';

/// How the recorder treats a route.
sealed class RouteTreatment {
  const RouteTreatment();
}

/// Recorded by the screen's own seams, or the recorder itself.
final class Instrumented extends RouteTreatment {
  const Instrumented();
}

/// Contents never recorded; one marker of [category].
final class Protected extends RouteTreatment {
  const Protected(this.category);
  final ProtectedSurface category;
}

/// Not instrumented: a visible manual step.
final class Unrecorded extends RouteTreatment {
  const Unrecorded();
}

/// The recorder's own screen.
const String taskRecorderRoute = '/task-recorder';

const _instrumented = ['/reserve', '/plan', '/res/', taskRecorderRoute];

const Map<String, ProtectedSurface> _protected = {
  '/auth': ProtectedSurface.authentication,
  '/linked-accounts': ProtectedSurface.authentication,
  '/oauth/consent': ProtectedSurface.authentication,
  '/consent': ProtectedSurface.authentication,
  '/scan-join': ProtectedSurface.authentication,
  '/kiosk-gate': ProtectedSurface.authentication,
  '/kiosk': ProtectedSurface.authentication,
  '/money': ProtectedSurface.payment,
  '/billing': ProtectedSurface.payment,
  '/invoices': ProtectedSurface.payment,
  '/invoice-register': ProtectedSurface.payment,
  '/invoicing/': ProtectedSurface.payment,
  '/payment-config': ProtectedSurface.payment,
  '/payment-methods': ProtectedSurface.payment,
  '/einvoice-config': ProtectedSurface.payment,
  '/vat': ProtectedSurface.payment,
  '/messages': ProtectedSurface.messenger,
  '/conversation/': ProtectedSurface.messenger,
  '/account-messages': ProtectedSurface.messenger,
  '/assistants': ProtectedSurface.provider,
  '/settings/assistants': ProtectedSurface.provider,
  '/settings/assistant-setup': ProtectedSurface.provider,
  '/database/assistant-approvals': ProtectedSurface.provider,
  '/mcp/': ProtectedSurface.provider,
  '/connections': ProtectedSurface.provider,
  '/applications': ProtectedSurface.provider,
  '/server': ProtectedSurface.secrets,
  '/developer': ProtectedSurface.secrets,
  '/nfc-config': ProtectedSurface.secrets,
  '/deployment': ProtectedSurface.secrets,
  '/installation/': ProtectedSurface.operator,
  '/settings/personal-info': ProtectedSurface.identity,
  '/privacy': ProtectedSurface.identity,
  '/me': ProtectedSurface.identity,
  '/legal-identity': ProtectedSurface.identity,
  '/member/': ProtectedSurface.identity,
  '/members': ProtectedSurface.identity,
  '/profiles': ProtectedSurface.identity,
  '/directory': ProtectedSurface.identity,
};

bool _matches(String path, String prefix) => prefix.endsWith('/')
    ? path.startsWith(prefix)
    : path == prefix || path.startsWith('$prefix/');

/// How the recorder treats the route at [path]. The longest matching
/// prefix decides, so `/settings/assistants` is a provider's screen even
/// though `/settings` alone is not protected.
RouteTreatment treatRoute(String path) {
  if (_instrumented.any((p) => _matches(path, p))) return const Instrumented();
  String? best;
  for (final prefix in _protected.keys) {
    if (_matches(path, prefix) &&
        (best == null || prefix.length > best.length)) {
      best = prefix;
    }
  }
  if (best != null) return Protected(_protected[best]!);
  return const Unrecorded();
}
