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
import '../features/workspace/domain/workspace_permission.dart';

typedef _P = WorkspacePermission;

/// Route pattern → the permissions of which holding ANY opens it.
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
  '/money/status': {_P.viewMyMoney, _P.viewFinances, _P.issueInvoices, _P.manageBilling},
  '/invoices': {_P.viewMyMoney, _P.viewFinances, _P.issueInvoices},
  '/invoice-register': {_P.viewMyMoney, _P.viewFinances, _P.issueInvoices},
  '/documents': {_P.viewDocuments, _P.manageDocuments},
  '/library': {_P.viewDocuments, _P.manageDocuments},
  '/developer': {_P.manageConfiguration, _P.deployToDev, _P.deployToProd},
  '/deployment': {_P.manageConfiguration, _P.deployToDev, _P.deployToProd},
  '/workspace-code': {_P.manageConfiguration, _P.manageMembers},
  '/features': {_P.manageConfiguration},
  '/workspace-settings': {_P.workspaceSettings},
  '/availability': {_P.workspaceSettings},
  '/settings/wording': {_P.workspaceSettings},
  '/settings/colours': {_P.workspaceSettings},
  '/settings/questions': {_P.workspaceSettings},
  '/settings/public-page': {_P.workspaceSettings},
  '/legal-identity': {_P.workspaceSettings},
  '/settings/sites': {_P.manageSites},
  '/editor': {_P.manageSites},
  '/editor/level/:levelId': {_P.manageSites},
  '/roles': {_P.manageRoles},
  '/settings/roles-of-this-space': {_P.manageRoles},
  '/members': {_P.manageMembers},
  '/members/managed': {_P.manageMembers},
  '/validation': {_P.manageValidation},
  '/invoicing/wizard': {_P.issueInvoices},
  '/money/repartition-wizard': {_P.issueInvoices, _P.manageBilling},
  '/report-editor': {_P.designDocuments, _P.manageDocuments},
  '/billing': {_P.manageBilling},
  '/settings/number-sequences': {_P.manageBilling},
  '/vat': {_P.manageBilling},
  '/vat-declarations': {_P.manageBilling, _P.viewFinances},
  '/services': {_P.manageServices},
  '/accessories': {_P.manageServices},
  '/payment-methods': {_P.manageIntegrations},
  '/payment-config': {_P.manageIntegrations},
  '/einvoice-config': {_P.manageIntegrations},
  '/settings/assistants': {_P.manageIntegrations},
  '/settings/assistant-setup': {_P.manageIntegrations},
  '/nfc-config': {_P.operateKiosk},
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
Set<WorkspacePermission>? permissionsFor(String path) {
  for (final entry in routePermissions.entries) {
    if (_matches(entry.key, path)) return entry.value;
  }
  return null;
}

/// Whether someone holding [held] may open [path].
bool mayOpen(String path, Set<WorkspacePermission> held) {
  final needed = permissionsFor(path);
  return needed == null || needed.any(held.contains);
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
