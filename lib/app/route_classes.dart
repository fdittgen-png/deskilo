// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1650 — every route the router registers, classified once by what it
// needs before it may open. The policy (route_policy.dart, next
// checkpoint) decides from the class; this file is the table, kept in
// step with router.dart by test/lint/route_policy_registry_test.dart in
// both directions: a route without a class is refused by the policy, a
// class without a route is a boundary kept alive for nothing.
import 'package:meta/meta.dart';
import '../core/ui/adaptive/page_measures.dart';
import 'schema_gate.dart';
import 'shell/shell_branch.dart';

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

/// #3603 — what a route is SHOWN in, apart from what it needs to open
/// ([RouteClass]): the desk (the business's navigation beside the page from
/// the expanded window class), the kiosk (the one pinned screen: no
/// navigation, search or shortcuts), the account's own pages, or a public
/// page.
enum RouteChrome { desk, kiosk, account, public }

/// One registered route pattern and its class. `:name` matches a segment.
class RouteRule {
  const RouteRule(
    this.pattern,
    this.kind, {
    this._chrome,
    this.place,
    this.measure = PageMeasure.framed,
  });
  final String pattern;
  final RouteClass kind;
  final RouteChrome? _chrome;

  /// #3603 — where this page sits in the business's navigation: the key of
  /// the entry it is reached from today (`drawer-…`; a tab is
  /// `drawer-tab-${ShellBranch.x}`, never a digit), or the id of a group whose
  /// entries select themselves (`reporting`). The desk selects that entry
  /// and names it in the breadcrumb and the window title; every desk route
  /// declares one (test/lint/desk_places_test.dart).
  final String? place;

  /// #3604 — the measure the page is drawn in, applied by the frame
  /// (page_frame.dart): today's frame unless the route declares its own.
  /// The route table is the only place a page's measure is declared.
  final PageMeasure measure;

