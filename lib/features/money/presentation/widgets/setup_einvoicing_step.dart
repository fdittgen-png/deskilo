// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The setup step "e-invoicing": the platform as the server stores it (the
// connector, whether it can send, which test environments are ready) and,
// while none is saved, the connector's documented test addresses
// (`eInvoiceSandboxDefaults`). The credentials themselves are typed on the
// e-invoicing platform screen, one tap away: they are secrets the server
// never returns, and that screen is their one editor. The guide sends
// nothing — a test send starts from an issued invoice. Beside it, what the
// law asks in the space's country: the dated duties of the tax reference
// data (`mandatesFor`), an unconfirmed date said to be unconfirmed, and a
// country the server refuses to issue for said to be refused.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/setup_step_layout.dart';
import '../../domain/einvoice_gateway.dart';
import '../../domain/einvoice_mandates.dart';
import '../../domain/einvoice_providers.dart';
import '../../providers/money_providers.dart';
import 'e_invoice_sheet.dart';
import 'einvoice_provider_section.dart';

class SetupEInvoicingStep extends ConsumerWidget {
  const SetupEInvoicingStep({super.key, required this.countryCode});

  /// The space's country, whose obligations the preview states.
  final String countryCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      switch (ref.watch(eInvoiceStatusProvider)) {
        AsyncValue(hasValue: true, :final value) => SetupStepLayout(
          form: _PlatformForm(
            status: value ?? const EInvoiceProviderStatus(configured: false),
            gateway:
                ref.watch(eInvoiceGatewayProvider).value ??
                EInvoiceGatewayConfig.notConfigured,
          ),
          preview: _Obligations(countryCode: countryCode),
        ),
        AsyncError() => Padding(
          padding: AppSpacing.lgAll,
          child: InlineBanner(
            key: const ValueKey('setup-einvoicing-failed'),
            icon: Icons.error_outline,
            text: context.l10n.setupStepLoadFailed,
          ),
        ),
        _ => const LoadingView(),
      };
}

class _PlatformForm extends StatelessWidget {
  const _PlatformForm({required this.status, required this.gateway});

  final EInvoiceProviderStatus status;
  final EInvoiceGatewayConfig gateway;

  String _platform(BuildContext context) {
    final l10n = context.l10n;
    if (!status.configured) return l10n.setupGrowEinvoicingNone;
    final name = eInvoiceProviderName(l10n, status.provider);
    return gateway.configured
        ? l10n.setupGrowEinvoicingReady(name)
        : l10n.setupGrowEinvoicingIncomplete(name);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupStepHint('einvoicing')),
        const FormGap.large(),
        Text(
          _platform(context),
          key: const ValueKey('setup-einvoicing-platform'),
          style: theme.textTheme.titleSmall,
        ),
        const FormGap(),
        Semantics(
          header: true,
          child: Text(
            l10n.setupGrowEinvoicingTestTitle,
            style: theme.textTheme.titleSmall,
          ),
        ),
        const FormGap.small(),
        _TestEnvironments(provider: status.provider, gateway: gateway),
        const FormGap(),
        InlineBanner(
          key: const ValueKey('setup-einvoicing-test-send'),
          icon: Icons.science_outlined,
          severity: InlineBannerSeverity.info,
          text: l10n.setupGrowEinvoicingTestSend,
        ),
        const FormGap.small(),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('setup-einvoicing-open'),
            onPressed: () => context.push('/einvoice-config'),
            child: Text(l10n.setupGrowEinvoicingOpen),
          ),
        ),
      ],
    );
  }
}

/// The test environments that are ready, or the connector's documented
/// test addresses while none is.
class _TestEnvironments extends StatelessWidget {
  const _TestEnvironments({required this.provider, required this.gateway});

  final String provider;
  final EInvoiceGatewayConfig gateway;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final ready = gateway.testEnvironments;
    if (ready.isNotEmpty) {
      return Text(
        l10n.setupGrowEinvoicingTestReady(
          ready
              .map(
                (e) => e == 'dev' ? l10n.einvoiceEnvDev : l10n.einvoiceEnvUat,
              )
              .join(', '),
        ),
        key: const ValueKey('setup-einvoicing-test-ready'),
      );
    }
    final sandbox = eInvoiceSandboxDefaults[provider] ?? const {};
    if (sandbox.isEmpty) {
      return Text(
        l10n.setupGrowEinvoicingNoSandbox,
        key: const ValueKey('setup-einvoicing-no-sandbox'),
      );
    }
    return Column(
      key: const ValueKey('setup-einvoicing-sandbox'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.setupGrowEinvoicingSandboxIntro),
        for (final MapEntry(:key, :value) in sandbox.entries)
          ListTile(
            key: ValueKey('setup-einvoicing-sandbox-$key'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(eInvoiceFieldLabel(l10n, key)),
            subtitle: SelectableText(value),
          ),
      ],
    );
  }
}

/// The country's dated e-invoicing duties, as the tax reference data has
/// them.
class _Obligations extends ConsumerWidget {
  const _Obligations({required this.countryCode});

  final String countryCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final today = ref.watch(clockProvider).now();
    final dates = DateFormat.yMMMd(Localizations.localeOf(context).toString());
    final duties = mandatesFor(countryCode);
    final refused = nationalChannelRequired.contains(
      countryCode.trim().toUpperCase(),
    );
    return Column(
      key: const ValueKey('setup-einvoicing-preview'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.setupGrowEinvoicingLawTitle,
          style: theme.textTheme.titleSmall,
        ),
        const FormGap.small(),
        if (duties.isEmpty)
          Text(
            l10n.setupGrowEinvoicingNoMandate,
            key: const ValueKey('setup-einvoicing-no-mandate'),
          ),
        for (final (index, duty) in duties.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.xs),
            child: Text(
              mandateText(l10n, duty, today, dates),
              key: ValueKey('setup-einvoicing-duty-$index'),
            ),
          ),
        if (duties.any((d) => !d.confirmed)) ...[
          const FormGap.small(),
          Text(
            l10n.setupGrowEinvoicingUnconfirmed,
            key: const ValueKey('setup-einvoicing-unconfirmed'),
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (refused) ...[
          const FormGap(),
          InlineBanner(
            key: const ValueKey('setup-einvoicing-refused'),
            icon: Icons.block,
            text: l10n.setupGrowEinvoicingChannel,
          ),
        ],
      ],
    );
  }
}
