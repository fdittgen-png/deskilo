// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The pages of the setup guide's Run steps. Prices, services, online
// payments, the purchase side, approvals, the public page and the kiosk's
// greeting belong to the money, events, directory and kiosk features, which
// sit above this one in the feature graph (`test/lint/feature_layers.yaml`):
// the router hands their pages in as builders, and this file gives each one
// what only this feature knows (the workspace row, the switched-on
// features, who the members are, what the owner may do) as plain values,
// and to the pages whose form holds unsaved answers, the frame that keeps
// them as the step's draft (#2869).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_draft_form.dart';
import '../../domain/member.dart';
import '../../domain/payment_instructions.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import 'setup_draft_frame.dart';
import 'setup_kiosk_step.dart';
import 'setup_payment_methods_step.dart';

typedef SetupPricingBuilder = Widget Function({
  required String workspaceId,
  required String currencyCode,
  required bool carnetsOn,
  required SetupDraftFrameBuilder draft,
});

/// A member's checkout on an unpaid statement, with or without the
/// online-payment button.
typedef SetupCheckoutBuilder = Widget Function(
  PaymentInstructions instructions, {
  required bool payOnline,
});

typedef SetupOnlinePaymentsBuilder = Widget Function({
  required String workspaceId,
  required Widget Function({required bool payOnline}) checkout,
});

typedef SetupApprovalsBuilder = Widget Function({
  required String workspaceId,
  required int owners,
  required int admins,
});

typedef SetupServicesBuilder = Widget Function({
  required String workspaceId,
  required String currencyCode,
});

/// The purchase side's registers: [stepId] is `purchases`, `lease` or
/// `assets`; [held] the wire names of the permissions the owner holds.
typedef SetupPurchaseSideBuilder = Widget Function({
  required String stepId,
  required String workspaceId,
  required String currencyCode,
  required Set<String> held,
});

typedef SetupPublicPageBuilder = Widget Function({
  required String workspaceId,
  required String workspaceName,
  required SetupDraftFrameBuilder draft,
});

class SetupRunPages {
  const SetupRunPages({
    required this.pricing,
    required this.checkout,
    required this.onlinePayments,
    required this.approvals,
    required this.services,
    required this.purchaseSide,
    required this.publicPage,
    required this.kioskGreeting,
  });

  final SetupPricingBuilder pricing;
  final SetupCheckoutBuilder checkout;
  final SetupOnlinePaymentsBuilder onlinePayments;
  final SetupApprovalsBuilder approvals;
  final SetupServicesBuilder services;
  final SetupPurchaseSideBuilder purchaseSide;
  final SetupPublicPageBuilder publicPage;
  final SetupKioskGreetingBuilder kioskGreeting;

  /// The page of [stepId] for [workspace]; null for a step that is not a
  /// Run step with a page here.
  Widget? pageFor(String stepId, Workspace workspace) => switch (stepId) {
    'pricing' => _PricingHost(pages: this, workspace: workspace),
    'payment_methods' => SetupPaymentMethodsStep(
      workspace: workspace,
      checkout: checkout,
    ),
    'online_payments' => onlinePayments(
      workspaceId: workspace.id,
      checkout: ({required bool payOnline}) => checkout(
        PaymentInstructions.fromDb(workspace.paymentInstructions),
        payOnline: payOnline,
      ),
    ),
    'approvals' => _ApprovalsHost(pages: this, workspaceId: workspace.id),
    'services' => services(
      workspaceId: workspace.id,
      currencyCode: workspace.currencyCode,
    ),
    'purchases' || 'lease' || 'assets' => _PurchaseSideHost(
      pages: this,
      stepId: stepId,
      workspace: workspace,
    ),
    'public_page' => publicPage(
      workspaceId: workspace.id,
      workspaceName: workspace.name,
      draft: setupDraftFrameFor(workspace.id, stepId),
    ),
    'kiosk' => SetupKioskStep(workspace: workspace, greeting: kioskGreeting),
    _ => null,
  };
}

/// The purchase side's registers open with the owner's own rights, as on
/// the purchases page.
class _PurchaseSideHost extends ConsumerWidget {
  const _PurchaseSideHost({
    required this.pages,
    required this.stepId,
    required this.workspace,
  });
  final SetupRunPages pages;
  final String stepId;
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) => pages.purchaseSide(
    stepId: stepId,
    workspaceId: workspace.id,
    currencyCode: workspace.currencyCode,
    held: {for (final p in ref.watch(myPermissionsProvider)) p.wireName},
  );
}

class _PricingHost extends ConsumerWidget {
  const _PricingHost({required this.pages, required this.workspace});
  final SetupRunPages pages;
  final Workspace workspace;

  @override
  Widget build(BuildContext context, WidgetRef ref) => pages.pricing(
    workspaceId: workspace.id,
    currencyCode: workspace.currencyCode,
    carnetsOn: ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.carnets),
    draft: setupDraftFrameFor(workspace.id, 'pricing'),
  );
}

/// Counts who can approve the way the server does when it calls a rule
/// short: active members, each once, owners apart from administrators.
class _ApprovalsHost extends ConsumerWidget {
  const _ApprovalsHost({required this.pages, required this.workspaceId});
  final SetupRunPages pages;
  final String workspaceId;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(workspaceMembersProvider)) {
        AsyncValue(hasValue: true, :final value) => pages.approvals(
          workspaceId: workspaceId,
          owners: [
            for (final m in value ?? const <Member>[])
              if (m.status == MemberStatus.active && m.isOwner) m,
          ].length,
          admins: [
            for (final m in value ?? const <Member>[])
              if (m.status == MemberStatus.active && m.isAdmin && !m.isOwner) m,
          ].length,
        ),
        AsyncError() => Padding(
          padding: AppSpacing.lgAll,
          child: InlineBanner(
            key: const ValueKey('setup-approvals-members-failed'),
            icon: Icons.error_outline,
            text: context.l10n.setupStepLoadFailed,
          ),
        ),
        _ => const LoadingView(),
      };
}