  /// The chrome this route is shown in: declared where it differs from
  /// what its class implies (the kiosk's routes), else derived from it.
  RouteChrome get chrome =>
      _chrome ??
      switch (kind) {
        RouteClass.workspace => RouteChrome.desk,
        RouteClass.nativeAccount || RouteClass.operator => RouteChrome.account,
        RouteClass.publicEntry || RouteClass.unknown => RouteChrome.public,
      };

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

/// #1823 — the person's own home, the Me layer: where the app opens when
/// there is no space of THIS person's to return to, and where "Back to
/// Me" leads. It needs a session and nothing else.
const String kMeHome = '/me';

/// Every route the router registers, classified. The lint in
/// test/lint/route_policy_registry_test.dart keeps this list and
/// router.dart in step both ways.
@visibleForTesting
const List<RouteRule> routeRules = [
  RouteRule(kMeHome, RouteClass.nativeAccount),
  // #2552 — the personal shell's branches and the pages inside them: the
  // account's own, like `/me`. (`/me/messages/new` and `:ref` sit after the
  // messenger's named pages below, which must match first.)
  RouteRule('/me/spaces', RouteClass.nativeAccount),
  RouteRule('/me/spaces/manage', RouteClass.nativeAccount),
  RouteRule('/me/discover', RouteClass.nativeAccount),
  RouteRule('/me/messages', RouteClass.nativeAccount),
  RouteRule('/me/data', RouteClass.nativeAccount),
  RouteRule('/me/formats', RouteClass.nativeAccount),
  RouteRule('/me/account', RouteClass.nativeAccount),
  RouteRule('/me/account/connections', RouteClass.nativeAccount),
  RouteRule('/discover', RouteClass.publicEntry),
  // #2211 — a published public profile, readable signed in or not.
  RouteRule('/p/:id', RouteClass.publicEntry),
  RouteRule('/connections', RouteClass.nativeAccount),
  RouteRule('/account-messages', RouteClass.nativeAccount),
  RouteRule('/settings/public-page', RouteClass.workspace, place: 'drawer-setup-guide'),
  RouteRule('/auth', RouteClass.publicEntry),
  // #3235 — the demo entry: public, for a signed-in person too.
  RouteRule('/demo', RouteClass.publicEntry),
  RouteRule('/help', RouteClass.publicEntry),
  RouteRule('/privacy', RouteClass.publicEntry),
  RouteRule('/server', RouteClass.publicEntry),
  RouteRule(kSchemaUpdateRoute, RouteClass.publicEntry),
  RouteRule('/server/new-instance', RouteClass.operator),
  RouteRule('/consent', RouteClass.nativeAccount),
  RouteRule('/profiles', RouteClass.nativeAccount),
  RouteRule('/applications', RouteClass.nativeAccount),
  // #1865 — the account's own recordings on this device.
  RouteRule('/task-recorder', RouteClass.nativeAccount),
  RouteRule('/task-wizard', RouteClass.nativeAccount),
  // #1872 — reads a file the person picks, on this device; no session.
  RouteRule('/task-workbench', RouteClass.publicEntry),
  RouteRule('/account-activity', RouteClass.nativeAccount),
  RouteRule('/linked-accounts', RouteClass.nativeAccount),
  // The person's own settings (sign-out, status line) and this
  // device's local diagnostics: no workspace decides them, so they open
  // with zero workspaces and while a membership is pending. The workspace
  // sections inside Settings keep their own permissions and flags.
  RouteRule(
    '/settings',
    RouteClass.nativeAccount,
    chrome: RouteChrome.desk,
    place: 'drawer-settings',
  ),
  RouteRule(
    '/developer',
    RouteClass.nativeAccount,
    chrome: RouteChrome.desk,
    place: 'drawer-settings',
  ),
  // #2388 — pages opened over another screen (they were Navigator pushes
  // with no path): each has the class of the screen it is opened from.
  RouteRule('/discover/workspace', RouteClass.publicEntry),
  RouteRule('/account-messages/thread', RouteClass.nativeAccount),
  RouteRule('/me/messages/thread', RouteClass.nativeAccount),
  RouteRule('/me/messages/inquiries', RouteClass.nativeAccount),
  RouteRule('/me/messages/starred', RouteClass.nativeAccount),
  RouteRule('/me/messages/new-group', RouteClass.nativeAccount),
  RouteRule('/me/messages/new', RouteClass.nativeAccount),
  RouteRule('/me/messages/:ref', RouteClass.nativeAccount),
  RouteRule('/templates/compare', RouteClass.nativeAccount),
  RouteRule('/templates/detail', RouteClass.nativeAccount),
  RouteRule('/task-recorder/guide', RouteClass.nativeAccount),
  RouteRule('/task-recorder/recording', RouteClass.nativeAccount),
  RouteRule('/task-workbench/storyboard', RouteClass.publicEntry),
  RouteRule('/money/repartition', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.money}'),
  RouteRule('/money/settlement', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.money}'),
  RouteRule('/account-activity/history', RouteClass.nativeAccount),
  RouteRule('/help/support-bundle', RouteClass.publicEntry),
  RouteRule('/server/new-instance/first-start', RouteClass.operator),
  RouteRule('/onboarding', RouteClass.nativeAccount),
  RouteRule('/scan-join', RouteClass.nativeAccount),
  RouteRule('/mcp/confirm/:id', RouteClass.nativeAccount),
  RouteRule('/oauth/consent', RouteClass.nativeAccount),
  RouteRule('/assistants', RouteClass.nativeAccount),
  RouteRule('/assistants/connect', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/database/assistant-approvals', RouteClass.nativeAccount),
  RouteRule('/installation/assistants', RouteClass.nativeAccount),
  RouteRule('/settings/assistants', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/settings/assistant-setup', RouteClass.workspace, place: 'drawer-settings'),
  // #3603 — workspace routes for authorization, the kiosk's own chrome.
  RouteRule('/kiosk-gate', RouteClass.workspace, chrome: RouteChrome.kiosk),
  RouteRule('/kiosk', RouteClass.workspace, chrome: RouteChrome.kiosk),
  // A membership still pending reaches no destination: no desk.
  RouteRule('/pending', RouteClass.workspace, chrome: RouteChrome.account),
  RouteRule('/messages', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.messages}'),
  RouteRule('/calendar', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.calendar}'),
  RouteRule('/directory', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.directory}'),
  RouteRule('/money', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.money}'),
  RouteRule('/reserve', RouteClass.workspace, place: 'drawer-reserve'),
  RouteRule('/formats', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/events', RouteClass.workspace, place: 'drawer-events'),
  RouteRule('/plan', RouteClass.workspace, place: 'drawer-reserve'),
  RouteRule('/conversation/:conversationId', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.messages}'),
  RouteRule('/res/:id', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.calendar}'),
  RouteRule('/space/:kind/:id', RouteClass.workspace, place: 'drawer-reserve'),
  RouteRule('/library', RouteClass.workspace, place: 'drawer-setup-guide'),
  RouteRule('/workspace-code', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/nfc-config', RouteClass.workspace, place: 'drawer-nfc-config'),
  RouteRule('/badge-kiosks', RouteClass.workspace, place: 'drawer-nfc-config', measure: PageMeasure.form),
  RouteRule('/payment-config', RouteClass.workspace, place: 'drawer-payment-config'),
  RouteRule('/billing', RouteClass.workspace, place: 'drawer-billing', measure: PageMeasure.form), // #3614: a settings form
  RouteRule(
    '/invoices',
    RouteClass.workspace,
    place: 'drawer-invoices',
    measure: PageMeasure.work,
  ),
  // #3607 — an open invoice beside the list (or its page).
  // #3614 — an open customer beside the list (or their page).
  RouteRule(
    '/invoices/customer/:id',
    RouteClass.workspace,
    place: 'drawer-invoices',
    measure: PageMeasure.work,
  ),
  RouteRule(
    '/invoices/:id',
    RouteClass.workspace,
    place: 'drawer-invoices',
    measure: PageMeasure.work,
  ),
  RouteRule(
    '/invoice-register',
    RouteClass.workspace,
    place: 'drawer-accounting-export',
    // #3606 — a records table: the whole work area.
    measure: PageMeasure.work,
  ),
  RouteRule('/einvoice-config', RouteClass.workspace, place: 'drawer-legal-identity'),
  RouteRule('/documents', RouteClass.workspace, place: 'drawer-documents'),
  RouteRule('/invoicing/wizard', RouteClass.workspace, place: 'drawer-invoices'),
  RouteRule('/member/:memberId', RouteClass.workspace, place: 'drawer-members'),
  RouteRule('/report-editor', RouteClass.workspace, place: 'drawer-reports-templates'),
  RouteRule('/roles', RouteClass.workspace, place: 'drawer-roles'),
  RouteRule('/settings/personal-info', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/settings/payment-terms', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/settings/sites', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/money/status', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.money}'),
  RouteRule('/money/purchases', RouteClass.workspace, place: 'drawer-purchases'),
  RouteRule('/money/guest-passes', RouteClass.workspace, place: 'drawer-guest-passes', measure: PageMeasure.work), // #3614
  RouteRule('/money/purchases/approvals', RouteClass.workspace, place: 'drawer-purchase-approvals'),
  RouteRule('/money/payments', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.money}', measure: PageMeasure.work), // #3614
  RouteRule('/money/suppliers', RouteClass.workspace, place: 'drawer-suppliers'),
  RouteRule('/money/purchase-orders', RouteClass.workspace, place: 'drawer-purchase-orders'),
  // #3608 — the order's form, a long task: a page with its own columns.
  RouteRule('/money/purchase-orders/new', RouteClass.workspace, place: 'drawer-purchase-orders', measure: PageMeasure.work),
  RouteRule('/money/purchase-orders/:id/edit', RouteClass.workspace, place: 'drawer-purchase-orders', measure: PageMeasure.work),
  RouteRule('/suppliers', RouteClass.workspace, place: 'drawer-suppliers'),
  RouteRule('/money/sales', RouteClass.workspace, place: 'drawer-invoices'),
  RouteRule('/money/cash', RouteClass.workspace, place: 'drawer-cash'),
  RouteRule('/money/accounting', RouteClass.workspace, place: 'drawer-accounting', measure: PageMeasure.work), // #3616: a dashboard
  RouteRule('/money/accounting/exports', RouteClass.workspace, place: 'drawer-accounting', measure: PageMeasure.work), // #3616
  RouteRule('/money/repartition-wizard', RouteClass.workspace, place: 'drawer-tab-${ShellBranch.money}'),
  RouteRule('/settings/wording', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/settings/colours', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/settings/roles-of-this-space', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/settings/what-you-can-do', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/settings/questions', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/attention', RouteClass.workspace, place: 'drawer-events'),
  RouteRule('/reservations/period', RouteClass.workspace, place: 'drawer-bi'),
  RouteRule(
    '/workspace-overview',
    RouteClass.workspace,
    place: 'drawer-nav-overview',
    measure: PageMeasure.work,
  ),
  RouteRule('/setup', RouteClass.workspace, place: 'drawer-setup-guide'),
  RouteRule('/setup/levels', RouteClass.workspace, place: 'drawer-setup-guide'),
  RouteRule('/setup/launch', RouteClass.workspace, place: 'drawer-setup-guide'),
  RouteRule('/setup/step/:id', RouteClass.workspace, place: 'drawer-setup-guide'),
  RouteRule('/settings/number-sequences', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/members/managed', RouteClass.workspace, place: 'drawer-members'),
  RouteRule('/members/privacy', RouteClass.workspace, place: 'drawer-members'),
  RouteRule('/payment-methods', RouteClass.workspace, place: 'drawer-payment-methods'),
  RouteRule('/legal-identity', RouteClass.workspace, place: 'drawer-legal-identity'),
  RouteRule('/deployment', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/vat-declarations', RouteClass.workspace, place: 'drawer-vat-declarations'),
  RouteRule('/vat-declarations/:id', RouteClass.workspace, place: 'drawer-vat-declarations', measure: PageMeasure.work), // #3616: a long task
  RouteRule('/vat', RouteClass.workspace, place: 'drawer-vat'),
  RouteRule('/services', RouteClass.workspace, place: 'drawer-services', measure: PageMeasure.work), // #3614
  RouteRule('/accessories', RouteClass.workspace, place: 'drawer-accessories'),
  RouteRule('/features', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/workspace-settings', RouteClass.workspace, place: 'drawer-setup-guide'),
  RouteRule('/reports', RouteClass.workspace, place: 'reporting'),
  RouteRule('/validation', RouteClass.workspace, place: 'drawer-settings'),
  RouteRule('/availability', RouteClass.workspace, place: 'drawer-availability'),
  RouteRule(
    '/bi',
    RouteClass.workspace,
    place: 'drawer-bi',
    measure: PageMeasure.work,
  ), // #1923
  RouteRule('/bi/report/:id', RouteClass.workspace, place: 'drawer-bi'), // #2580
  RouteRule('/members', RouteClass.workspace, place: 'drawer-members'),
  RouteRule('/editor', RouteClass.workspace, place: 'drawer-setup-guide'),
  RouteRule('/editor/level/:levelId', RouteClass.workspace, place: 'drawer-setup-guide'),
];

/// Account routes whose content is the workspace's own sections: they open
/// outside any workspace (policy: nativeAccount) but render inside the
/// workspace chrome, strip included, whenever a workspace is selected.
const Set<String> workspaceChromeAccountRoutes = {'/settings', '/developer'};

/// The rule [path] (no query) matches, or null when none does.
RouteRule? matchRoute(String path) {
  for (final rule in routeRules) {
    if (rule.matches(path)) return rule;
  }
  return null;
}

/// The chrome [path] (no query) is shown in; an unknown path is public.
RouteChrome chromeOf(String path) =>
    matchRoute(path)?.chrome ?? RouteChrome.public;

/// #3603 — the place [path] (no query) declares, or null.
String? placeOf(String path) => matchRoute(path)?.place;

/// #3604 — the measure [path] (no query) is drawn in.
PageMeasure measureOf(String path) =>
    matchRoute(path)?.measure ?? PageMeasure.framed;

/// The class of [path] (no query), or [RouteClass.unknown].
RouteClass classifyRoute(String path) =>
    matchRoute(path)?.kind ?? RouteClass.unknown;

/// Whether [path] is the person's own layer rather than a space's: every
/// registered route that needs no membership, except the account routes
/// that render a space's own sections. It decides the chrome (Me's colours
/// or the space's) and the format (the person's or the business's).
bool isPersonalLayer(String path) => switch (classifyRoute(path)) {
      RouteClass.nativeAccount => !workspaceChromeAccountRoutes.contains(path),
      RouteClass.publicEntry || RouteClass.operator => true,
      RouteClass.workspace || RouteClass.unknown => false,
    };
