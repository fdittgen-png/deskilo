// SPDX-License-Identifier: AGPL-3.0-or-later

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../profile/domain/personal_preferences.dart';
import '../../../profile/providers/personal_preferences_providers.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/finance_selection_commands.dart';
import '../../domain/payment_claims.dart';
import '../../domain/payment_gateway_repository.dart';
import '../../domain/payment_provider.dart';
import '../../domain/payment_request_ids.dart';
import '../../providers/finance_overview_provider.dart';
import '../../providers/finance_selection_provider.dart';
import '../../providers/money_providers.dart';
import '../../providers/payment_approval_providers.dart';
import '../claim_refusal_text.dart';
import '../finance_host_unavailable.dart';
import '../payment_provider_labels.dart';

typedef _PaymentTarget = ({String workspaceId, String memberId, String currency,
  String financeKey, PaymentGatewayRepository repository, PaymentRequestIds requests,
  String businessName, bool canAdminister, Future<bool> Function()? open});

/// Starts an online payment (0043 scaffolding, #1637, #2014 B): asks the
/// deployment what it can charge with, lets the member pick a provider,
/// creates the order and hands the approval URL to the link launcher. Inert
/// until the server carries the PSP secrets (docs/design/payments-integration.md).
/// Split out of `_MoneyScreenState` (#2494).
class MoneyOnlinePayment {
  MoneyOnlinePayment(this._state, this._ref);

  final State _state;
  final WidgetRef _ref;

  /// #2014 B — the request id of a retried payment stays the same: one set
  /// per account, shared with My finances (#3556), so a retry after a lost
  /// answer is the same request whichever screen makes it.
  PaymentRequestIds get _requests => _ref.read(paymentRequestIdsProvider);

  BuildContext get _context => _state.context;

