// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/dunning.dart';
import '../../domain/invoice.dart';
import '../../domain/money_face.dart';
import '../../providers/money_face_controller.dart';
import '../../providers/money_providers.dart';
import '../invoice_status.dart';
import 'invoice_journey_view.dart';
import 'invoice_process_sheet.dart';

/// #726 — what a member owes across their invoices, judged by the
/// workspace's own payment term (the dunning rules' first delay): open
/// invoices, the sum still due, and how many are past the term.
class InvoiceExposure {
  const InvoiceExposure({
    required this.open,
    required this.overdue,
    required this.dueCents,
    required this.currency,
    required this.termDays,
  });

  final List<Invoice> open;
  final List<Invoice> overdue;
  final int dueCents;
  final String currency;
  final int termDays;

  bool get isEmpty => open.isEmpty;

  /// Days until (positive) or past (negative) the term of [invoice].
  int daysToTerm(Invoice invoice, DateTime now) =>
      termDays - now.difference(invoice.issuedAt).inDays;

  static InvoiceExposure of({
    required Iterable<Invoice> invoices,
    required Map<String, InvoiceMatch> matches,
    required DunningRules rules,
    required DateTime now,
    required String fallbackCurrency,
  }) {
    final open = <Invoice>[];
    for (final i in invoices) {
      if (i.totalCents <= 0) continue;
      // #831 — a settled source is owed through its settlement, once.
      if (i.isFolded) continue;
      if (invoiceLifecycleOf(i, matches[i.id]) != InvoiceLifecycle.open) {
        continue;
      }
      open.add(i);
    }
    open.sort((a, b) => a.issuedAt.compareTo(b.issuedAt));
    final overdue = [
      for (final i in open)
        if (now.difference(i.issuedAt).inDays >= rules.firstAfterDays) i,
    ];
    return InvoiceExposure(
      open: open,
      overdue: overdue,
      dueCents: open.fold(0, (sum, i) => sum + i.totalCents),
      currency: open.isEmpty ? fallbackCurrency : open.first.currency,
      termDays: rules.firstAfterDays,
    );
  }
}

/// The member's exposure from the providers, or null while loading.
InvoiceExposure? watchExposure(WidgetRef ref, String memberId, String currency) {
  final invoices = ref.watch(invoicesProvider).value;
  if (invoices == null) return null;
  return InvoiceExposure.of(
    invoices: invoices.where((i) => i.memberId == memberId),
    matches: ref.watch(invoiceMatchesProvider).value ?? const {},
    rules: ref.watch(dunningRulesProvider).value ?? DunningRules.defaults,
    now: ref.watch(clockProvider).now(),
    fallbackCurrency: currency,
  );
}

/// The red strip above the Payments and Invoices faces while something
/// is past the term: how many, how much, and the way to settle it.
class OverdueBanner extends ConsumerWidget {
  const OverdueBanner({super.key, required this.exposure});

  final InvoiceExposure exposure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (exposure.overdue.isEmpty) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    final scheme = Theme.of(context).colorScheme;
    final amount = moneyFormat(exposure.currency).formatMinor(
      exposure.overdue.fold(0, (sum, i) => sum + i.totalCents),
    );
    return Card(
      key: const ValueKey('money-overdue-banner'),
      color: scheme.errorContainer,
      child: Padding(
        padding: AppSpacing.mdAll,
        child: Row(children: [
          Icon(Icons.notification_important_outlined,
              color: scheme.onErrorContainer),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Text(
              l10n?.moneyOverdueBanner(exposure.overdue.length, amount) ??
                  '${exposure.overdue.length} overdue — $amount to settle',
              style: TextStyle(
                color: scheme.onErrorContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('money-overdue-pay'),
            onPressed: () => ref
                .read(moneyFaceControllerProvider.notifier)
                .show(MoneyFace.payments),
            child: Text(l10n?.moneyPayNow ?? 'Pay now'),
          ),
        ]),
      ),
    );
  }
}

/// The Invoices face's headline: open count, amount due, overdue count —
/// or "nothing open", which is the sentence most members want to read.
class InvoiceSummaryCard extends ConsumerWidget {
  const InvoiceSummaryCard({super.key, required this.exposure});

  final InvoiceExposure exposure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final money = moneyFormat(exposure.currency);
    // #812 — the same explainer the issuers' hub opens.
    final howItWorks = invoiceJourneyOn(ref)
        ? TextButton.icon(
            key: const ValueKey('money-invoice-process'),
            onPressed: () => showInvoiceProcessSheet(context),
            icon: const Icon(Icons.help_outline, size: 18),
            label: Text(l10n?.journeyHowButton ?? 'How it works'),
          )
        : null;
    return Card(
      key: const ValueKey('money-invoice-summary'),
      child: Padding(
        padding: AppSpacing.mdAll,
        child: exposure.isEmpty
            ? Row(children: [
                Icon(Icons.check_circle_outline,
                    color: theme.colorScheme.primary),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(l10n?.moneyNothingOpen ??
                      'Nothing open — you are up to date.'),
                ),
                ?howItWorks,
              ])
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n?.moneyOpenInvoicesTitle ?? 'Open invoices',
                      style: theme.textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    l10n?.moneyOpenInvoicesSummary(
                          exposure.open.length,
                          money.formatMinor(exposure.dueCents),
                        ) ??
                        '${exposure.open.length} open · '
                            '${money.formatMinor(exposure.dueCents)} due',
                    style: theme.textTheme.bodyLarge,
                  ),
                  if (exposure.overdue.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      l10n?.moneyOverdueBanner(
                            exposure.overdue.length,
                            money.formatMinor(exposure.overdue
                                .fold(0, (s, i) => s + i.totalCents)),
                          ) ??
                          '${exposure.overdue.length} overdue',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: AppSpacing.sm),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      ?howItWorks,
                      if (howItWorks != null)
                        const SizedBox(width: AppSpacing.sm),
                      FilledButton.icon(
                        key: const ValueKey('money-summary-pay'),
                        onPressed: () => ref
                            .read(moneyFaceControllerProvider.notifier)
                            .show(MoneyFace.payments),
                        icon: const Icon(Icons.payments_outlined),
                        label: Text(l10n?.moneyPayNow ?? 'Pay now'),
                      ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}
