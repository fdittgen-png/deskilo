// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4218 — what My finances says when the host of an invoice cannot be reached
// or verified: in words, naming the invoice's business, with a way to try
// again. Pay, declare, take back, continue and Open all end here, so none of
// them fails silently or throws past the page.
import 'package:flutter/material.dart';

import '../../../core/l10n/context_l10n.dart';
import '../../../core/ui/app_snack.dart';

/// Says that [business] cannot be reached or verified now, and offers to
/// [retry]. [opening] is for a page that only opens something; a command says
/// as well that nothing was sent.
void showFinanceHostUnavailable(
  BuildContext context,
  String business, {
  required VoidCallback retry,
  bool opening = false,
}) {
  final l10n = context.l10n;
  AppSnack.error(
    context,
    opening
        ? l10n.financesBusinessUnavailableOpen(business)
        : l10n.financesBusinessUnavailable(business),
    action: SnackBarAction(
      key: const ValueKey('finance-host-retry'),
      label: l10n.commonRetry,
      onPressed: retry,
    ),
  );
}
