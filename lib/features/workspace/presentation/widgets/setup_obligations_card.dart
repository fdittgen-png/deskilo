// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2868 — beside the plain questions, what the law of the space's country
// asks, as the reviewed tax reference data says it: each e-invoicing duty
// with its date, each small-business VAT limit, the law each row cites,
// and "ask your accountant" for a row nobody confirmed or a country the
// data does not cover. It explains; it never sets an answer or a level.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/country_names.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/date_text.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/setup_obligations.dart';

class SetupObligationsCard extends ConsumerWidget {
  const SetupObligationsCard({super.key, required this.country});

  /// The space's country, ISO 3166-1 alpha-2.
  final String country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final today = isoDay(ref.watch(clockProvider).now());
    final dates = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    final obligations = setupObligations(country);
    final small = Theme.of(context).textTheme.bodySmall;
    return Card(
      key: const ValueKey('setup-obligations'),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.setupObligationsTitle(localizedCountryName(l10n, country)),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            if (obligations.isEmpty)
              Text(
                l10n.setupObligationNone,
                key: const ValueKey('setup-obligations-none'),
              ),
            for (final (i, o) in obligations.indexed) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                _text(l10n, o, today, dates),
                key: ValueKey('setup-obligation-$i'),
              ),
              Text(
                [
                  if (!o.confirmed) l10n.setupObligationUnconfirmed,
                  l10n.setupObligationSource(o.source),
                ].join(' '),
                style: small,
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _text(
    AppLocalizations l10n,
    SetupObligation o,
    String today,
    DateFormat dates,
  ) {
    if (o.kind == SetupObligationKind.vatThreshold) {
      return l10n.setupObligationThreshold(
        o.detail,
        moneyFormat(o.currency).formatMinor(o.cents!),
      );
    }
    final duty = switch (o.detail) {
      'receive_all' => l10n.eInvoiceMandateReceiveAll,
      'issue_large' => l10n.eInvoiceMandateIssueLarge,
      'issue_all' => l10n.eInvoiceMandateIssueAll,
      'e_reporting' => l10n.eInvoiceMandateEReporting,
      'invoice_records' => l10n.eInvoiceMandateInvoiceRecords,
      _ => o.detail,
    };
    final from = o.from!;
    final date = dates.format(DateTime.parse(from));
    return from.compareTo(today) <= 0
        ? l10n.eInvoiceMandateSince(date, duty)
        : l10n.eInvoiceMandateFrom(date, duty);
  }
}
