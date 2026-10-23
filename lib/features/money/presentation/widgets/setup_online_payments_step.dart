// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "online payments" is the operator's: the provider's
// secret key is entered by the operator, never asked of the owner here and
// never shown once saved. The step says so, shows which providers are
// connected as the online-payments screen reads them (secrets only by
// name, never by value), and opens that screen. The preview is the
// checkout a member reaches on an unpaid statement: with the "Pay online"
// button once a provider is connected, without it before.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../domain/payment_provider.dart';
import '../../providers/payment_gateway_providers.dart';
import '../payment_provider_labels.dart';

class SetupOnlinePaymentsStep extends ConsumerWidget {
  const SetupOnlinePaymentsStep({
    super.key,
    required this.workspaceId,
    required this.checkout,
  });

  final String workspaceId;

  /// The checkout a member sees, with or without online payment.
  final Widget Function({required bool payOnline}) checkout;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(paymentGatewayStatusProvider(workspaceId))) {
        AsyncData(value: final status) => SetupStepLayout(
          form: _OnlineForm(status: status),
          preview: _OnlinePreview(
            connected: status.values.any((s) => s.configured),
            checkout: checkout,
          ),
        ),
        AsyncError() => Padding(
          padding: AppSpacing.lgAll,
          child: InlineBanner(
            key: const ValueKey('setup-online-failed'),
            icon: Icons.error_outline,
            text: context.l10n.setupStepLoadFailed,
          ),
        ),
        _ => const LoadingView(),
      };
}

class _OnlineForm extends StatelessWidget {
  const _OnlineForm({required this.status});
  final Map<PaymentProvider, PaymentProviderStatus> status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('online_payments')),
        const SizedBox(height: AppSpacing.md),
        InlineBanner(
          key: const ValueKey('setup-online-operator'),
          icon: Icons.admin_panel_settings_outlined,
          severity: InlineBannerSeverity.info,
          text: l10n.setupOnlineOperatorNotice,
        ),
        const SizedBox(height: AppSpacing.md),
        for (final provider in PaymentProvider.values)
          ListTile(
            key: ValueKey('setup-online-provider-${provider.wireName}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              (status[provider]?.configured ?? false)
                  ? Icons.check_circle_outline
                  : Icons.radio_button_unchecked,
            ),
            title: Text(paymentProviderLabel(l10n, provider)),
            subtitle: Text(
              (status[provider]?.configured ?? false)
                  ? l10n.payConfigConfigured
                  : l10n.payConfigNotConfigured,
            ),
          ),
        const SizedBox(height: AppSpacing.sm),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('setup-online-open-config'),
            onPressed: () => context.push('/payment-config'),
            child: Text(l10n.setupOnlineOpenConfig),
          ),
        ),
      ],
    );
  }
}

class _OnlinePreview extends StatelessWidget {
  const _OnlinePreview({required this.connected, required this.checkout});

  final bool connected;
  final Widget Function({required bool payOnline}) checkout;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      key: const ValueKey('setup-online-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          connected ? l10n.setupOnlinePreviewOn : l10n.setupOnlinePreviewOff,
          key: ValueKey('setup-online-preview-${connected ? 'on' : 'off'}'),
        ),
        const SizedBox(height: AppSpacing.sm),
        // A picture of the checkout: nothing in it acts.
        IgnorePointer(child: checkout(payOnline: connected)),
      ],
    );
  }
}
