// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice.dart';
import 'open_invoice_card.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../domain/invoice_ubl.dart';
import '../../domain/money_face.dart';
import '../../providers/money_face_controller.dart';
import '../../providers/money_providers.dart';
import '../invoice_status.dart';
import '../period_label.dart';
import 'invoice_detail_sheet.dart';
import 'invoice_journey_view.dart';
import 'invoice_overview.dart';

/// #720 — the Invoices face lists MY documents right there, newest
/// first, each opening the same detail sheet the register uses. An OPEN
/// invoice says when it is due (or since when it is overdue, #726) and
/// carries the one action that matters: pay. RLS already scopes
/// [invoicesProvider] to what the caller may read; the client filter to
/// the subject only keeps an issuer's own face about THEM.
class MyInvoicesList extends ConsumerWidget {
  const MyInvoicesList({
    super.key,
    required this.memberId,
    required this.exposure,
  });

  final String memberId;
  final InvoiceExposure exposure;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    // Erroneous (voided) invoices stay out of a member's face, as they
    // do in the register's member view (0072): the replacement is the
    // document that counts.
    // #831 — a regrouped source nests under its settlement.
    final fold = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.settlementFold);
    final all = ref.watch(invoicesProvider).value ?? const <Invoice>[];
    final invoices = all
        .where((i) => i.memberId == memberId && !i.isVoided && !(fold && i.isFolded))
        .toList()
      ..sort((a, b) => b.issuedAt.compareTo(a.issuedAt));
    final matches = ref.watch(invoiceMatchesProvider).value ?? const {};
    final reminders = ref.watch(invoiceRemindersProvider).value ?? const {};
    final now = ref.watch(clockProvider).now();
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    if (invoices.isEmpty) {
      return Padding(
        key: const ValueKey('my-invoices-empty'),
        padding: AppSpacing.mdAll,
        child: Text(
          l10n?.moneyNoInvoicesYet ??
              'No invoice yet — the month is invoiced by the workspace once '
                  'it closes.',
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final invoice in invoices)
          _row(context, ref, l10n, theme, invoice, matches[invoice.id],
              reminders[invoice.id], dateFormat, now),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations? l10n,
    ThemeData theme,
    Invoice invoice,
    InvoiceMatch? match,
    ({int count, DateTime last})? reminder,
    DateFormat dateFormat,
    DateTime now,
  ) {
    final status = invoiceLifecycleOf(invoice, match);
    final open = status == InvoiceLifecycle.open && invoice.totalCents > 0;
    final days = exposure.daysToTerm(invoice, now);
    final overdue = open && days <= 0;
    // #812 — the journey: the bar and "your move" on the row itself; the
    // facts line keeps its due/overdue count (#726) beside them.
    final journey = watchInvoiceJourney(
      ref,
      invoice,
      match: match,
      reminder: reminder,
    );
    final dueLine = !open
        ? null
        : overdue
            ? (l10n?.moneyOverdueBy(-days) ?? 'Overdue by ${-days} days')
            : (l10n?.moneyDueIn(days) ?? 'Due in $days days');
    final facts = Text(
      [
        invoicePeriodLabel(context, invoice),
        dateFormat.format(invoice.issuedAt),
        ?dueLine,
        if (reminder != null)
          l10n?.moneyRemindedTimes(reminder.count) ??
              'Reminded ×${reminder.count}',
      ].join(' · '),
      style: overdue ? TextStyle(color: theme.colorScheme.error) : null,
    );
    final card = Card(
      child: ListTile(
        key: ValueKey('my-invoice-${invoice.id}'),
        onTap: () => _open(context, ref, invoice, match),
        title: Wrap(
          spacing: AppSpacing.sm,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              invoice.number,
              style: invoice.isVoided
                  ? const TextStyle(decoration: TextDecoration.lineThrough)
                  : null,
            ),
            InvoiceStatusChip(status: status),
          ],
        ),
        subtitle: journey == null
            ? facts
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: AppSpacing.xs),
                  InvoiceJourneyBar(journey: journey),
                  const SizedBox(height: AppSpacing.xs),
                  facts,
                  const SizedBox(height: AppSpacing.xs),
                  InvoiceMoveLine(
                    journey: journey,
                    invoice: invoice,
                    match: match,
                    issuer: false,
                  ),
                ],
              ),
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          Text(
            moneyFormat(invoice.currency).formatMinor(invoice.totalCents),
            style: theme.textTheme.titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          if (open)
            IconButton(
              key: ValueKey('my-invoice-pay-${invoice.id}'),
              tooltip: l10n?.moneyPayNow ?? 'Pay now',
              icon: Icon(Icons.payments_outlined,
                  color: overdue ? theme.colorScheme.error : null),
              onPressed: () => ref
                  .read(moneyFaceControllerProvider.notifier)
                  .show(MoneyFace.payments),
            ),
        ]),
      ),
    );
    // #831 — the regrouped sources under their settlement, PDF only.
    if (invoice.settles.isEmpty) return card;
    final all = ref.read(invoicesProvider).value ?? const <Invoice>[];
    final currency = moneyFormat(invoice.currency);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        card,
        for (final source in invoice.settles)
          FoldedSourceRow(
            key: ValueKey('my-invoice-folded-${source.invoiceId}'),
            keyPrefix: 'my-invoice-folded',
            source: source,
            settlement: invoice,
            full: all.where((i) => i.id == source.invoiceId).firstOrNull,
            currency: currency,
          ),
      ],
    );
  }

  Future<void> _open(
    BuildContext context,
    WidgetRef ref,
    Invoice invoice,
    InvoiceMatch? match,
  ) async {
    final country = ref.read(currentWorkspaceProvider).value?.countryCode ?? '';
    final reminder = ref.read(invoiceRemindersProvider).value?[invoice.id];
    await showInvoiceDetailSheet(
      context,
      invoice: invoice,
      match: match,
      settledByNumber: settledByNumberOf(
          invoice, ref.read(invoicesProvider).value ?? const []),
      canIssue: ref
          .read(myPermissionsProvider)
          .contains(WorkspacePermission.issueInvoices),
      isEu: isEuCountry(country),
      reminder: reminder,
      journey: readInvoiceJourney(
        ref,
        invoice,
        match: match,
        reminder: reminder,
      ),
    );
  }
}
