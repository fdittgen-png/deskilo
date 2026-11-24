// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4105 -- before issuing, what the configured channel will still need: a
// warning, not a refusal (a paper or PDF invoice is valid without these), with
// the way to where the space's own facts are entered.
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/navigation/routes.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/einvoice_channel_check.dart';
import 'e_invoice_sheet.dart';

/// The gaps of the configured channel, said before the number is taken.
class EInvoiceGapsWarning extends StatelessWidget {
  const EInvoiceGapsWarning({
    super.key,
    required this.l10n,
    required this.gaps,
  });

  final AppLocalizations l10n;
  final List<ChannelGap> gaps;

  @override
  Widget build(BuildContext context) {
    final ownFacts = gaps.any(isSellerGap);
    return InlineBanner(
      key: const ValueKey('invoice-einvoice-gaps'),
      icon: Icons.outgoing_mail,
      severity: InlineBannerSeverity.info,
      text:
          '${l10n.invoiceEInvoiceGapsTitle}\n'
          '${[for (final gap in gaps) '• ${channelGapText(l10n, gap)}'].join('\n')}',
      actionLabel: ownFacts ? l10n.invoiceEInvoiceGapsOpenIdentity : null,
      onAction: ownFacts ? () => context.push(Routes.legalIdentity) : null,
    );
  }
}
