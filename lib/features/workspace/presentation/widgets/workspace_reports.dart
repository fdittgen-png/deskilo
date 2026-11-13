// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import '../../../../core/ui/app_tab_bar.dart';
import '../../../money/presentation/widgets/invoice_template_sheet.dart';
import '../../domain/bi_modules.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/workspace_providers.dart';
import 'report_pages.dart';
import 'reports_table.dart';

/// Existing destinations keep their own feature and permission checks.
bool workspaceReportsAvailable(Set<WorkspaceFeature> features,
    Set<WorkspacePermission> permissions, {bool isAdmin = false}) =>
    permissions.contains(WorkspacePermission.workspaceSettings) ||
    (features.contains(WorkspaceFeature.invoicing) &&
      permissions.any({WorkspacePermission.viewFinances, WorkspacePermission.issueInvoices}.contains)) ||
    (isAdmin && features.contains(WorkspaceFeature.workspaceStatus) &&
      permissions.any({WorkspacePermission.viewMyMoney, WorkspacePermission.viewFinances, WorkspacePermission.issueInvoices, WorkspacePermission.manageBilling}.contains)) ||
    biAvailable(features: features, permissions: permissions) ||
    (features.contains(WorkspaceFeature.invoicePdfTemplate) &&
      permissions.any({WorkspacePermission.designDocuments, WorkspacePermission.manageDocuments}.contains));

/// #2313 — the sections of the Reporting area this reader may open, in menu
/// order: `finance`, `documents`, `analytics`, `templates`. The drawer's
/// Reporting group and the Reports page's tabs both come from here, so a
/// sub-item is never offered for a tab the page would not show.
List<String> reportingSections({
  required Set<WorkspaceFeature> features,
  required Set<WorkspacePermission> permissions,
  bool isAdmin = false,
  bool actsAsOwner = false,
}) {
  // #3617 — the sections of the report pages come from their one list.
  final pages = reportPagesFor(
    features: features,
    permissions: permissions,
    isAdmin: isAdmin,
    actsAsOwner: actsAsOwner,
  );
  bool has(ReportSection s) => pages.any((p) => p.section == s);
  return [
    if (has(ReportSection.finance)) 'finance',
    if (permissions.contains(WorkspacePermission.workspaceSettings)) 'documents',
    if (has(ReportSection.analytics)) 'analytics',
    if (features.contains(WorkspaceFeature.invoicePdfTemplate) &&
        (permissions.contains(WorkspacePermission.designDocuments) ||
            permissions.contains(WorkspacePermission.manageDocuments)))
      'templates',
  ];
}

class WorkspaceReports extends ConsumerWidget {
  const WorkspaceReports({required this.workspaceName, required this.documents, this.initialSection, super.key});
  final String workspaceName;
  final List<Widget> documents;

  /// #2313 — the tab the Reporting menu asked for (`/reports?section=`).
  final String? initialSection;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    final features = ref.watch(enabledFeaturesSyncProvider);
    final permissions = ref.watch(myPermissionsProvider);
    final member = ref.watch(myMemberProvider).value;
    final pages = reportPagesFor(
      features: features,
      permissions: permissions,
      isAdmin: member?.isAdmin ?? false,
      actsAsOwner: member?.actsAsOwner ?? false,
    );
    final templates = features.contains(WorkspaceFeature.invoicePdfTemplate) &&
      permissions.any({WorkspacePermission.designDocuments, WorkspacePermission.manageDocuments}.contains);
    final templateTile = ListTile(key: const ValueKey('reports-templates'), leading: const Icon(Icons.edit_note_outlined),
      title: Text(features.contains(WorkspaceFeature.reportDesigner) ? l.reportEditorTitle : l.invoiceTemplateTitle),
      subtitle: Text(l.invoiceTemplateHint), trailing: const Icon(Icons.chevron_right),
      onTap: () => showInvoiceTemplateSheet(context, ref));
    final tools = [...documents, if (templates) templateTile];
    // #3617 — at the desk the reports are one records table.
    if (WindowClass.of(context).index >= WindowClass.expanded.index) {
      return ReportsTable(pages: pages, tools: tools);
    }
    Widget link(ReportPage p) => ListTile(key: ValueKey('reports-${p.id}'), leading: Icon(p.icon),
      title: Text(p.name(l)), subtitle: Text(p.covers(l)), trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push(p.route));
    List<Widget> of(ReportSection s) => [for (final p in pages) if (p.section == s) link(p)];
    final sections = <(String, String, List<Widget>)>[
      // #2583 — the overview: what needs the person, then the figures.
      if (of(ReportSection.overview).isNotEmpty) ('overview', l.overviewTitle, of(ReportSection.overview)),
      if (of(ReportSection.finance).isNotEmpty) ('finance', l.uxReportsFinance, of(ReportSection.finance)),
      if (documents.isNotEmpty) ('documents', l.uxReportsWorkspace, documents),
      if (of(ReportSection.analytics).isNotEmpty) ('analytics', l.biTitle, of(ReportSection.analytics)),
      if (templates) ('templates', l.uxReportsTemplates, [templateTile]),
    ];
    final initial = sections.indexWhere((s) => s.$1 == initialSection);
    return DefaultTabController(length: sections.length, initialIndex: initial < 0 ? 0 : initial,
      child: Column(children: [
      ListTile(title: Text(workspaceName), subtitle: Text(l.uxReportsHint)),
      AppTabBar(tabs: [
        for (final section in sections) AppTab(section.$2, key: ValueKey('workspace-section-${section.$1}')),
      ]),
      Expanded(child: TabBarView(children: [
        for (final section in sections) ListView(padding: AppSpacing.gutterAll,
          children: section.$3),
      ])),
    ]));
  }
}
