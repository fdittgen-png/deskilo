// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/payment_intent.dart';
import '../../domain/payment_provider.dart';
import '../payment_provider_labels.dart';

/// #1637 — what became of the member's online payments for the browsed
/// month, told truthfully. A session the provider has not confirmed is
/// PENDING: the balance keeps showing what is owed and the reference is
/// there to quote if it never settles. A refused or expired one is
/// FAILED: nothing was credited. A captured one needs no card — its
/// credit is on the bill. Only the webhook's ledger posting ever says
/// "paid"; the provider's redirect back to the app never does.
class OnlinePaymentStatusCard extends StatelessWidget {
  const OnlinePaymentStatusCard({
    super.key,
    required this.intents,
    required this.currencyCode,
  });

  /// The member's own attempts (any period); the card picks its own.
  final List<PaymentIntent> intents;
  final String currencyCode;

  /// The attempts worth a line: pending ones, and failed ones that no
  /// later capture of the same month has superseded.
  static List<PaymentIntent> shown(List<PaymentIntent> intents, String period) {
    final ofMonth = intents.where((i) => i.period == period).toList();
    final captured = ofMonth.any((i) => i.status == 'captured');
    return [
      for (final i in ofMonth)
        if (i.status == 'created' || (i.status == 'failed' && !captured)) i,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final currency = moneyFormat(currencyCode);
    return Card(
      key: const ValueKey('online-payment-status-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final intent in intents)
            ListTile(
              key: ValueKey('online-payment-${intent.status}-${intent.id}'),
              leading: Icon(
                intent.status == 'failed'
                    ? Icons.error_outline
                    : Icons.hourglass_top_outlined,
                color: intent.status == 'failed' ? scheme.error : null,
              ),
              title: Text(
                intent.status == 'failed'
                    ? (l10n?.payOnlineFailedTitle ?? 'Online payment failed')
                    : (l10n?.payOnlinePendingTitle ??
                        'Online payment pending'),
              ),
              subtitle: Text(_detail(l10n, intent, currency)),
            ),
        ],
      ),
    );
  }

  String _detail(
    AppLocalizations? l10n,
    PaymentIntent intent,
    MoneyFormat currency,
  ) {
    final provider = PaymentProvider.fromWire(intent.provider);
    final via = provider == null
        ? intent.provider
        : paymentProviderLabel(l10n, provider);
    final amount = currency.formatMinor(intent.amountCents);
    return intent.status == 'failed'
        ? (l10n?.payOnlineFailedDetail(intent.reference, amount, via) ??
            'Payment ${intent.reference} ($amount via $via) was not '
                'completed — nothing was credited; the balance is still owed.')
        : (l10n?.payOnlinePendingDetail(intent.reference, amount, via) ??
            'Payment ${intent.reference} ($amount via $via) has not been '
                'confirmed by the provider yet, so the balance still shows '
                'what is owed. Quote this reference if it does not settle.');
  }
}
