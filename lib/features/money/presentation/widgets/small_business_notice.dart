// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../domain/small_business_threshold.dart';
import '../../providers/money_providers.dart';

/// #2440 — on Invoicing, tells a seller on the small-business exemption
/// (franchise, § 19 UStG) when its net turnover of the year nears or has
/// passed the limit that ends it. Nothing for any other regime, country or
/// currency.
class SmallBusinessNotice extends ConsumerWidget {
  const SmallBusinessNotice({
    super.key,
    required this.exempt,
    required this.country,
    required this.currency,
  });

  /// Whether the seller's VAT regime is the small-business exemption.
  final bool exempt;
  final String country;
  final String currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoices = ref.watch(invoicesProvider).value;
    if (!exempt || invoices == null) return const SizedBox.shrink();
    final now = ref.watch(clockProvider).now();
    final turnover = turnoverOfYear(invoices, now.year);
    final alerts = smallBusinessAlerts(
      country: country,
      currency: currency,
      turnoverCents: turnover,
    );
    if (alerts.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final alert = alerts.first;
    final money = moneyFormat(currency);
    final (turnoverText, limit) = (
      money.formatMinor(alert.turnoverCents),
      money.formatMinor(alert.threshold.cents),
    );
    final immediate = alert.threshold.effect == ThresholdEffect.immediate;
    final passed = alert.level == ThresholdLevel.passed;
    final message = switch ((immediate, passed)) {
      (false, false) => l10n.smallBusinessNearNextYear(turnoverText, limit),
      (false, true) => l10n.smallBusinessPassedNextYear(turnoverText, limit),
      (true, false) => l10n.smallBusinessNearImmediate(turnoverText, limit),
      (true, true) => l10n.smallBusinessPassedImmediate(turnoverText, limit),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: InlineBanner(
        key: const ValueKey('small-business-notice'),
        icon: Icons.warning_amber_outlined,
        text: alert.threshold.confirmed
            ? message
            : '$message ${l10n.smallBusinessCheckFigure}',
        severity: passed
            ? InlineBannerSeverity.error
            : InlineBannerSeverity.info,
      ),
    );
  }
}
