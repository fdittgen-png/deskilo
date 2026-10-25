// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The test payment of the online-payments step: on the owner's request it
// reads what a member's checkout would do with the keys the space holds
// (test keys move no real money, a live key charges a real card) and
// whether the space opens payments at all. Nothing is paid, and no
// invoice or statement line is written. What it cannot see is said
// beside every answer: whether the provider accepts the keys and tells
// DesKilo a payment arrived, which only a first payment with test keys,
// made by the operator who holds them, proves. The step offers it only
// while online payments are on, as the server only answers then.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/payment_test_check.dart';
import '../../providers/payment_gateway_providers.dart';
import '../payment_provider_labels.dart';

class SetupPaymentTest extends ConsumerStatefulWidget {
  const SetupPaymentTest({super.key, required this.workspaceId});

  final String workspaceId;

  @override
  ConsumerState<SetupPaymentTest> createState() => _SetupPaymentTestState();
}

class _SetupPaymentTestState extends ConsumerState<SetupPaymentTest> {
  final _asked = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _asked.dispose();
    super.dispose();
  }

  void _run() {
    if (_asked.value) {
      ref.invalidate(paymentTestCheckProvider(widget.workspaceId));
    }
    _asked.value = true;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ValueListenableBuilder<bool>(
      valueListenable: _asked,
      builder: (context, asked, _) {
        final answer = asked
            ? ref.watch(paymentTestCheckProvider(widget.workspaceId))
            : null;
        return Column(
          key: const ValueKey('setup-online-test'),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.setupOnlineTestTitle,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(l10n.setupOnlineTestBody),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(
                key: const ValueKey('setup-online-test-run'),
                onPressed: (answer?.isLoading ?? false) ? null : _run,
                child: Text(l10n.setupOnlineTestRun),
              ),
            ),
            if (answer != null) ...[
              const SizedBox(height: AppSpacing.sm),
              switch (answer) {
                AsyncData(:final value) => _Answer(check: value),
                AsyncError() => InlineBanner(
                  key: const ValueKey('setup-online-test-failed'),
                  icon: Icons.error_outline,
                  text: l10n.setupStepLoadFailed,
                ),
                _ => const LinearProgressIndicator(),
              },
            ],
          ],
        );
      },
    );
  }
}

class _Answer extends StatelessWidget {
  const _Answer({required this.check});

  final PaymentTestCheck check;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InlineBanner(
          key: ValueKey('setup-online-test-${check.verdict.wireName}'),
          icon: switch (check.verdict) {
            PaymentTestVerdict.testKeys => Icons.science_outlined,
            PaymentTestVerdict.liveKeys => Icons.credit_card,
            _ => Icons.help_outline,
          },
          severity: check.verdict == PaymentTestVerdict.liveKeys
              ? InlineBannerSeverity.error
              : InlineBannerSeverity.info,
          text: _verdict(l10n, check.verdict),
        ),
        for (final MapEntry(key: provider, value: mode) in check.modes.entries)
          ListTile(
            key: ValueKey('setup-online-test-mode-${provider.wireName}'),
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(paymentProviderLabel(l10n, provider)),
            subtitle: Text(_mode(l10n, mode)),
          ),
        if (!check.takesPayments) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineBanner(
            key: const ValueKey('setup-online-test-rehearsal'),
            icon: Icons.construction_outlined,
            severity: InlineBannerSeverity.info,
            text: l10n.setupOnlineTestRehearsal,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
        Text(
          l10n.setupOnlineTestLimits,
          key: const ValueKey('setup-online-test-limits'),
        ),
      ],
    );
  }

  static String _verdict(AppLocalizations l10n, PaymentTestVerdict v) =>
      switch (v) {
        PaymentTestVerdict.noProvider => l10n.setupOnlineTestNoProvider,
        PaymentTestVerdict.testKeys => l10n.setupOnlineTestTestKeys,
        PaymentTestVerdict.liveKeys => l10n.setupOnlineTestLiveKeys,
        PaymentTestVerdict.unverified => l10n.setupOnlineTestUnverified,
      };

  static String _mode(AppLocalizations l10n, PaymentKeyMode m) => switch (m) {
    PaymentKeyMode.test => l10n.setupOnlineKeyTest,
    PaymentKeyMode.live => l10n.setupOnlineKeyLive,
    PaymentKeyMode.unknown => l10n.setupOnlineKeyUnknown,
    PaymentKeyMode.installation => l10n.setupOnlineKeyInstallation,
  };
}