  /// Pays [amountCents] of the bill of [period]; with [invoiceIds] (#3556)
  /// exactly those invoices of that month (the server derives what they
  /// still owe and refuses any other amount). True once the payment is
  /// with its provider (or was paid already); false when it was not
  /// started — refused, failed or left — so a selection stays as it was.
  ///
  /// #4165 — [standalone]: [invoiceIds] are invoices without a month, paid as
  /// one payment of their financial subject ([period] is not read); the
  /// payment function must say it takes them.
  Future<bool> pay(
    int amountCents,
    String period, {
    List<String>? invoiceIds,
    FinanceCommandTarget? captured,
    bool standalone = false,
  }) async {
    final l10n = _context.l10n;
    final payment = _paymentOrSay(captured, amountCents, period, invoiceIds, standalone);
    if (payment == null || amountCents <= 0 || (captured != null && !captured.isCurrent())) return false;
    final trace = TraceLogger.instance;

    // 1. What can this deployment charge with?
    final gateway = await _probe(payment.workspaceId, l10n, payment.repository);
    if (gateway == null || !_context.mounted) return false;
    trace.log(
      TraceLevel.info,
      'payments',
      'config: providers=${gateway.providers.map((p) => p.wireName).toList()} '
          'missing=${gateway.missing}',
    );
    if (gateway.providers.isEmpty) {
      await _diagnostics(l10n, gateway, payment);
      return false;
    }
    if (_unsupported(l10n, gateway, invoiceIds: invoiceIds, standalone: standalone)) return false;

    // 2. Pick the provider (directly when only one is configured).
    final chosen = await _chooseProvider(gateway, l10n);
    if (chosen == null || !_context.mounted || (captured != null && !captured.isCurrent())) return false;

    // 3. Start the order; every step lands in the payments trace.
    trace.log(
      TraceLevel.info,
      'payments',
      'order start: provider=${chosen.wireName} amountCents=$amountCents '
          'period=$period',
    );
    final order = await _startOrder(
      l10n: l10n,
      payment: payment,
      provider: chosen,
      order: _claimOf(standalone, period, amountCents, invoiceIds ?? const []),
    );
    if (order == null || !_context.mounted || (captured != null && !captured.isCurrent())) return false;
    // #3556 — the function names how many invoices it took; another count
    // is a claim not taken: its checkout is not opened.
    if (invoiceIds != null &&
        order.started &&
        order.claimed != invoiceIds.length) {
      trace.warn('payments', 'payment claim not taken: ${order.claimed}');
      AppSnack.error(_context, l10n.payOnlineClaimNotTaken);
      return false;
    }
    if (order.alreadyPaid) {
      // #2014 B: retry of a paid request
      _ref.invalidate(myPaymentIntentsProvider);
      return true;
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
        payment,
      );
      return false;
    }
    trace.log(
      TraceLevel.info,
      'payments',
      'order created: provider=${chosen.wireName} orderId=${order.orderId}',
    );
    // Launch failures are traced inside the shared link seam.
    await _ref.read(paymentApprovalProvider)(_context, order.approveUrl!);
    return true;
  }

  /// #3556 — a function that does not take a claim would drop it and pay the account: a selection is not paid through
  /// it; #4165 — nor are invoices without a month through a function that does not know them. Says so, and answers
  /// whether the payment stops here.
  bool _unsupported(AppLocalizations l10n, PaymentGatewayConfig gateway, {required List<String>? invoiceIds, required bool standalone}) {
    final text = invoiceIds != null && !gateway.claims
        ? l10n.payOnlineClaimsUnsupported
        : (standalone && !gateway.standalone ? l10n.payOnlineStandaloneUnsupported : null);
    if (text == null) return false;
    AppSnack.error(_context, text);
    return true;
  }

  /// The invoices a payment names: a month's, or those without one (#4165).
  InvoiceClaim _claimOf(bool standalone, String period, int amountCents, List<String> invoiceIds) => standalone
      ? InvoiceClaim.standalone(amountCents: amountCents, invoiceIds: invoiceIds)
      : InvoiceClaim(period: period, amountCents: amountCents, invoiceIds: invoiceIds);

  /// The target of a payment; when the business's verified identity is not
  /// known yet (its context is loading or failed) that is said, with a way to
  /// try again, and not nothing (#4218).
  _PaymentTarget? _paymentOrSay(
    FinanceCommandTarget? captured,
    int amountCents,
    String period,
    List<String>? invoiceIds,
    bool standalone,
  ) {
    final payment = _payment(captured);
    if (payment != null || captured != null || amountCents <= 0) return payment;
    final l10n = _context.l10n;
    AppSnack.error(_context, l10n.payOnlineContextNotReady,
        action: SnackBarAction(
          key: const ValueKey('pay-not-ready-retry'),
          label: l10n.commonRetry,
          onPressed: () {
            if (_context.mounted) {
              unawaited(pay(amountCents, period, invoiceIds: invoiceIds, standalone: standalone));
            }
          },
        ));
    return null;
  }

  _PaymentTarget? _payment(FinanceCommandTarget? captured) {
    if (captured != null) {
      return (
      workspaceId: captured.target.workspaceId, memberId: captured.memberId,
      currency: captured.currency, repository: captured.gateway,
      financeKey: captured.target.financeKey, requests: _requests,
      businessName: captured.businessName, canAdminister: captured.canAdminister,
      open: captured.open,
      );
    }
    final workspace = _ref.read(currentWorkspaceProvider).value;
    final member = _ref.read(myMemberProvider).value;
    // #4218 — no bare local id stands in for the identity: a payment of a
    // business whose verified identity is not known is not started.
    final target = _ref.read(financeCurrentTargetProvider);
    if (workspace == null || member == null || target == null) return null;
    return (workspaceId: workspace.id, memberId: member.id,
      currency: workspace.currencyCode, repository: _ref.read(paymentGatewayRepositoryProvider),
      financeKey: target.financeKey, requests: _requests,
      businessName: workspace.name, canAdminister: member.canAdminister, open: null);
  }

  Future<PaymentGatewayConfig?> _probe(
    String workspaceId,
    AppLocalizations l10n,
    PaymentGatewayRepository repository,
  ) async {
    PaymentGatewayConfig? config;
    final ok = await runGuarded(
      _context,
      domain: 'payments',
      message: 'payment config probe failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        config = await repository.fetchPaymentConfig(workspaceId);
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
    required PaymentProvider provider,
    required _PaymentTarget payment,
    // what is paid: a month and its amount, and the invoices it names
    // (#3556; none: a payment of the account)
    required InvoiceClaim order,
  }) async {
    final InvoiceClaim(:period, :amountCents, :invoiceIds, :standalone) = order;
    final workspaceId = payment.workspaceId;
    final memberId = payment.memberId;
    PaymentOrderStart? start;
    ClaimRefusal? refused;
    final ok = await runGuarded(
      _context,
      domain: 'payments',
      message: 'create payment order failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        final repo = payment.repository;
        // No workspace currency, no payment order: never one in a currency
        // nobody chose (#2488).
        final currency = payment.currency;
        try {
          final claimed = invoiceIds.isNotEmpty;
          start = await payment.requests.run(payment.financeKey, memberId, provider,
              claimed
                  ? PaymentRequestIds.forClaim(standalone ? 'standalone' : period, invoiceIds)
                  : period,
              amountCents, (id) => claimed
                  ? repo.createClaimOrder(
                      provider: provider, workspaceId: workspaceId,
                      memberId: memberId, currencyCode: currency,
                      claim: order, requestId: id)
                  : repo.createPaymentOrder(
                      provider: provider, workspaceId: workspaceId,
                      memberId: memberId, amountCents: amountCents,
                      currencyCode: currency, period: period, requestId: id));
        } on ClaimRefused catch (r, st) {
          // #3556 — the business's server refused the invoices named:
          // nothing was charged; said by its own sentence.
          TraceLogger.instance.warn('payments', 'payment claim refused: ${r.reason.code}',
              error: r, stackTrace: st);
          refused = r.reason;
        } on PaymentGatewayException catch (e, st) {
          // #3556 — a retried payment the server ended (failed, or too old
          // to send again): its id is forgotten (definitive), and the person
          // starts the payment again.
          final ended = e.status == 409 &&
              (e.detail.contains('intent_failed') ||
                  e.detail.contains('intent_stale'));
          // #3905 — a production workspace takes real payments only: an order
          // on test credentials is refused, and said in words.
          if (!ended && (e.status != 409 || !e.detail.contains('test_keys'))) {
            rethrow;
          }
          TraceLogger.instance.warn('payments', 'payment order refused: ${e.detail}',
              error: e, stackTrace: st);
          if (_context.mounted) {
            AppSnack.error(_context,
                ended ? l10n.payOnlineStartAgain : l10n.payOnlineTestKeys);
          }
        }
      },
    );
    if (refused case final r? when _context.mounted) {
      AppSnack.error(_context, claimRefusalText(l10n, r));
    }
    return ok ? start : null;
  }

  /// Opens the configuration of the business the payment is OF: that business
  /// is entered first (its host, as Open does); one that cannot be entered is
  /// said, with a way to try again.
  Future<void> _configure(_PaymentTarget payment) async {
    final open = payment.open;
    if (open != null && !await open()) {
      if (_context.mounted) {
        showFinanceHostUnavailable(_context, payment.businessName, opening: true,
            retry: () => unawaited(_configure(payment)));
      }
      return;
    }
    if (_context.mounted) unawaited(_context.push('/payment-config'));
  }

  /// Owner/admin diagnostics when online payments cannot run: names the
  /// undeployed function or the exact missing server secrets, so "not set
  /// up" is actionable instead of a mystery. Members get the friendly
  /// snack instead.
  ///
  /// #4218 — for the business the payment is OF (its name, my right there,
  /// its own configuration), never the business selected elsewhere.
  Future<void> _diagnostics(
    AppLocalizations l10n,
    PaymentGatewayConfig config,
    _PaymentTarget payment,
  ) async {
    if (!payment.canAdminister) {
      AppSnack.info(
        _context,
        l10n.payOnlineNotConfigured,
      );
      return;
    }
    final lines = [
      for (final entry in config.missing.entries)
        if (entry.value.isNotEmpty)
          l10n.labelledValue(entry.key, entry.value.join(', ')),
    ];
    await showDialog<void>(
      context: _context,
      builder: (context) => PaymentDiagnosticsDialog(
        lines: lines,
        business: payment.businessName,
        onConfigure: () => _configure(payment),
      ),
    );
  }
}

/// The owner/admin dialog naming what an online payment is missing.
class PaymentDiagnosticsDialog extends StatelessWidget {
  const PaymentDiagnosticsDialog({
    super.key,
    required this.lines,
    required this.business,
    required this.onConfigure,
  });

  final List<String> lines;

  /// The business these payments are missing configuration for (#4218).
  final String business;

  /// Opens that business's configuration.
  final Future<void> Function() onConfigure;

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
            l10n.payOnlineDiagBusiness(business),
            style: small?.emphasised,
          ),
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
            unawaited(onConfigure());
          },
          child: Text(l10n.payConfigOpenFor(business)),
        ),
      ],
    );
  }
}
