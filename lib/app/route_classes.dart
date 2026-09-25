// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — every route the router registers, classified once by what it
// needs before it may open. The policy (route_policy.dart, next
// checkpoint) decides from the class; this file is the table, kept in
// step with router.dart by test/lint/route_policy_registry_test.dart in
// both directions: a route without a class is refused by the policy, a
// class without a route is a boundary kept alive for nothing.
import 'schema_gate.dart';

/// What a route needs before it may open.
enum RouteClass {
  /// Sign-in, help, privacy, the server chooser and the schema notice:
  /// reachable signed out and before consent. The server screen shows a
  /// non-secret endpoint and its diagnostics; it authorises nothing.
  publicEntry,

  /// The account's own pages: a session and consent, no workspace. They
  /// work with zero workspaces and while the selected workspace is
  /// pending — that is what they are for.
  nativeAccount,

  /// Instance provisioning: its own credentials, asked for in its own
  /// flow. Not behind a workspace flag when there is no workspace.
  operator,

  /// Everything inside a workspace: a membership that is not pending.
  /// The route's own guard then asks its permission and its feature.
  workspace,

  /// Not registered. Refused to the safe home, never rendered.
  unknown,
}

/// One registered route pattern and its class. `:name` matches a segment.
class RouteRule {
  const RouteRule(this.pattern, this.kind);
  final String pattern;
  final RouteClass kind;

  bool matches(String path) {
    final want = pattern.split('/');
    final have = path.split('/');
    if (want.length != have.length) return false;
    for (var i = 0; i < want.length; i++) {
      if (want[i].startsWith(':')) {
        if (have[i].isEmpty) return false;
      } else if (want[i] != have[i]) {
        return false;
      }
    }
    return true;
  }
}

/// Where the app opens when nothing more specific was asked for.
const String kDefaultHome = '/reserve';

/// Every route the router registers, classified. The lint in
/// test/lint/route_policy_registry_test.dart keeps this list and
/// router.dart in step both ways.
const List<RouteRule> routeRules = [
  RouteRule('/auth', RouteClass.publicEntry),
  RouteRule('/help', RouteClass.publicEntry),
  RouteRule('/privacy', RouteClass.publicEntry),
  RouteRule('/server', RouteClass.publicEntry),
  RouteRule(kSchemaUpdateRoute, RouteClass.publicEntry),
  RouteRule('/server/new-instance', RouteClass.operator),
  RouteRule('/consent', RouteClass.nativeAccount),
  RouteRule('/profiles', RouteClass.nativeAccount),
  RouteRule('/linked-accounts', RouteClass.nativeAccount),
  RouteRule('/onboarding', RouteClass.nativeAccount),
  RouteRule('/scan-join', RouteClass.nativeAccount),
  RouteRule('/kiosk-gate', RouteClass.workspace),
  RouteRule('/kiosk', RouteClass.workspace),
  RouteRule('/pending', RouteClass.workspace),
  RouteRule('/messages', RouteClass.workspace),
  RouteRule('/calendar', RouteClass.workspace),
  RouteRule('/directory', RouteClass.workspace),
  RouteRule('/money', RouteClass.workspace),
  RouteRule('/reserve', RouteClass.workspace),
  RouteRule('/settings', RouteClass.workspace),
  RouteRule('/developer', RouteClass.workspace),
  RouteRule('/formats', RouteClass.workspace),
  RouteRule('/events', RouteClass.workspace),
  RouteRule('/plan', RouteClass.workspace),
  RouteRule('/conversation/:conversationId', RouteClass.workspace),
  RouteRule('/res/:id', RouteClass.workspace),
  RouteRule('/space/:kind/:id', RouteClass.workspace),
  RouteRule('/library', RouteClass.workspace),
  RouteRule('/workspace-code', RouteClass.workspace),
  RouteRule('/nfc-config', RouteClass.workspace),
  RouteRule('/payment-config', RouteClass.workspace),
  RouteRule('/billing', RouteClass.workspace),
  RouteRule('/invoices', RouteClass.workspace),
  RouteRule('/invoice-register', RouteClass.workspace),
  RouteRule('/einvoice-config', RouteClass.workspace),
  RouteRule('/documents', RouteClass.workspace),
  RouteRule('/invoicing/wizard', RouteClass.workspace),
  RouteRule('/member/:memberId', RouteClass.workspace),
  RouteRule('/report-editor', RouteClass.workspace),
  RouteRule('/roles', RouteClass.workspace),
  RouteRule('/settings/personal-info', RouteClass.workspace),
  RouteRule('/settings/payment-terms', RouteClass.workspace),
  RouteRule('/settings/sites', RouteClass.workspace),
  RouteRule('/money/status', RouteClass.workspace),
  RouteRule('/money/repartition-wizard', RouteClass.workspace),
  RouteRule('/settings/wording', RouteClass.workspace),
  RouteRule('/settings/colours', RouteClass.workspace),
  RouteRule('/settings/roles-of-this-space', RouteClass.workspace),
  RouteRule('/settings/questions', RouteClass.workspace),
  RouteRule('/attention', RouteClass.workspace),
  RouteRule('/settings/number-sequences', RouteClass.workspace),
  RouteRule('/members/managed', RouteClass.workspace),
  RouteRule('/payment-methods', RouteClass.workspace),
  RouteRule('/legal-identity', RouteClass.workspace),
  RouteRule('/deployment', RouteClass.workspace),
  RouteRule('/vat-declarations', RouteClass.workspace),
  RouteRule('/vat', RouteClass.workspace),
  RouteRule('/services', RouteClass.workspace),
  RouteRule('/accessories', RouteClass.workspace),
  RouteRule('/features', RouteClass.workspace),
  RouteRule('/workspace-settings', RouteClass.workspace),
  RouteRule('/validation', RouteClass.workspace),
  RouteRule('/availability', RouteClass.workspace),
  RouteRule('/members', RouteClass.workspace),
  RouteRule('/editor', RouteClass.workspace),
  RouteRule('/editor/level/:levelId', RouteClass.workspace),
];

/// The rule [path] (no query) matches, or null when none does.
RouteRule? matchRoute(String path) {
  for (final rule in routeRules) {
    if (rule.matches(path)) return rule;
  }
  return null;
}

/// The class of [path] (no query), or [RouteClass.unknown].
RouteClass classifyRoute(String path) =>
    matchRoute(path)?.kind ?? RouteClass.unknown;
