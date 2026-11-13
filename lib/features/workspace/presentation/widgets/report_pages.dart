// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3617 — the reports that are pages, declared once (the decision on
// #3617): each with its section, the address it opens, and the feature and
// right it needs. This one list feeds the desk's records table, the phone's
// tabs and the search's pages, so the three never disagree; a report whose
// feature is off or whose right the person lacks is in none of them, as it
// is not in the menu. Its name and what it covers are its own sentences.
import 'package:flutter/material.dart';

import '../../../../l10n/app_localizations.dart';
import '../../domain/bi_modules.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';

/// The section a report stands under: a tab on a phone, a chip at the desk.
enum ReportSection { overview, finance, analytics }

/// One report that is a page.
@immutable
class ReportPage {
  const ReportPage({
    required this.id,
    required this.section,
    required this.route,
    required this.icon,
  });

  final String id;
  final ReportSection section;

  /// The address it opens.
  final String route;
  final IconData icon;

  /// Its name, as the menu and the search say it.
  String name(AppLocalizations l) => switch (id) {
    'register' => l.invoiceRegisterTitle,
    'status' => l.statusTitle,
    'vat' => l.vatDeclTitle,
    'overview' => l.overviewTitle,
    _ => l.biTitle,
  };

  /// What it covers: the report's own sentence.
  String covers(AppLocalizations l) => switch (id) {
    'register' => l.reportCoversRegister,
    'status' => l.statusSubtitle,
    'vat' => l.reportCoversVat,
    'overview' => l.reportCoversOverview,
    _ => l.reportCoversAnalysis,
  };
}

/// The reports [the person] may open, in menu order: their features on and
/// their rights held.
List<ReportPage> reportPagesFor({
  required Set<WorkspaceFeature> features,
  required Set<WorkspacePermission> permissions,
  bool isAdmin = false,
  bool actsAsOwner = false,
}) {
  bool on(WorkspaceFeature f) => features.contains(f);
  bool may(WorkspacePermission p) => permissions.contains(p);
  bool any(Set<WorkspacePermission> ps) => permissions.any(ps.contains);
  return [
    if (on(WorkspaceFeature.workspaceOverview))
      const ReportPage(
        id: 'overview',
        section: ReportSection.overview,
        route: '/workspace-overview',
        icon: Icons.dashboard_outlined,
      ),
    if (on(WorkspaceFeature.invoicing) &&
        any({
          WorkspacePermission.viewFinances,
          WorkspacePermission.issueInvoices,
        }))
      const ReportPage(
        id: 'register',
        section: ReportSection.finance,
        route: '/invoice-register',
        icon: Icons.table_rows_outlined,
      ),
    // #3627 — the status asks what its route and the server ask.
    if (on(WorkspaceFeature.workspaceStatus) &&
        any({WorkspacePermission.viewFinances}))
      const ReportPage(
        id: 'status',
        section: ReportSection.finance,
        route: '/money/status',
        icon: Icons.account_balance_outlined,
      ),
    if (on(WorkspaceFeature.invoicing) &&
        on(WorkspaceFeature.vatDeclarations) &&
        actsAsOwner &&
        (may(WorkspacePermission.manageBilling) ||
            may(WorkspacePermission.viewFinances)))
      const ReportPage(
        id: 'vat',
        section: ReportSection.finance,
        route: '/vat-declarations',
        icon: Icons.receipt_long_outlined,
      ),
    if (biAvailable(features: features, permissions: permissions))
      const ReportPage(
        id: 'analysis',
        section: ReportSection.analytics,
        route: '/bi',
        icon: Icons.insights_outlined,
      ),
  ];
}
