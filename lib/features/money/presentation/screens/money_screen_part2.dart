// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'money_screen.dart';

// #2386 — part 2 of _MoneyScreenState, split out of money_screen.dart so no
// file holds the whole class.
extension _MoneyScreenStatePart2 on _MoneyScreenState {

  /// Request extra half-days beyond the subscription entitlement (0031):
  /// lands as a pending 'quota' event that owners/admins validate per the
  /// owner's policy; once confirmed the booking cap rises for [_period].
  Future<void> _requestQuotaSheet() async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final count = TextEditingController();
    final period = _period;
    final submitted = await showAppSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SheetShell(
        title: l10n.quotaRequestTitle,
        children: [
            const SizedBox(height: 8),
            Text(
              l10n.quotaRequestExplainer(period),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('quota-request-count'),
              controller: count,
              decoration: InputDecoration(
                labelText:
                    l10n.quotaRequestCountLabel,
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            FilledButton(
              key: const ValueKey('money-submit-payment-2'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n.moneySubmitPayment,
              ),
            ),
        ],
      ),
    );
    if (submitted != true || !mounted) return;

    final halfDays = int.tryParse(count.text.trim());
    if (halfDays == null || halfDays < 1) return;
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'quota request failed',
      errorText: l10n.workspaceGenericError,
      action: () => ref.read(eventRepositoryProvider).requestQuotaExtension(
            workspace.id,
            period: period,
            halfDays: halfDays,
          ),
    )) {
      return;
    }
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n.quotaRequestPending,
    );
    ref.invalidate(eventsProvider);
  }

  /// Self-serve package purchase (0042): pick an owner-defined package; the
  /// cap rises immediately and the price posts to this month's bill.
  Future<void> _buyPackageSheet(MoneyFormat currency) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    if (workspace == null) return;
    final packages = await ref.read(packagesProvider.future);
    // #744 — my negotiated package prices, when I have a deal.
    final myId = ref.read(myMemberProvider).value?.id;
    final myDeal = myId != null &&
            ref
                .read(enabledFeaturesSyncProvider)
                .contains(WorkspaceFeature.priceNegotiations)
        ? ref.read(priceNegotiationProvider(myId)).value?.active
        : null;
    if (!mounted) return;
    if (packages.isEmpty) {
      AppSnack.info(
        context,
        l10n.buyPackageNone,
      );
      return;
    }
    final chosen = await showAppSheet<Package>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SheetShell(
        title: l10n.buyPackageTitle,
        children: [
            const SizedBox(height: 8),
            for (final package in packages)
              Card(
                child: ListTile(
                  key: ValueKey('money-buy-package-days-${package.id}'),
                  title: Text(package.name),
                  subtitle: Text(
                    l10n.buyPackageDays(package.days),
                  ),
                  trailing: Text(currency.formatMinor(
                      myDeal?.itemPrice('packages', package.id) ??
                          package.priceCents)),
                  onTap: () => Navigator.of(context).pop(package),
                ),
              ),
        ],
      ),
    );
    if (chosen == null || !mounted) return;
    if (!await runGuarded(
      context,
      domain: 'money',
      message: 'buy package failed',
      errorText: l10n.workspaceGenericError,
      action: () => ref.read(moneyRepositoryProvider).buyPackage(
            workspace.id,
            chosen.id,
          ),
    )) {
      return;
    }
    if (!mounted) return;
    AppSnack.success(
      context,
      l10n.buyPackageDone,
    );
    // The bill (new charge + higher cap) and every booking surface (the
    // guard now allows more) must refresh.
    ref
      ..invalidate(myStatementProvider)
      ..invalidate(myLedgerProvider);
    invalidateBookingData(ref);
  }

  /// Starts an online payment for [amountCents] (0043 scaffolding). Opens
  /// the payment provider's approval URL when the deployment is configured;
  /// otherwise tells the member online payments are not set up. Inert until
  /// the server carries the PSP secrets (docs/design/payments-integration.md).
  /// Localized label of an online-payment [provider] button.
  /// Owner/admin diagnostics when online payments cannot run: names the
  /// undeployed function or the exact missing server secrets, so "not set
  /// up" is actionable instead of a mystery. Members get the friendly
  /// snack instead.
  Future<void> _paymentDiagnostics(
    AppLocalizations l10n,
    PaymentGatewayConfig config,
  ) async {
    final canAdminister =
        ref.read(myMemberProvider).value?.canAdminister ?? false;
    if (!canAdminister) {
      AppSnack.info(
        context,
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
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          l10n.payOnlineDiagTitle,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.payOnlineDiagHint,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Text(
                  line,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(fontFamily: 'monospace'),
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
      ),
    );
  }

  Future<void> _payOnline(int amountCents) async {
    final l10n = context.l10n;
    final workspace = ref.read(currentWorkspaceProvider).value;
    final member = ref.read(myMemberProvider).value;
    if (workspace == null || member == null || amountCents <= 0) return;
    final trace = TraceLogger.instance;

    // 1. What can this deployment charge with?
    PaymentGatewayConfig? config;
    if (!await runGuarded(
      context,
      domain: 'payments',
      message: 'payment config probe failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        config = await ref
            .read(moneyRepositoryProvider)
            .fetchPaymentConfig(workspace.id);
      },
    )) {
      return;
    }
    final gateway = config;
    if (gateway == null || !mounted) return;
    trace.log(
      TraceLevel.info,
      'payments',
      'config: providers=${gateway.providers.map((p) => p.wireName).toList()} '
          'missing=${gateway.missing}',
    );
    if (gateway.providers.isEmpty) {
      await _paymentDiagnostics(l10n, gateway);
      return;
    }

    // 2. Pick the provider (directly when only one is configured).
    final preferred = PaymentProvider.fromWire(ref.read(personalSettingsProvider).value?.effective[PersonalPreference.paymentProvider]);
    PaymentProvider? provider = gateway.providers.contains(preferred) ? preferred : gateway.providers.singleOrNull;
    provider ??= await showAppSheet<PaymentProvider>(
      context: context,
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
    if (provider == null || !mounted) return;
    final chosen = provider;

    // 3. Start the order; every step lands in the payments trace.
    trace.log(
      TraceLevel.info,
      'payments',
      'order start: provider=${chosen.wireName} amountCents=$amountCents '
          'period=$_period',
    );
    PaymentOrderStart? start;
    if (!await runGuarded(
      context,
      domain: 'payments',
      message: 'create payment order failed',
      errorText: l10n.workspaceGenericError,
      action: () async {
        final repo = ref.read(moneyRepositoryProvider);
        final currency =
            ref.read(currentWorkspaceProvider).value?.currencyCode ?? 'EUR';
        start = await _paymentRequests.run(workspace.id, member.id, chosen,
            _period, amountCents, (id) => repo.createPaymentOrder(
                provider: chosen, workspaceId: workspace.id, memberId: member.id,
                amountCents: amountCents, currencyCode: currency,
                period: _period, requestId: id));
      },
    )) {
      return;
    }
    final order = start;
    if (order == null || !mounted) return;
    if (order.alreadyPaid) return ref.invalidate(myPaymentIntentsProvider); // #2014 B: retry of a paid request
    if (!order.started) {
      trace.warn(
        'payments',
        'provider ${chosen.wireName} not configured: ${order.missing}',
      );
      await _paymentDiagnostics(
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
    await ref.read(linkLauncherProvider)(order.approveUrl!);
  }
}
