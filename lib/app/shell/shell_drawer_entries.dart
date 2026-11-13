// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2493 — what the drawer offers, as data: every destination of the
// navigation, administration, reporting and account groups with the
// permission and feature that earn it. It was 120 lines of
// ShellDrawer.build; the entries, keys and conditions are unchanged.

import 'package:flutter/material.dart';

import '../../core/l10n/context_l10n.dart';
import '../../core/l10n/lexicon.dart';
import '../../core/shortcuts/shortcut_scope.dart';
import '../../features/task_recorder/presentation/route_classification.dart'
    show taskWizardRoute;
import '../../features/workspace/domain/workspace_feature.dart';
import '../../features/workspace/domain/workspace_permission.dart';
import '../../l10n/app_localizations.dart';
import '../route_classes.dart' show placeOf;
import 'shell_destinations.dart';

/// One destination of the drawer.
class DrawerEntry {
  const DrawerEntry(
    this.key,
    this.icon,
    this.label,
    this.onTap, {
    this.selected = false,
    this.route,
  });
  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool selected;
  final String? route;
}

/// Whether [e] is where [path] is. #3603 — a route that declares its place
/// (route_classes.dart) selects that entry alone, so a page opened from a
/// destination keeps it selected; otherwise an entry is current on its own
/// route and below it.
bool entryIsCurrent(DrawerEntry e, String path) {
  if (e.selected) return true;
  final place = placeOf(path);
  if (place != null) return e.key == place;
  final route = e.route;
  return route != null && (path == route || path.startsWith('$route/'));
}

/// Whether the group [id] holding [entries] (and [sub]) is where [path] is:
/// one of its entries is current, or the route names the group itself.
bool groupIsCurrent(
  String id,
  Iterable<DrawerEntry> entries,
  String path,
) => placeOf(path) == id || entries.any((e) => entryIsCurrent(e, path));

/// The drawer's entries for one person in one workspace.
class DrawerEntries {
  DrawerEntries({
    required this.context,
    required this.features,
    required this.permissions,
    required this.accountMenu,
    required this.permanent,
    required this.visibleBranches,
    this.navs,
    this.path = '',
    required this.tabTitles,
    required this.currentIndex,
    required this.onBranch,
    required this.go,
    this.setupOpen = false,
    this.openToPay,
  });

  final BuildContext context;
  final Set<WorkspaceFeature> features;
  final Set<WorkspacePermission> permissions;
  final bool accountMenu;
  final bool permanent;
  final List<int> visibleBranches;

  /// #3551 — the shell's destination table; null: one entry per branch.
  final List<ShellNav>? navs;

  /// The location on screen, for a destination selected by its location.
  final String path;
  final List<String> tabTitles;
  final int currentIndex;
  final ValueChanged<int> onBranch;

  /// #3077 — the setup guide has a milestone open: its door is offered.
  final bool setupOpen;

  /// Opens the existing workspace-wide payable flow.
  final VoidCallback? openToPay;

  /// Leaves the drawer and goes (or pushes) to [route].
  final void Function(String route, {bool push}) go;

  AppLocalizations get l10n => context.l10n;
  AppLocalizations get labels => l10n;

  // #2137 — each entry asks the permission its route asks, so a member
  // given it through a role finds the way there.
  bool may(WorkspacePermission p) => permissions.contains(p);

  /// #3550 — a place entry: the places are on, [p] is held and, when named,
  /// [also] is on too.
  bool mayOnPlaces(WorkspacePermission p, [WorkspaceFeature? also]) =>
      features.contains(WorkspaceFeature.placeBooking) &&
      may(p) &&
      (also == null || features.contains(also));

