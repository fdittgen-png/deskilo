// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../domain/swiss_kmu.dart';

/// #2360 — the accounts of the Swiss booking journal: the suggestions of
/// the KMU chart, shown and editable before the file is written. A chart
/// is the accountant's; every wrong number is unbooked by hand.
Future<SwissKmuAccounts?> showSwissKmuAccountsDialog(
  BuildContext context, {
  SwissKmuAccounts initial = const SwissKmuAccounts(),
}) {
  final l10n = context.l10n;
  final fields = <(String, String, TextEditingController)>[
    ('debtors', l10n.fecAccountCustomers, TextEditingController(text: initial.debtors)),
    ('bank', l10n.fecAccountBank, TextEditingController(text: initial.bank)),
    ('revenue-normal', l10n.swissKmuRevenueNormal, TextEditingController(text: initial.revenueNormal)),
    ('revenue-reduced', l10n.swissKmuRevenueReduced, TextEditingController(text: initial.revenueReduced)),
    ('revenue-exempt', l10n.swissKmuRevenueExempt, TextEditingController(text: initial.revenueExempt)),
    ('vat', l10n.fecAccountVat, TextEditingController(text: initial.vatDue)),
  ];
  String text(String key) =>
      fields.firstWhere((f) => f.$1 == key).$3.text.trim();
  return showDialog<SwissKmuAccounts>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l10n.swissKmuAccountsTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.swissKmuAccountsIntro,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: AppSpacing.md),
            for (final f in fields)
              AppTextField(
                key: ValueKey('swiss-kmu-account-${f.$1}'),
                controller: f.$3,
                fieldKey: f.$1,
                keyboardType: TextInputType.number,
                label: f.$2,
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('swiss-kmu-accounts-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('swiss-kmu-accounts-confirm'),
          onPressed: () => Navigator.of(context).pop(SwissKmuAccounts(
            debtors: text('debtors'),
            bank: text('bank'),
            revenueNormal: text('revenue-normal'),
            revenueReduced: text('revenue-reduced'),
            revenueExempt: text('revenue-exempt'),
            vatDue: text('vat'),
          )),
          child: Text(l10n.commonSave),
        ),
      ],
    ),
  ).whenComplete(() {
    for (final f in fields) {
      f.$3.dispose();
    }
  });
}
