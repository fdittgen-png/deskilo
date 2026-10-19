// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/links/link_launcher.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/personal_preferences.dart';
import '../../../profile/providers/personal_preferences_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/payment_provider.dart';
import '../../domain/payment_request_ids.dart';
import '../../providers/money_providers.dart';
import '../payment_provider_labels.dart';

/// Starts an online payment (0043 scaffolding, #1637, #2014 B): asks the
/// deployment what it can charge with, lets the member pick a provider,
/// creates the order and hands the approval URL to the link launcher. Inert
/// until the server carries the PSP secrets (docs/design/payments-integration.md).
/// Split out of `_MoneyScreenState` (#2494).
class MoneyOnlinePayment {
  MoneyOnlinePayment(this._state, this._ref);

  final State _state;
  final WidgetRef _ref;

  /// #2014 B — the request id of a retried payment stays the same.
  final PaymentRequestIds _requests = PaymentRequestIds();

  BuildContext get _context => _state.context;

  /// Pays [amountCents] of the bill of [period].
  Future<void> pay(int amountCents, String period) async {
    final l10n = _context.l10n;
    final workspace = _ref.read(currentWorkspaceProvider).value;
    final member = _ref.read(myMemberProvider).value;
    if (workspace == null || member == null || amountCents <= 0) return;
    final trace = TraceLogger.instance;

    // 1. What can this deployment charge with?
    final gateway = await _probe(workspace.id, l10n);
    if (gateway == null || !_context.mounted) return;
    trace.log(
      TraceLevel.info,
      'payments',
      'config: providers=${gateway.providers.map((p) => p.wireName).toList()} '
          'missing=${gateway.missing}',
    );
    if (gateway.providers.isEmpty) {
      await _diagnostics(l10n, gateway);
      return;
    }

    // 2. Pick the provider (directly when only one is configured).
    final chosen = await _chooseProvider(gateway, l10n);
    if (chosen == null || !_context.mounted) return;

    // 3. Start the order; every step lands in the payments trace.
    trace.log(
      TraceLevel.info,
      'payments',
      'order start: provider=${chosen.wireName} amountCents=$amountCents '
          'period=$period',
    );
    final order = await _startOrder(
      l10n: l10n,
      workspaceId: workspace.id,
      memberId: member.id,
      provider: chosen,
      amountCents: amountCents,
      period: period,
    );
    if (order == null || !_context.mounted) return;
    if (order.alreadyPaid) {
      // #2014 B: retry of a paid request
      return _ref.invalidate(myPaymentIntentsProvider);
    }
    if (!order.started) {
      trace.warn(
        'payments',
        'provider ${chosen.wireName} not configured: ${order.missing}',
      );
      await _diagnostics(
        l10n,
        PaymentGatewayConfig(
          providers: const [],
          missing: {chosen.wireName: order.missing},
        ),
      );
      return;
    }
    trace.log(
      TraceLevel.info,
      'payments',
      'order created: provider=${chosen.wireName} orderId=${order.orderId}',
    );
    // Launch failures are traced inside the shared link seam.
    await _ref.read(linkLauncherProvider)(order.approveUrl!);
  }

  Future<PaymentGatewayConfig?> _probe(
    String workspaceId,
    AppLocalizations l10n,
  ) async {
    PaymentGatewayConfig? config;
    final ok = await runGuarded(
      _context,
      domain: 'payments',
      message: 'payment config probe failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        config = await _ref
            .read(moneyRepositoryProvider)
            .fetchPaymentConfig(workspaceId);
      },
    );
    return ok ? config : null;
  }

  Future<PaymentProvider?> _chooseProvider(
    PaymentGatewayConfig gateway,
    AppLocalizations l10n,
  ) async {
    final preferred = PaymentProvider.fromWire(_ref
        .read(personalSettingsProvider)
        .value
        ?.effective[PersonalPreference.paymentProvider]);
    final direct = gateway.providers.contains(preferred)
        ? preferred
        : gateway.providers.singleOrNull;
    if (direct != null) return direct;
    return showAppSheet<PaymentProvider>(
      context: _context,
      builder: (context) => SheetShell(
        title: l10n.payOnlineChooseTitle,
        children: [
          const SizedBox(height: 12),
          for (final candidate in gateway.providers) ...[
            FilledButton.tonalIcon(
              key: ValueKey('pay-provider-${candidate.wireName}'),
              onPressed: () => Navigator.of(context).pop(candidate),
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: Text(paymentProviderLabel(l10n, candidate)),
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Future<PaymentOrderStart?> _startOrder({
    required AppLocalizations l10n,
    required String workspaceId,
    required String memberId,
    required PaymentProvider provider,
    required int amountCents,
    required String period,
  }) async {
    PaymentOrderStart? start;
    final ok = await runGuarded(
      _context,
      domain: 'payments',
      message: 'create payment order failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        final repo = _ref.read(moneyRepositoryProvider);
        final currency =
            _ref.read(currentWorkspaceProvider).value?.currencyCode ?? 'EUR';
        start = await _requests.run(workspaceId, memberId, provider, period,
            amountCents, (id) => repo.createPaymentOrder(
                provider: provider, workspaceId: workspaceId,
                memberId: memberId, amountCents: amountCents,
                currencyCode: currency, period: period, requestId: id));
      },
    );
    return ok ? start : null;
  }

  /// Owner/admin diagnostics when online payments cannot run: names the
  /// undeployed function or the exact missing server secrets, so "not set
  /// up" is actionable instead of a mystery. Members get the friendly
  /// snack instead.
  Future<void> _diagnostics(
    AppLocalizations l10n,
    PaymentGatewayConfig config,
  ) async {
    final canAdminister =
        _ref.read(myMemberProvider).value?.canAdminister ?? false;
    if (!canAdminister) {
      AppSnack.info(
        _context,
        l10n.payOnlineNotConfigured,
      );
      return;
    }
    final lines = [
      for (final entry in config.missing.entries)
        if (entry.value.isNotEmpty)
          '${entry.key}: ${entry.value.join(', ')}',
    ];
    await showDialog<void>(
      context: _context,
      builder: (context) => PaymentDiagnosticsDialog(lines: lines),
    );
  }
}

/// The owner/admin dialog naming what an online payment is missing.
class PaymentDiagnosticsDialog extends StatelessWidget {
  const PaymentDiagnosticsDialog({super.key, required this.lines});

  final List<String> lines;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final small = Theme.of(context).textTheme.bodySmall;
    return AlertDialog(scrollable: true,
      title: Text(
        l10n.payOnlineDiagTitle,
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.payOnlineDiagHint,
            style: small,
          ),
          const SizedBox(height: 8),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Text(
                line,
                style: small?.copyWith(fontFamily: 'monospace'),
              ),
            ),
        ],
      ),
      actions: [
        TextButton(
          key: const ValueKey('money-close'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonClose),
        ),
        FilledButton(
          key: const ValueKey('pay-config-open'),
          onPressed: () {
            Navigator.of(context).pop();
            unawaited(context.push('/payment-config'));
          },
          child: Text(l10n.payConfigOpen),
        ),
      ],
    );
  }
}
