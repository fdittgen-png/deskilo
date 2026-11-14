// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3961 — the Demo's stand-in for a payment provider's page: where the real
// app would leave for the provider, the Demo shows this sheet. It says what
// it is, charges nothing and offers the three answers a provider gives: pay,
// cancel, no answer. It names no provider.
import 'package:flutter/material.dart';

import '../../l10n/context_l10n.dart';
import '../../ui/app_sheet.dart';
import '../../ui/form_kit.dart';
import '../../ui/form_sheet.dart';
import '../data/money/demo_payment_gateway_repository.dart';

/// Shows the page and returns the answer chosen; null when it is dismissed,
/// which is no answer either.
Future<DemoPaymentOutcome?> showDemoProviderPage(BuildContext context) =>
    showAppSheet<DemoPaymentOutcome>(
      context: context,
      builder: (sheet) {
        final l10n = sheet.l10n;
        return SheetShell(
          title: l10n.demoProviderPageTitle,
          children: [
            Text(l10n.demoProviderPageBody),
            const FormGap.large(),
            FilledButton(
              key: const ValueKey('demo-provider-pay'),
              onPressed: () => Navigator.of(sheet).pop(DemoPaymentOutcome.paid),
              child: Text(l10n.demoProviderPagePay),
            ),
            const FormGap.small(),
            OutlinedButton(
              key: const ValueKey('demo-provider-cancel'),
              onPressed: () =>
                  Navigator.of(sheet).pop(DemoPaymentOutcome.cancelled),
              child: Text(l10n.commonCancel),
            ),
            const FormGap.small(),
            TextButton(
              key: const ValueKey('demo-provider-no-answer'),
              onPressed: () =>
                  Navigator.of(sheet).pop(DemoPaymentOutcome.noAnswer),
              child: Text(l10n.demoProviderPageNoAnswer),
            ),
          ],
        );
      },
    );