  List<DrawerEntry> navigation() {
    return <DrawerEntry>[
      // #3610 — on a narrow window search is the drawer's first entry: the
      // bar keeps its controls. The desk has its bar's button.
      if (!permanent && features.contains(WorkspaceFeature.quickSearch))
        DrawerEntry('drawer-search', Icons.search, l10n.invoicingSearch, () {
          final open = ShortcutHost.searchOf(context);
          Navigator.of(context).pop();
          open?.call();
        }),
      if (mayOnPlaces(WorkspacePermission.makeReservations))
        DrawerEntry(
          'drawer-reserve',
          shellBranchIcon(ShellBranch.reserve),
          lexiconText(
            context,
            key: 'shellReserveButton',
            fallback: l10n.shellReserveButton,
          ),
          () {
            if (!permanent) Navigator.of(context).pop();
            onBranch(ShellBranch.reserve);
          },
          selected: currentIndex == ShellBranch.reserve,
        ),
      for (final nav in navs ??
          [for (final b in visibleBranches) ShellNav('$b', b)])
        if (nav.location == null)
          DrawerEntry(
            'drawer-tab-${nav.branch}',
            shellBranchIcon(nav.branch),
            tabTitles[nav.branch],
            () {
              if (!permanent) Navigator.of(context).pop();
              onBranch(nav.branch);
            },
            selected: currentIndex == nav.branch,
          )
        else
          DrawerEntry(
            'drawer-nav-${nav.id}',
            nav.id == 'overview'
                ? Icons.space_dashboard_outlined
                : shellBranchIcon(nav.branch),
            nav.id == 'overview' ? l10n.overviewTitle : tabTitles[nav.branch],
            () => go(nav.location!, push: false),
            // #3603 — a page placed in the tab selects it here too.
            selected: nav.selectedAt(branch: currentIndex, path: path) ||
                placeOf(path) == 'drawer-tab-${nav.branch}',
          ),
      // Events live in the calendar when it holds the alerts: no entry then.
      if (features.contains(WorkspaceFeature.eventsTab) &&
          !calendarHoldsAlerts(features) &&
          may(WorkspacePermission.useMessages))
        DrawerEntry(
          'drawer-events',
          Icons.notifications_outlined,
          lexiconText(context, key: 'tabEvents', fallback: l10n.tabEvents),
          () => go('/events', push: false),
        ),
      // The task wizard — recordings, guides and tools — after Finance and
      // Events (it used to hide behind Help's icons).
      if (features.contains(WorkspaceFeature.taskRecorder))
        DrawerEntry(
          'drawer-task-wizard',
          Icons.assistant_navigation,
          l10n.taskWizardTitle,
          () => go(taskWizardRoute),
        ),
    ];
  }

