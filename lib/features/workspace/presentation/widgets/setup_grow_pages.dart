// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The pages of the setup guide's Grow steps: the legal identity, the VAT
// rates, the invoice numbering, the invoice look, the e-invoicing
// platform, the books and the reminder rules belong to the money
// feature, which sits above this one in the feature graph
// (`test/lint/feature_layers.yaml`). The router hands their pages in as
// builders, and this file gives each one what only this feature knows
// (the workspace row, and how to read it again) as plain values, and to
// the legal identity the frame that keeps its unsaved answers as the
// step's draft (#2869).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ui/setup_draft_form.dart';
import '../../domain/site.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/settings_providers.dart';
import '../../providers/workspace_providers.dart';
import 'setup_draft_frame.dart';

typedef SetupLegalIdentityBuilder = Widget Function({
  required String workspaceId,
  required VoidCallback onSaved,
  required SetupDraftFrameBuilder draft,
});

typedef SetupVatBuilder = Widget Function({
  required String workspaceId,
  required String countryCode,
  required String currencyCode,
  required String vatRegime,
});

typedef SetupDocumentsBuilder = Widget Function({required String workspaceId});

typedef SetupEInvoicingBuilder = Widget Function({required String countryCode});

typedef SetupAccountingBuilder = Widget Function({
  required String workspaceId,
  required Map<String, String> sites,
  required bool periodsOn,
  required bool isOwner,
});

typedef SetupRemindersBuilder = Widget Function({
  required String workspaceId,
  required String currencyCode,
  required Map<String, Object?> invoiceLegal,
  required VoidCallback onSaved,
});

class SetupGrowPages {
  const SetupGrowPages({
    required this.legalIdentity,
    required this.vat,
    required this.numbering,
    required this.documents,
    required this.einvoicing,
    required this.accounting,
    required this.reminders,
  });

  final SetupLegalIdentityBuilder legalIdentity;
  final SetupVatBuilder vat;
  final Widget Function() numbering;
  final SetupDocumentsBuilder documents;
  final SetupEInvoicingBuilder einvoicing;
  final SetupAccountingBuilder accounting;
  final SetupRemindersBuilder reminders;

  /// The page of [stepId] for [workspace]; null for a step that is not a
  /// Grow step with a page here.
  Widget? pageFor(String stepId, Workspace workspace) => switch (stepId) {
    'legal_identity' => _LegalIdentityHost(
      pages: this,
      workspaceId: workspace.id,
    ),
    'vat' => vat(
      workspaceId: workspace.id,
      countryCode: workspace.countryCode,
      currencyCode: workspace.currencyCode,
      vatRegime: workspace.vatRegime,
    ),
    'numbering' => numbering(),
    'documents' => documents(workspaceId: workspace.id),
    'einvoicing' => einvoicing(countryCode: workspace.countryCode),
    'accounting' => _AccountingHost(pages: this, workspaceId: workspace.id),
    'reminders' => _RemindersHost(pages: this, workspace: workspace),
    _ => null,
  };
}

/// The legal identity lives on the workspace row: once saved, the row is
/// read again, so the guide and every invoice see it.
class _LegalIdentityHost extends ConsumerWidget {
  const _LegalIdentityHost({required this.pages, required this.workspaceId});
  final SetupGrowPages pages;
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) => pages.legalIdentity(
    workspaceId: workspaceId,
    onSaved: () => ref.invalidate(myWorkspacesProvider),
    draft: setupDraftFrameFor(workspaceId, 'legal_identity'),
  );
}

/// The books are kept per issuer: the page names each one by its site, and
/// offers the accounting periods when they are on.
class _AccountingHost extends ConsumerWidget {
  const _AccountingHost({required this.pages, required this.workspaceId});
  final SetupGrowPages pages;
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sites = ref.watch(sitesProvider).value ?? const <Site>[];
    return pages.accounting(
      workspaceId: workspaceId,
      sites: {for (final s in sites) s.id: s.name},
      periodsOn: ref
          .watch(enabledFeaturesSyncProvider)
          .contains(WorkspaceFeature.accountingPeriods),
      isOwner: ref.watch(myMemberProvider).value?.isOwner ?? false,
    );
  }
}

/// The first reminder's delay is also a setting: once the rules are saved,
/// the settings are read again.
class _RemindersHost extends ConsumerWidget {
  const _RemindersHost({required this.pages, required this.workspace});
  final SetupGrowPages pages;
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) => pages.reminders(
    workspaceId: workspace.id,
    currencyCode: workspace.currencyCode,
    invoiceLegal: workspace.invoiceLegal,
    onSaved: () => ref
      ..invalidate(settingsSetProvider(workspace.id))
      ..invalidate(currentSettingsProvider),
  );
}
