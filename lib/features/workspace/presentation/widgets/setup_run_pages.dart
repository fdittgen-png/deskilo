// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The pages of the setup guide's Run steps. Prices, online payments and
// approvals belong to the money and events features, which sit above this
// one in the feature graph (`test/lint/feature_layers.yaml`): the router
// hands their pages in as builders, and this file gives each one what
// only this feature knows (the workspace row, the switched-on features,
// who the members are) as plain values.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/member.dart';
import '../../domain/payment_instructions.dart';
import '../../domain/workspace.dart';
import '../../domain/workspace_feature.dart';
import '../../providers/workspace_providers.dart';
import 'setup_payment_methods_step.dart';

typedef SetupPricingBuilder = Widget Function({
  required String workspaceId,
  required String currencyCode,
  required bool carnetsOn,
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

class SetupRunPages {
  const SetupRunPages({
    required this.pricing,
    required this.checkout,
    required this.onlinePayments,
    required this.approvals,
  });

  final SetupPricingBuilder pricing;
  final SetupCheckoutBuilder checkout;
  final SetupOnlinePaymentsBuilder onlinePayments;
  final SetupApprovalsBuilder approvals;

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
    _ => null,
  };
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