  /// #3614 — the sales hub's links, as entries of the Sales group: the
  /// guest passes and the register.
  List<DrawerEntry> salesPages() {
    final sales = features.contains(WorkspaceFeature.invoicing);
    return <DrawerEntry>[
      if (features.contains(WorkspaceFeature.guestPasses) &&
          (may(WorkspacePermission.issueInvoices) ||
              may(WorkspacePermission.manageServices)))
        DrawerEntry('drawer-guest-passes', Icons.confirmation_number_outlined,
            l10n.guestPassesTitle, () => go('/money/guest-passes'),
            route: '/money/guest-passes'),
      if (sales &&
          (may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.issueInvoices)))
        DrawerEntry('drawer-invoice-register', Icons.table_rows_outlined,
            l10n.invoiceRegisterTitle, () => go('/invoice-register'),
            route: '/invoice-register'),
    ];
  }

  /// The purchases, cash and accounting pages of #2577, each one door for
  /// whoever holds what its page asks (the sales page is the Sales group
  /// since #3614).
  List<DrawerEntry> money() {
    final money = features.contains(WorkspaceFeature.moneyTab);
    return <DrawerEntry>[
      if (features.contains(WorkspaceFeature.purchases) &&
          (may(WorkspacePermission.viewMyMoney) ||
              may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.managePurchases)))
        DrawerEntry('drawer-purchases', Icons.shopping_cart_outlined,
            l10n.hubPurchasesTitle, () => go('/money/purchases'),
            route: '/money/purchases'),
      // #3070 — the payees, for whoever opens their page.
      if (features.contains(WorkspaceFeature.supplyExpenses) &&
          (may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.manageBilling) ||
              may(WorkspacePermission.managePurchases)))
        DrawerEntry('drawer-suppliers', Icons.storefront_outlined,
            l10n.bookRoleSuppliers, () => go('/money/suppliers'),
            route: '/money/suppliers'),
      ..._purchaseOrders(),
      // #3070 — the documents waiting for a decision; the drawer badges it.
      if (features.contains(WorkspaceFeature.purchases) &&
          may(WorkspacePermission.approveExpenses))
        DrawerEntry('drawer-purchase-approvals', Icons.task_alt_outlined,
            l10n.purchaseApprovalsTitle,
            () => go('/money/purchases/approvals'),
            route: '/money/purchases/approvals'),
      if (features.contains(WorkspaceFeature.purchases) &&
          (may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.managePurchases)) &&
          openToPay != null)
        DrawerEntry('drawer-purchases-to-pay', Icons.outbox_outlined,
            l10n.cashHubToPay, openToPay!),
      if (money &&
          (may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.manageBilling) ||
              may(WorkspacePermission.managePurchases)))
        DrawerEntry('drawer-cash', Icons.account_balance_outlined,
            l10n.hubCashTitle, () => go('/money/cash'),
            route: '/money/cash'),
    ];
  }

  /// #3307 — the space's orders to its suppliers, for a buyer or a
  /// finance reader.
  List<DrawerEntry> _purchaseOrders() => [
    if (features.contains(WorkspaceFeature.purchases) &&
        features.contains(WorkspaceFeature.purchaseOrders) &&
        (may(WorkspacePermission.viewFinances) ||
            may(WorkspacePermission.managePurchases)))
      DrawerEntry('drawer-purchase-orders', Icons.local_shipping_outlined,
          l10n.purchaseOrdersTitle, () => go('/money/purchase-orders'),
          route: '/money/purchase-orders'),
  ];

  /// The accounting and VAT sub-group of Finance: the one place the books,
  /// their export and import, the VAT and the legal identity are reached.
  List<DrawerEntry> accounting() {
    final invoicing = features.contains(WorkspaceFeature.invoicing);
    final billing = may(WorkspacePermission.manageBilling);
    return <DrawerEntry>[
      if (features.contains(WorkspaceFeature.moneyTab) &&
          accountingPageRights.any(may))
        DrawerEntry('drawer-accounting', Icons.menu_book_outlined,
            l10n.hubAccountingTitle, () => go('/money/accounting'),
            route: '/money/accounting'),
      if (invoicing &&
          (may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.issueInvoices)))
        DrawerEntry('drawer-accounting-export', Icons.file_download_outlined,
            l10n.invoiceAccountingExport, () => go('/invoice-register'),
            route: '/invoice-register'),
      if (features.contains(WorkspaceFeature.vatManagement) && billing)
        DrawerEntry('drawer-vat', Icons.percent_outlined, l10n.vatTitle,
            () => go('/vat'),
            route: '/vat'),
      if (invoicing &&
          features.contains(WorkspaceFeature.vatDeclarations) &&
          (billing || may(WorkspacePermission.viewFinances)))
        DrawerEntry('drawer-vat-declarations', Icons.receipt_long_outlined,
            l10n.vatDeclTitle, () => go('/vat-declarations'),
            route: '/vat-declarations'),
      if (invoicing && may(WorkspacePermission.workspaceSettings))
        DrawerEntry('drawer-legal-identity', Icons.badge_outlined,
            l10n.legalIdentityTitle, () => go('/legal-identity'),
            route: '/legal-identity'),
    ];
  }

  /// #3282 — one "Configure workspace" door for the whole configuration:
  /// the guide (its overview, tasks and advanced settings) for whoever may
  /// configure, as its routes require; a delegate who may not opens the
  /// deepest page they may — the workspace's settings, the switches, the plan.
  List<DrawerEntry> setupGuide() {
    final target = configureWorkspaceRoute(
      permissions: permissions,
      features: features,
      setupOpen: setupOpen,
    );
    if (target == null) return const [];
    return [
      DrawerEntry(
        'drawer-setup-guide',
        Icons.tune_outlined,
        l10n.configureWorkspaceTitle,
        () => go(target),
        route: target,
      ),
    ];
  }

  List<DrawerEntry> administration() {
    return <DrawerEntry>[

      if (may(WorkspacePermission.manageMembers))
        DrawerEntry(
          'drawer-members',
          Icons.group_outlined,
          l10n.membersTitle,
          () => go('/members'),
          route: '/members',
        ),
      if (mayOnPlaces(WorkspacePermission.workspaceSettings))
        DrawerEntry(
          'drawer-availability',
          Icons.event_busy_outlined,
          l10n.availabilityTitle,
          () => go('/availability'),
          route: '/availability',
        ),
      if (may(WorkspacePermission.manageRoles) &&
          features.contains(WorkspaceFeature.roleManagement))
        DrawerEntry(
          'drawer-roles',
          Icons.admin_panel_settings_outlined,
          l10n.rolesTitle,
          () => go('/roles'),
          route: '/roles',
        ),
      if ((may(WorkspacePermission.viewFinances) ||
              may(WorkspacePermission.issueInvoices)) &&
          features.contains(WorkspaceFeature.invoicing))
        DrawerEntry(
          'drawer-invoices',
          Icons.receipt_long_outlined,
          l10n.featureInvoicing,
          () => go('/invoices'),
          route: '/invoices',
        ),
      if (may(WorkspacePermission.manageIntegrations) &&
          features.contains(WorkspaceFeature.moneyTab))
        DrawerEntry(
          'drawer-payment-methods',
          Icons.account_balance_wallet_outlined,
          l10n.paymentInstructionsTitle,
          () => go('/payment-methods'),
          route: '/payment-methods',
        ),
      if (may(WorkspacePermission.manageIntegrations) &&
          features.contains(WorkspaceFeature.onlinePayments))
        DrawerEntry(
          'drawer-payment-config',
          Icons.credit_card_outlined,
          l10n.payConfigTitle,
          () => go('/payment-config'),
          route: '/payment-config',
        ),
      if (may(WorkspacePermission.operateKiosk) &&
          features.contains(WorkspaceFeature.nfcBadges))
        DrawerEntry(
          'drawer-nfc-config',
          Icons.nfc_outlined,
          l10n.nfcConfigTitle,
          () => go('/nfc-config'),
          route: '/nfc-config',
        ),
      if (may(WorkspacePermission.manageServices) &&
          features.contains(WorkspaceFeature.services))
        DrawerEntry(
          'drawer-services',
          Icons.room_service_outlined,
          l10n.servicesTitle,
          () => go('/services'),
          route: '/services',
        ),
      if (mayOnPlaces(
        WorkspacePermission.manageServices,
        WorkspaceFeature.accessorySupplements,
      ))
        DrawerEntry(
          'drawer-accessories',
          Icons.chair_outlined,
          l10n.accessoriesTitle,
          () => go('/accessories'),
          route: '/accessories',
        ),
      if (may(WorkspacePermission.manageBilling) &&
          features.contains(WorkspaceFeature.moneyTab))
        DrawerEntry(
          'drawer-billing',
          Icons.tune,
          l10n.billingTitle,
          () => go('/billing'),
          route: '/billing',
        ),
    ];
  }

  /// #2313 — Reporting: every report and the BI in one group, one
  /// sub-item per section the Reports page would show this reader.
  List<DrawerEntry> reporting({
    required List<String> sections,
    required bool Function(String id) onSection,
  }) {
    return <DrawerEntry>[
      if (sections.contains('finance'))
        DrawerEntry(
          'drawer-reports-finance',
          Icons.account_balance_outlined,
          labels.uxReportsFinance,
          () => go('/reports?section=finance'),
          selected: onSection('finance'),
        ),
      if (sections.contains('documents'))
        DrawerEntry(
          'drawer-reports-documents',
          Icons.summarize_outlined,
          labels.uxReportsWorkspace,
          () => go('/reports?section=documents'),
          selected: onSection('documents'),
        ),
      // #1923 — the BI area, on every platform.
      if (sections.contains('analytics'))
        DrawerEntry(
          'drawer-bi',
          Icons.insights_outlined,
          labels.biTitle,
          () => go('/bi'),
          route: '/bi',
        ),
      if (sections.contains('templates'))
        DrawerEntry(
          'drawer-reports-templates',
          Icons.edit_note_outlined,
          labels.uxReportsTemplates,
          () => go('/reports?section=templates'),
          selected: onSection('templates'),
        ),
    ];
  }

  List<DrawerEntry> account() {
    return <DrawerEntry>[
      if (features.contains(WorkspaceFeature.documents) &&
          (may(WorkspacePermission.viewDocuments) ||
              may(WorkspacePermission.manageDocuments)))
        DrawerEntry(
          'drawer-documents',
          Icons.folder_open_outlined,
          l10n.featureDocuments,
          () => go('/documents'),
        ),
      DrawerEntry(
        'drawer-privacy',
        Icons.shield_outlined,
        l10n.privacyTitle,
        () => go('/privacy'),
      ),
      // #1598 — the wide shell says the same word as the narrow one: the
      // entry keeps its key and its destination and changes only its
      // name and icon, so a member who administers nothing reads
      // My account here too.
      DrawerEntry(
        'drawer-settings',
        accountMenu ? Icons.account_circle_outlined : Icons.settings_outlined,
        accountMenu ? (l10n.memberAccountTitle) : (l10n.settingsTitle),
        () => go('/settings'),
      ),
    ];
  }
}
