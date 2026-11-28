// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Who may open which workspace screen — one table, one door.
//
// Everyone in a workspace is a member: they book, check in, message and
// keep their own account. Everything beyond that is held through a
// permission (the role matrix, or a role the workspace defined), and a
// screen that is not in this table is the member's own. A route listed
// here opens only for someone who HOLDS one of its permissions; holding
// none of them is a refusal, whatever the person's title and whether or
// not the menu offered the way there. Deep links, stored shortcuts and
// notification taps all arrive through the router, so this is the one
// place that cannot be walked around. (The server asks the same
// permissions again for everything these screens write.) Even the
// everyday features — the messenger, the reservations, the calendar, the
// directory, one's own account, the shared documents — are listed: a
// member holds them only through a role, and never by default.
import 'package:meta/meta.dart';
import '../features/workspace/domain/workspace_feature.dart';
import '../features/workspace/domain/workspace_permission.dart';

typedef _P = WorkspacePermission;

/// Route pattern → the permissions of which holding ANY opens it.
@visibleForTesting
const Map<String, Set<WorkspacePermission>> routePermissions = {
  // The everyday features: held through a role like everything else.
  '/messages': {_P.useMessages},
  '/events': {_P.useMessages},
  '/conversation/:conversationId': {_P.useMessages},
  '/res/:id': {_P.useMessages, _P.makeReservations},
  '/space/:kind/:id': {_P.useMessages, _P.makeReservations},
  '/reserve': {_P.makeReservations},
  '/plan': {_P.makeReservations},
  '/calendar': {_P.viewCalendar},
  '/directory': {_P.viewDirectory},
  '/money': {_P.viewMyMoney, _P.viewFinances, _P.issueInvoices, _P.manageBilling},
  // #3627 — what the server's workspace_status asks (MoneyToolRights.status).
  '/money/status': {_P.viewFinances},
  '/money/purchases': {_P.viewMyMoney, _P.viewFinances, _P.managePurchases},
  '/money/purchases/doc/:id': {_P.viewMyMoney, _P.viewFinances, _P.managePurchases},
  '/money/purchases/approvals': {_P.approveExpenses},
  '/money/payments': {_P.viewFinances},
  '/money/suppliers': {_P.viewFinances, _P.manageBilling, _P.managePurchases},
  // #4164 — the list reads under the rights that read the customers' money; the
  // editor's own door needs manageBillingCustomers.
  // #4161 — the stock records and one movement: who sees or moves the stock.
  '/stock': {_P.viewStock, _P.manageStock},
  '/stock/movements': {_P.viewStock, _P.manageStock},
  '/stock/movements/:id': {_P.viewStock, _P.manageStock},
  // #4434 — where an item is: read like the stock, and the server asks the same.
  '/stock/where/:itemId': {_P.viewStock, _P.manageStock},
  // #4170 — the goods on their way and the commands that move goods: seen with the stock, run with manageStock.
  '/stock/transfers': {_P.viewStock, _P.manageStock},
  // #4172 — the counts: seen by who sees the stock or approves, counted with manageStock, applied with the approval right.
  '/stock/counts': {_P.viewStock, _P.manageStock, _P.approveStockAdjustments},
  // #4294 — what is low and what to order: seen by who sees the stock or buys; the draft order itself
  // needs managePurchases, which the screen and the server ask.
  '/stock/reorder': {_P.viewStock, _P.manageStock, _P.managePurchases},
  // #4173 — what the goods on hand cost: who reads the finances or manages the purchases (the server asks the same).
  '/stock/value': {_P.viewFinances, _P.managePurchases},
  // #4295 — who counts (the right countStock implies nothing else) or manages the stock.
  '/stock/cycle-counts': {_P.countStock, _P.manageStock},
  '/stock/cycle-counts/:taskId': {_P.countStock, _P.manageStock},
  // #4431 — the expiry report reads like the stock (the server asks the same: it is the stock's own read).
  '/stock/expiry': {_P.viewStock, _P.manageStock},
  '/stock/units': {_P.viewStock, _P.manageStock},
  // #4361 — the item groups read like the stock; changing one is for who manages it (the server asks the same).
  '/stock/groups': {_P.viewStock, _P.manageStock},
  // #4299 — the item registry and the places read like the stock; its settings
  // are for who manages the stock or the configuration.
  '/stock/items': {_P.viewStock, _P.manageStock},
  '/stock/items/:itemId': {_P.viewStock, _P.manageStock},
  '/stock/places': {_P.viewStock, _P.manageStock},
  '/stock/settings': {_P.manageStock, _P.manageConfiguration},
  '/money/customers': {_P.manageBillingCustomers, _P.issueInvoices, _P.viewFinances},
  // #4166 — the quotes read under the right to issue or the finances; the server decides who acts.
  '/money/quotes': {_P.issueInvoices, _P.viewFinances},
  // #4366 — the till sells at the counter: a member who may issue invoices.
  '/till': {_P.issueInvoices},
  // #4367 — the cash drawer of the till: the counter opens and closes its session; the finances read every one.
  '/till/drawer': {_P.issueInvoices, _P.viewFinances},
  '/till/day': {_P.viewFinances},
  '/till/reasons': {_P.configureTill}, // #4514
  '/till/layout/:tillId': {_P.configureTill}, // #4448
  // #4185 — the counter's receipts: the counter corrects, the finances settle a card answer.
  '/till/receipts': {_P.issueInvoices, _P.viewFinances},
  '/money/quotes/:id': {_P.issueInvoices, _P.viewFinances},
  '/money/quotes/:id/edit': {_P.issueInvoices},
  // #4178 — the engagements read under the right to issue or the finances.
  '/money/engagements': {_P.issueInvoices, _P.viewFinances},
  '/money/engagements/:id': {_P.issueInvoices, _P.viewFinances},
  // #3615 — a supplier's payables: who reads the finances or the purchases.
  '/money/suppliers/:id': {_P.viewFinances, _P.managePurchases},
  '/money/purchase-orders': {_P.viewFinances, _P.managePurchases},
  '/money/purchase-orders/order/:id': {_P.viewFinances, _P.managePurchases},
  '/suppliers': {_P.viewFinances, _P.manageBilling, _P.managePurchases},
  '/money/sales': {_P.viewFinances, _P.issueInvoices, _P.manageBilling},
  '/money/accounting': accountingPageRights,
  '/money/accounting/exports': accountingPageRights,
  '/money/cash': {_P.viewFinances, _P.manageBilling, _P.managePurchases},
  '/money/bank-accounts': {_P.viewFinances, _P.issueInvoices}, // #4496
  '/money/expense-categories': {_P.workspaceSettings}, // #4512
  '/money/supplier-contact-roles': {_P.manageBilling}, // #4518
  '/invoices': {_P.viewMyMoney, _P.viewFinances, _P.issueInvoices},
  '/invoices/:id': {_P.viewMyMoney, _P.viewFinances, _P.issueInvoices},
  // #3614 — a customer's page is for who reads the finances or issues.
  '/invoices/customer/:id': {_P.viewFinances, _P.issueInvoices},
  '/invoice-register': {_P.viewMyMoney, _P.viewFinances, _P.issueInvoices},
  '/documents': {_P.viewDocuments, _P.manageDocuments},
  '/library': {_P.viewDocuments, _P.manageDocuments},
  '/deployment': {_P.manageConfiguration, _P.deployToDev, _P.deployToProd},
  '/workspace-code': {_P.manageConfiguration, _P.manageMembers},
  '/setup': {_P.manageConfiguration},
  '/setup/levels': {_P.manageConfiguration},
  '/setup/launch': {_P.manageConfiguration},
  '/setup/step/:id': {_P.manageConfiguration},
  '/features': {_P.manageConfiguration},
  '/workspace-settings': {_P.workspaceSettings},
  '/availability': {_P.workspaceSettings},
  '/settings/wording': {_P.workspaceSettings},
  '/settings/colours': {_P.workspaceSettings},
  '/settings/questions': {_P.workspaceSettings},
  '/settings/units': {_P.workspaceSettings}, // #4442
  '/settings/devices': {_P.workspaceSettings}, // #4466
  // #4485 — the Master data page: who may open one of its kinds' screens (the
  // page shows each card to whom that screen opens; master_data_test holds
  // this set to the union of theirs).
  '/settings/master-data': {
    _P.workspaceSettings, _P.manageBilling, _P.viewStock, _P.manageStock, _P.manageServices, _P.issueInvoices,
    _P.viewFinances, _P.managePurchases, _P.manageBillingCustomers, _P.manageSites, _P.configureTill,
  },
  '/settings/public-page': {_P.workspaceSettings},
  '/legal-identity': {_P.workspaceSettings},
  '/settings/sites': {_P.manageSites},
  '/editor': {_P.manageSites},
  '/editor/level/:levelId': {_P.manageSites},
  '/roles': {_P.manageRoles},
  '/settings/roles-of-this-space': {_P.manageRoles},
  '/members': {_P.manageMembers},
  '/members/:id': {_P.manageMembers},
  '/members/plans': {_P.manageMembers},
  '/members/plans/:id': {_P.manageMembers},
  '/members/managed': {_P.manageMembers},
  '/members/privacy': {_P.managePrivacy, _P.viewPersonalData},
  '/members/privacy/:id': {_P.managePrivacy, _P.viewPersonalData},
  '/money/guest-passes': {_P.issueInvoices, _P.manageServices},
  '/validation': {_P.manageValidation},
  '/invoicing/wizard': {_P.issueInvoices},
  '/invoicing/standalone/new': {_P.issueInvoices},
  '/money/repartition-wizard': {_P.issueInvoices, _P.manageBilling},
  '/report-editor': {_P.designDocuments, _P.manageDocuments},
  '/billing': {_P.manageBilling},
  '/settings/number-sequences': {_P.manageBilling},
  '/vat': {_P.manageBilling},
  '/vat-declarations': {_P.manageBilling, _P.viewFinances},
  '/vat-declarations/:id': {_P.manageBilling, _P.viewFinances},
  '/services': {_P.manageServices},
  '/accessories': {_P.manageServices},
  '/payment-methods': {_P.manageIntegrations},
  '/payment-config': {_P.manageIntegrations},
  '/einvoice-config': {_P.manageIntegrations},
  '/settings/assistants': {_P.manageIntegrations},
  '/settings/assistant-setup': {_P.manageIntegrations},
  '/nfc-config': {_P.operateKiosk},
  '/badge-kiosks': {_P.operateKiosk},
};

