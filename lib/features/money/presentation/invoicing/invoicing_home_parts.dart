// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 release 1 -- the invoicing home's two plain states: a business
// that has never invoiced, and a source that could not be read.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/personal_theme.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../providers/money_providers.dart';
import 'invoicing_home.dart' show InvoicingSource;
import 'invoicing_reads.dart';

/// The home of a business that has never invoiced.
class InvoicingEmptyHome extends StatelessWidget {
  const InvoicingEmptyHome({super.key, required this.onNewInvoice});

  final VoidCallback onNewInvoice;

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final theme = Theme.of(context);
    return ListView(
      key: const ValueKey('invoicing-empty'),
      padding: AppSpacing.mdAll,
      children: [
        KitCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: AppSpacing.sm,
            children: [
              Text(l.invoicingEmptyTitle, style: theme.textTheme.titleMedium),
              Text(
                l.invoicingEmptyBody,
                style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
              ),
              const SizedBox(height: AppSpacing.sm),
              FilledButton.icon(
                key: const ValueKey('invoicing-empty-new'),
                onPressed: onNewInvoice,
                icon: const Icon(Icons.add),
                label: Text(l.invoicingEmptyNew),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// One line naming a source that could not be read, with a retry.
class InvoicingFailedSource extends ConsumerWidget {
  const InvoicingFailedSource({
    super.key,
    required this.source,
    required this.onRetry,
  });

  final InvoicingSource source;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = context.l10n;
    // #4097 — the invoices themselves are the page's records: their failed
    // or refused read is said as every records page says it.
    if (source == InvoicingSource.invoices) {
      if (ref.watch(invoicesProvider).error case final error?) {
        return ReadFailureBanner(error: error, onRetry: onRetry);
      }
    }
    final t = PersonalTheme.of(context);
    final name = switch (source) {
      InvoicingSource.invoices => l.featureInvoicing,
      InvoicingSource.matches => l.invoicingSourceMatches,
      InvoicingSource.holds => l.invoicingSourceHolds,
      InvoicingSource.transmissions => l.invoicingSourceTransmissions,
      InvoicingSource.credits => l.invoicingSourceCredits,
      InvoicingSource.payments => l.invoicingSourcePayments,
      InvoicingSource.reminders => l.invoicingSourceReminders,
      InvoicingSource.toInvoice => l.invoicingSourceToInvoice,
      InvoicingSource.declarations => l.invoicingSourceDeclarations,
      InvoicingSource.rules => l.dunningSettingsTitle,
    };
    return DecoratedBox(
      key: ValueKey('invoicing-failed-${source.name}'),
      decoration: BoxDecoration(
        color: t.warningTint,
        borderRadius: AppRadius.lgAll,
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: AppSpacing.md),
        child: Row(
          children: [
            Expanded(
              child: Text(
                // #3913 — the money not assigned is unknown because ledger
                // entries could not be read: said so, not as a failed read.
                source == InvoicingSource.credits &&
                        unassignedMoneyUnreadable(
                          ref.watch(unassignedMoneyProvider),
                        )
                    ? l.invoicingUnassignedUnreadable
                    : l.invoicingSourceFailed(name),
                style: TextStyle(color: t.warning),
              ),
            ),
            TextButton(
              key: ValueKey('invoicing-retry-${source.name}'),
              onPressed: onRetry,
              child: Text(l.invoicingTryAgain),
            ),
          ],
        ),
      ),
    );
  }
}
