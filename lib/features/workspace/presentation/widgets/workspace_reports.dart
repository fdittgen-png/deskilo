// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../l10n/app_localizations_en.dart';
import '../../../money/presentation/widgets/invoice_template_sheet.dart';
import '../../domain/bi_modules.dart';
import '../../domain/workspace_feature.dart';
import '../../domain/workspace_permission.dart';
import '../../providers/workspace_providers.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/app_tab_bar.dart';

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
  bool on(WorkspaceFeature f) => features.contains(f);
  bool may(WorkspacePermission p) => permissions.contains(p);
  final finance = (on(WorkspaceFeature.invoicing) &&
          (may(WorkspacePermission.viewFinances) || may(WorkspacePermission.issueInvoices))) ||
      (on(WorkspaceFeature.workspaceStatus) && isAdmin &&
          permissions.any({WorkspacePermission.viewMyMoney, WorkspacePermission.viewFinances,
            WorkspacePermission.issueInvoices, WorkspacePermission.manageBilling}.contains)) ||
      (on(WorkspaceFeature.invoicing) && on(WorkspaceFeature.vatDeclarations) && actsAsOwner &&
          (may(WorkspacePermission.manageBilling) || may(WorkspacePermission.viewFinances)));
  return [
    if (finance) 'finance',
    if (may(WorkspacePermission.workspaceSettings)) 'documents',
    if (biAvailable(features: features, permissions: permissions)) 'analytics',
    if (on(WorkspaceFeature.invoicePdfTemplate) &&
        (may(WorkspacePermission.designDocuments) || may(WorkspacePermission.manageDocuments)))
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
    final l = AppLocalizations.of(context) ?? AppLocalizationsEn();
    final features = ref.watch(enabledFeaturesSyncProvider);
    final permissions = ref.watch(myPermissionsProvider);
    final member = ref.watch(myMemberProvider).value;
    bool on(WorkspaceFeature feature) => features.contains(feature);
    bool may(WorkspacePermission permission) => permissions.contains(permission);
    Widget link(String id, IconData icon, String title, String route, {String? subtitle}) =>
      ListTile(key: ValueKey(id), leading: Icon(icon), title: Text(title),
        subtitle: subtitle == null ? null : Text(subtitle), trailing: const Icon(Icons.chevron_right),
        onTap: () => context.push(route));
    final finance = <Widget>[
      if (on(WorkspaceFeature.invoicing) && (may(WorkspacePermission.viewFinances) || may(WorkspacePermission.issueInvoices)))
        link('reports-register', Icons.table_rows_outlined, l.invoiceRegisterTitle, '/invoice-register',
          subtitle: may(WorkspacePermission.issueInvoices) && may(WorkspacePermission.exportData) ? l.invoiceAccountingExport : null),
      if (on(WorkspaceFeature.workspaceStatus) && (member?.isAdmin ?? false) &&
          permissions.any({WorkspacePermission.viewMyMoney, WorkspacePermission.viewFinances, WorkspacePermission.issueInvoices, WorkspacePermission.manageBilling}.contains))
        link('reports-status', Icons.account_balance_outlined, l.statusTitle, '/money/status', subtitle: l.statusSubtitle),
      if (on(WorkspaceFeature.invoicing) && on(WorkspaceFeature.vatDeclarations) && (member?.actsAsOwner ?? false) &&
          (may(WorkspacePermission.manageBilling) || may(WorkspacePermission.viewFinances)))
        link('reports-vat', Icons.receipt_long_outlined, l.vatDeclTitle, '/vat-declarations'),
    ];
    final templates = on(WorkspaceFeature.invoicePdfTemplate) &&
      (may(WorkspacePermission.designDocuments) || may(WorkspacePermission.manageDocuments));
    final sections = <(String, String, List<Widget>)>[
      if (finance.isNotEmpty) ('finance', l.uxReportsFinance, finance),
      if (documents.isNotEmpty) ('documents', l.uxReportsWorkspace, documents),
      if (biAvailable(features: features, permissions: permissions))
        ('analytics', l.biTitle, [link('reports-analytics', Icons.insights_outlined, l.biTitle, '/bi')]),
      if (templates) ('templates', l.uxReportsTemplates, [
        ListTile(key: const ValueKey('reports-templates'), leading: const Icon(Icons.edit_note_outlined),
          title: Text(on(WorkspaceFeature.reportDesigner) ? l.reportEditorTitle : l.invoiceTemplateTitle),
          subtitle: Text(l.invoiceTemplateHint), trailing: const Icon(Icons.chevron_right),
          onTap: () => showInvoiceTemplateSheet(context, ref)),
      ]),
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