bool _matches(String pattern, String path) {
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

/// The permissions [path] asks for, or null for a screen every member has.
Set<WorkspacePermission>? _permissionsFor(String path) {
  for (final entry in routePermissions.entries) {
    if (_matches(entry.key, path)) return entry.value;
  }
  return null;
}

/// Whether someone holding [held] may open [path].
bool mayOpen(String path, Set<WorkspacePermission> held) {
  final needed = _permissionsFor(path);
  return needed == null || needed.any(held.contains);
}

/// #3926 — where the cash page goes at the desk, where its doors are menu
/// entries: money in and out when the person may open it, else the
/// purchases, else the money page; never a page that refuses them.
String cashDeskLanding(AccessContext access) {
  final held = access.permissions;
  for (final (path, feature) in const [
    ('/money/status', WorkspaceFeature.workspaceStatus),
    ('/money/purchases', WorkspaceFeature.purchases),
  ]) {
    if (access.featureEnabled(feature) && mayOpen(path, held)) return path;
  }
  return '/money';
}

/// Where someone lands when the screen they asked for is not theirs: the
/// first everyday screen they hold, and their own account (which every
/// member has) when they hold none.
String landingFor(Set<WorkspacePermission> held) {
  for (final entry in const [
    ('/messages', _P.useMessages),
    ('/reserve', _P.makeReservations),
    ('/calendar', _P.viewCalendar),
    ('/money', _P.viewMyMoney),
    ('/directory', _P.viewDirectory),
  ]) {
    if (held.contains(entry.$2)) return entry.$1;
  }
  return '/settings';
}

/// What a route's access is asked about: the person and the workspace as
/// they are now. The router answers it from providers (route_env.dart);
/// a test answers it from a record.
abstract interface class AccessContext {
  /// Whether [feature] is enabled for the active workspace (everything is
  /// ON while the workspace is still loading, so a deep link is never
  /// bounced during startup).
  bool featureEnabled(WorkspaceFeature feature);

  /// Every enabled feature, for the few rules that read the whole set.
  Set<WorkspaceFeature> get enabledFeatures;

  /// The permissions the person holds in the active workspace.
  Set<WorkspacePermission> get permissions;

  /// Owner, or a co-owner whose status is active.
  bool get actsAsOwner;

  /// Owner or administrator with an active membership.
  bool get canAdminister;

  /// The membership's administrator flag.
  bool get isAdmin;

  /// Whether the active workspace is one half of a dev/prod pair.
  bool get hasPairedTwin;
}

/// Who may open a route, declared beside the route and evaluated by ONE
/// function ([redirectFor]): every listed feature enabled, the person
/// holding [permission] (or being [bypass]), and [when] true; otherwise
/// the route sends the person to [to].
///
/// This is NAVIGATION policy, not security: it keeps a person from a
/// screen their menu would not offer. The backend (RLS and the RPCs) stays
/// authoritative and asks the same permissions again for everything these
/// screens write.
class RouteAccess {
  const RouteAccess({
    this.features = const [],
    this.permission,
    this.bypass = RoleBypass.none,
    this.when,
    this.to = '/messages',
  });

  /// Every one of these must be enabled.
  final List<WorkspaceFeature> features;

  /// Held by the person. With no permission and no [bypass] anyone passes.
  final WorkspacePermission? permission;

  /// A role that opens the route without holding [permission].
  final RoleBypass bypass;

  /// A further condition no table can state (a twin, a report registry).
  final bool Function(AccessContext)? when;

  /// Where a refused person goes.
  final String to;

  /// The redirect for [context]: null to open, [to] to refuse.
  String? redirectFor(AccessContext context) {
    final allowed =
        features.every(context.featureEnabled) &&
        _personMay(context) &&
        (when?.call(context) ?? true);
    return allowed ? null : to;
  }

  bool _personMay(AccessContext c) {
    if (permission == null && bypass == RoleBypass.none) return true;
    return switch (bypass) {
          RoleBypass.owner => c.actsAsOwner,
          RoleBypass.administrator => c.canAdminister,
          RoleBypass.none => false,
        } ||
        (permission != null && c.permissions.contains(permission));
  }
}

/// A role that passes a [RouteAccess] without the permission.
enum RoleBypass { none, owner, administrator }
