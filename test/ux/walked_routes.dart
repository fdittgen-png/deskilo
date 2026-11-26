// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4077 -- the pages the desk walk renders, as data the route lint reads
// (test/lint/route_walk_coverage_test.dart): the walk of
// test/ux/desk_guard_pages_test.dart runs on these lists and on nothing else,
// so a route is "rendered" exactly when its path is on one of them.
import 'experience_guards.dart';

/// One page of the walk: path, kind, module and screen for a sheet.
typedef DeskWalkPage = (String, PageKind, String, String);

/// The pages the guards run on: path, kind, module and screen for a sheet.
const List<DeskWalkPage> deskWalkPages = [
  // #3946 — Tab walks each of these once, in the order they are built.
  ('/settings/number-sequences', PageKind.task, 'money', 'number-sequences'),
  ('/settings/personal-info', PageKind.task, 'settings', 'personal-info'),
  ('/workspace-overview', PageKind.task, 'settings', 'workspace-overview'),
  ('/availability', PageKind.task, 'settings', 'availability'),
  ('/money/purchase-orders/new', PageKind.task, 'money', 'purchase-order-new'),
  ('/settings/public-page', PageKind.task, 'settings', 'public-page'),
  ('/einvoice-config', PageKind.task, 'money', 'einvoice-config'),
  ('/legal-identity', PageKind.task, 'money', 'legal-identity'),
  ('/payment-methods', PageKind.task, 'money', 'payment-methods'),
  ('/member/member-2', PageKind.task, 'people', 'member'),
  ('/settings/what-you-can-do', PageKind.task, 'settings', 'what-you-can-do'),
  // #3892 — booking and requests at the desk.
  // #3947 — controls named, targets of the kit's size.
  ('/accessories', PageKind.document, 'money', 'accessories'),
  ('/documents', PageKind.document, 'reports', 'documents'),
  ('/money/settlement', PageKind.task, 'money', 'settlement'),
  ('/money/repartition', PageKind.task, 'money', 'repartition'),
  // #3948 — a settings form's text wraps inside the form's measure.
  ('/vat', PageKind.document, 'money', 'vat'),
  ('/settings/sites', PageKind.document, 'settings', 'sites'),
  // #3948 — the invoicing wizard: its words wrap inside the reading measure.
  ('/invoicing/wizard', PageKind.task, 'money', 'invoicing-wizard'),
  // #3949 — a record page opened at its address, with its record.
  ('/invoices/inv-1', PageKind.recordBesideTable, 'money', 'invoice-open'),
  (
    '/invoices/customer/member-1',
    PageKind.recordBesideTable,
    'money',
    'customer-open',
  ),
  ('/members/plans/band-2', PageKind.recordBesideTable, 'members', 'plan-open'),
  ('/editor/level/level-1', PageKind.task, 'places', 'level-canvas'),
  (
    '/reservations/period?from=2026-05&to=2026-05',
    PageKind.document,
    'booking',
    'period-filled',
  ),
  ('/res/res-1', PageKind.document, 'booking', 'reservation-open'),
  ('/space/seat/seat-4', PageKind.document, 'booking', 'space-open'),
  ('/bi/report/view-1', PageKind.dashboard, 'reports', 'report-open'),
  // #3949 — the pages of #3946 and #3947, with both causes on master.
  ('/billing', PageKind.document, 'money', 'billing'),
  ('/settings/wording', PageKind.document, 'settings', 'wording'),
  (
    '/money/purchase-orders/demo-order-1/edit',
    PageKind.task,
    'money',
    'purchase-order-edit',
  ),
  // #3954 — the colours page, walked by Tab once at every size.
  ('/settings/colours', PageKind.document, 'settings', 'colours'),
  // #4057 — Privacy and the task assistant, inside the business's shell.
  ('/business-privacy', PageKind.document, 'settings', 'business-privacy'),
  (
    '/business-task-wizard',
    PageKind.document,
    'settings',
    'business-task-wizard',
  ),
  // #3947 — a conversation with a message: its menu and header are targets
  // of the kit's size.
  ('/conversation/conv-1', PageKind.document, 'people', 'conversation'),
  // #3943 — an empty page passes the keyboard on.
  ('/reservations/period', PageKind.document, 'booking', 'period'),
  // #3892 — settings, people, money and documents at the desk.
  ('/validation', PageKind.task, 'requests', 'validation'),
  ('/assistants/connect', PageKind.task, 'settings', 'assistants-connect'),
  ('/settings/assistants', PageKind.task, 'settings', 'assistants'),
  ('/settings/assistant-setup', PageKind.task, 'settings', 'assistant-setup'),
  ('/kiosk-gate', PageKind.task, 'kiosk', 'kiosk-gate'),
  ('/kiosk', PageKind.task, 'kiosk', 'kiosk'),
  ('/pending', PageKind.document, 'account', 'pending'),
  ('/plan', PageKind.document, 'places', 'plan'),
  ('/badge-kiosks', PageKind.task, 'settings', 'badge-kiosks'),
  ('/accounting/connected', PageKind.document, 'money', 'accounting-connected'),
  ('/suppliers', PageKind.records, 'money', 'suppliers-alias'),
  ('/deployment', PageKind.task, 'settings', 'deployment'),
  ('/editor', PageKind.task, 'places', 'editor'),
  ('/money/repartition-wizard', PageKind.task, 'money', 'repartition-wizard'),
  ('/members/privacy/rr-1', PageKind.recordBesideTable, 'people', 'privacy-open'),
  ('/settings/payment-terms', PageKind.task, 'settings', 'payment-terms'),
  ('/settings/questions', PageKind.task, 'settings', 'questions'),
  ('/settings/roles-of-this-space', PageKind.document, 'settings', 'roles-of-this-space'),
  ('/formats', PageKind.task, 'settings', 'formats'),
  ('/payment-config', PageKind.task, 'settings', 'payment-config'),
  ('/nfc-config', PageKind.task, 'settings', 'nfc-config'),
  ('/workspace-code', PageKind.document, 'settings', 'workspace-code'),
  ('/members/managed', PageKind.task, 'people', 'managed'),
  ('/money/cash', PageKind.document, 'money', 'cash'),
  ('/vat-declarations', PageKind.document, 'money', 'vat-declarations'),
  ('/library', PageKind.document, 'reports', 'library'),
  // #4022 — the guide's own home, beside its steps.
  ('/setup', PageKind.dashboard, 'settings', 'setup'),
  ('/setup/levels', PageKind.task, 'settings', 'setup-levels'),
  ('/attention', PageKind.document, 'booking', 'attention'),
  ('/events', PageKind.document, 'requests', 'events'),
  ('/invoices', PageKind.records, 'money', 'invoices'),
  ('/me', PageKind.dashboard, 'me', 'overview'),
  // #4007 — an organisation's houses side by side.
  ('/organisation/demo-organisation-atelier/overview', PageKind.records, 'organisation', 'overview'),
  // #3606 — the first records table.
  ('/invoice-register', PageKind.records, 'money', 'invoice-register'),
  // #3614 — sales at the desk.
  ('/services', PageKind.records, 'money', 'services'),
  ('/money/guest-passes', PageKind.records, 'money', 'guest-passes'),
  // #3615 — purchases at the desk.
  ('/money/purchases', PageKind.records, 'money', 'purchases'),
  // #3874 — what waits for a decision.
  (
    '/money/purchases/approvals',
    PageKind.records,
    'money',
    'purchase-approvals',
  ),
  ('/money/suppliers', PageKind.records, 'money', 'suppliers'),
  ('/money/customers', PageKind.document, 'money', 'customers'),
  // #4161 — the stock records, and one movement at its address.
  ('/stock', PageKind.document, 'stock', 'stock'),
  // #4299 — the pages of the Stock group.
  ('/stock/movements', PageKind.document, 'stock', 'stock-movements'),
  ('/stock/items', PageKind.document, 'stock', 'stock-items'),
  // #4480 — an item open beside the items list, its sections and their actions.
  ('/stock/items/demo-item-shirt', PageKind.document, 'stock', 'stock-item-open'),
  ('/stock/places', PageKind.document, 'stock', 'stock-places'),
  ('/stock/settings', PageKind.document, 'stock', 'stock-settings'),
  (
    '/stock/movements/demo-stock-movement-1',
    PageKind.document,
    'stock',
    'stock-movement',
  ),
  // #4166 — the quotes: the list, a sent quote and the editor of a draft.
  ('/money/quotes', PageKind.document, 'money', 'quotes'),
  // #4178 — the engagements of the services ordered: the list and one at its address.
  ('/money/engagements', PageKind.document, 'money', 'engagements'),
  ('/money/engagements/engagement-1', PageKind.document, 'money', 'engagement-open'),
  ('/money/quotes/quote-1', PageKind.document, 'money', 'quote-open'),
  ('/money/quotes/quote-2/edit', PageKind.task, 'money', 'quote-edit'),
  // #3842 — the purchase orders as records, and an order beside the table.
  ('/money/purchase-orders', PageKind.records, 'money', 'purchase-orders'),
  (
    '/money/purchase-orders/order/demo-order-1',
    PageKind.recordBesideTable,
    'money',
    'purchase-orders-open',
  ),
  // #3618 — members and plans at the desk, and a member beside the table.
  ('/members', PageKind.records, 'members', 'members'),
  ('/members/plans', PageKind.records, 'members', 'plans'),
  // #3860 — a member open beside the table: name, state and what is open stay.
  ('/members/member-2', PageKind.recordBesideTable, 'members', 'member-open'),
  // #3616 — the books at the desk.
  ('/money/accounting', PageKind.dashboard, 'money', 'accounting'),
  ('/money/accounting/exports', PageKind.records, 'money', 'accounting-exports'),
  // #3627 — the payments received at the desk.
  ('/money/payments', PageKind.records, 'money', 'payments'),
  // #3627 — my money at the desk: the month a dashboard, the faces tables.
  ('/money?face=statement', PageKind.dashboard, 'money', 'money-month'),
  ('/money?face=invoices', PageKind.records, 'money', 'money-invoices'),
  ('/money?face=payments', PageKind.records, 'money', 'money-payments'),
  ('/money?face=usage', PageKind.records, 'money', 'money-usage'),
  ('/vat-declarations/d1', PageKind.task, 'money', 'vat-return'),
  // #3619 — settings and setup at the desk.
  ('/settings', PageKind.task, 'settings', 'account'),
  ('/workspace-settings', PageKind.task, 'settings', 'workspace'),
  ('/features', PageKind.records, 'settings', 'features'),
  ('/setup/step/basics', PageKind.task, 'settings', 'setup-step'),
  // #3629 — the setup guide at the desk: its steps beside a step with a
  // preview, beside a step done on its own screen, and beside Launch.
  ('/setup/step/assistant', PageKind.task, 'settings', 'setup-step-elsewhere'),
  ('/setup/launch', PageKind.task, 'settings', 'setup-launch'),
  // #3860 — a record open beside its table: the table keeps its staying
  // columns, the pane its reading measure, together the work area.
  (
    '/money/suppliers/demo-supplier-1',
    PageKind.recordBesideTable,
    'money',
    'suppliers-open',
  ),
  (
    '/money/purchases/doc/p1',
    PageKind.recordBesideTable,
    'money',
    'purchases-open',
  ),
  // #3617 — reports and analysis at the desk.
  ('/reports', PageKind.records, 'reports', 'reports'),
  // #3947 — the report editor: its page shrunk beside the preview at 1440.
  ('/report-editor', PageKind.document, 'reports', 'report-editor'),
  ('/money/status', PageKind.dashboard, 'money', 'status'),
  ('/bi', PageKind.dashboard, 'reports', 'analysis'),
  // #3860 — a record open beside its table: the table keeps its staying
  // columns, the pane its reading measure, together the work area.
  (
    '/money/suppliers/demo-supplier-1',
    PageKind.recordBesideTable,
    'money',
    'suppliers-open',
  ),
  (
    '/money/purchases/doc/p1',
    PageKind.recordBesideTable,
    'money',
    'purchases-open',
  ),
  // #3628 — the roles beside the chosen role's permissions.
  ('/roles', PageKind.document, 'people', 'roles'),
  ('/members/privacy', PageKind.records, 'people', 'privacy-requests'),
];

/// #4077 -- the routes the first walk left out, now walked at the desk
/// sizes and, for a member and an administrator, at 1440 and 390 (no sheet:
/// the pictures are those of [deskWalkPages]).
const List<DeskWalkPage> deskWalkMorePages = [
  ('/account-activity', PageKind.task, 'account', 'activity'),
  ('/account-activity/history', PageKind.task, 'account', 'activity-history'),
  ('/account-messages', PageKind.task, 'account', 'account-messages'),
  ('/applications', PageKind.task, 'account', 'applications'),
  ('/assistants', PageKind.task, 'account', 'assistants'),
  ('/connections', PageKind.task, 'account', 'connections'),
  ('/database/assistant-approvals', PageKind.task, 'account', 'approvals'),
  ('/demo', PageKind.task, 'account', 'demo'),
  ('/developer', PageKind.task, 'account', 'developer'),
  ('/discover', PageKind.task, 'account', 'discover'),
  ('/help', PageKind.task, 'account', 'help'),
  ('/help/support-bundle', PageKind.task, 'account', 'support-bundle'),
  ('/installation/assistants', PageKind.task, 'account', 'installation'),
  ('/linked-accounts', PageKind.task, 'account', 'linked-accounts'),
  ('/mcp/confirm/c1', PageKind.task, 'account', 'mcp-confirm'),
  ('/me/formats', PageKind.task, 'account', 'formats'),
  ('/me/messages/new-group', PageKind.task, 'account', 'new-group'),
  ('/me/messages/starred', PageKind.task, 'account', 'starred'),
  ('/oauth/consent', PageKind.task, 'account', 'oauth-consent'),
  ('/p/profile-1', PageKind.task, 'account', 'public-profile'),
  ('/privacy', PageKind.task, 'account', 'privacy'),
  ('/profiles', PageKind.task, 'account', 'profiles'),
  ('/scan-join', PageKind.task, 'account', 'scan-join'),
  ('/server', PageKind.task, 'account', 'server'),
  ('/server/new-instance', PageKind.task, 'account', 'new-instance'),
  ('/task-recorder', PageKind.task, 'account', 'task-recorder'),
  ('/task-wizard', PageKind.task, 'account', 'task-wizard'),
  ('/task-workbench', PageKind.task, 'account', 'task-workbench'),
];

/// Every page the walk renders.
const List<DeskWalkPage> deskWalkAllPages = [
  ...deskWalkPages,
  ...deskWalkMorePages,
];

/// The five tab pages of a phone, walked by test/ux/information_cut_guard_test
/// .dart in each language.
const List<String> phoneTabRoutes = [
  '/messages',
  '/calendar',
  '/directory',
  '/money',
  '/reserve',
];
