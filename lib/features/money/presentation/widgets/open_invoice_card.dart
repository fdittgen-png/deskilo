// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/accounting_view.dart';
import '../../domain/billing_rules.dart';
import '../../domain/invoice.dart';
import '../invoice_actions.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../domain/dunning.dart';
import '../../providers/money_providers.dart';
import '../invoice_journey.dart';
import 'invoice_journey_view.dart';

/// Everything an open card can do — the same callbacks the hub already
/// wires, so the process view never invents an action of its own.
typedef OpenInvoiceActions = ({
  void Function(OpenInvoiceEntry entry) onOpen,
  void Function(OpenInvoiceEntry entry) onRemind,
  void Function(OpenInvoiceEntry entry) onMatch,
  void Function(OpenInvoiceEntry entry) onWriteoff,
  void Function(OpenInvoiceEntry entry) onRefund,
  void Function(OpenInvoiceEntry entry) onVoid,
  void Function(OpenInvoiceEntry entry) onProforma,
  void Function(OpenInvoiceEntry entry) onEvents,
});

/// #812 — the Open tab as a PROCESS: every card carries the journey bar,
/// the next move as a sentence, ONE labelled button for the action the
/// move expects from the issuer, and the other actions as icons with
/// tooltips beside it (field report: three labels side by side clipped).
class OpenInvoiceJourneyList extends ConsumerWidget {
  const OpenInvoiceJourneyList({
    super.key,
    required this.entries,
    required this.currency,
    required this.actions,
  });

  final List<OpenInvoiceEntry> entries;
  final MoneyFormat currency;
  final OpenInvoiceActions actions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final matches = ref.watch(invoiceMatchesProvider).value ?? const {};
    final reminders = ref.watch(invoiceRemindersProvider).value ?? const {};
    final rules = ref.watch(dunningRulesProvider).value ?? DunningRules.defaults;
    final events = ref.watch(eventsProvider).value ?? const [];
    final now = ref.watch(clockProvider).now();
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    // #831 — a settlement's sources nest under it, documentation only.
    final fold = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.settlementFold);
    final all = ref.watch(invoicesProvider).value ?? const <Invoice>[];
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        for (final entry in entries) ...[
          OpenInvoiceCard(
            key: ValueKey('invoice-open-${entry.invoice.id}'),
            entry: entry,
            journey: InvoiceJourney.of(
              invoice: entry.invoice,
              match: matches[entry.invoice.id],
              reminder: reminders[entry.invoice.id],
              rules: rules,
              now: now,
              facts: journeyFactsOf(
                entry.invoice,
                matches[entry.invoice.id],
                events,
              ),
            ),
            currency: currency,
            dateFormat: dateFormat,
            now: now,
            actions: actions,
          ),
          if (fold && entry.invoice.kind == InvoiceKind.settlement)
            for (final source in entry.invoice.settles)
              FoldedSourceRow(
                key: ValueKey('invoice-folded-${source.invoiceId}'),
                source: source,
                settlement: entry.invoice,
                full: all.where((i) => i.id == source.invoiceId).firstOrNull,
                currency: currency,
              ),
        ],
      ],
    );
  }
}

/// #831 — one regrouped source under its settlement: number, period,
/// amount, where it went — and the ONE thing left to do with it, the
/// stamped PDF.
class FoldedSourceRow extends ConsumerWidget {
  const FoldedSourceRow({
    super.key,
    required this.source,
    required this.settlement,
    required this.full,
    required this.currency,
    this.keyPrefix = 'invoice-folded',
  });

  final SettledSource source;
  final Invoice settlement;

  /// The source as an invoice, when the list holds it (the PDF needs it).
  final Invoice? full;
  final MoneyFormat currency;
  final String keyPrefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    // How it stands THROUGH the settlement: paid once that one is.
    final settlementMatch =
        ref.watch(invoiceMatchesProvider).value?[settlement.id];
    final paid = full != null &&
        effectiveMatchOf(full!, settlement, settlementMatch) != null;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpacing.xl),
      child: Card(
        color: theme.colorScheme.surfaceContainerLow,
        child: ListTile(
          dense: true,
          leading: Icon(Icons.subdirectory_arrow_right,
              color: theme.colorScheme.onSurfaceVariant),
          title: Text([
            source.number,
            if (source.period != null) source.period!,
            currency.formatMinor(source.totalCents),
          ].join(' · ')),
          subtitle: Text(
            paid
                ? (l10n?.settlementPaidThrough(settlement.number) ??
                    'Paid through ${settlement.number}')
                : (l10n?.settlementFoldedIn(settlement.number) ??
                    'Regrouped in ${settlement.number}'),
            key: ValueKey('$keyPrefix-status-${source.invoiceId}'),
            style: muted,
          ),
          trailing: full == null
              ? null
              : IconButton(
                  key: ValueKey('$keyPrefix-pdf-${source.invoiceId}'),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: l10n?.settlementSourcePdf ?? 'PDF (regrouped)',
                  onPressed: () => downloadInvoicePdf(context, ref, full!),
                ),
        ),
      ),
    );
  }
}

class OpenInvoiceCard extends StatelessWidget {
  const OpenInvoiceCard({
    super.key,
    required this.entry,
    required this.journey,
    required this.currency,
    required this.dateFormat,
    required this.now,
    required this.actions,
  });

  final OpenInvoiceEntry entry;
  final InvoiceJourney journey;
  final MoneyFormat currency;
  final DateFormat dateFormat;
  final DateTime now;
  final OpenInvoiceActions actions;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final invoice = entry.invoice;
    final id = invoice.id;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final days = now.difference(invoice.issuedAt).inDays;
    final due = journey.reminderDue;

    // ── The actions, by move ─────────────────────────────────────────
    // The move names ONE expected action; it gets the label. Everything
    // else the lifecycle still permits stays an icon with a tooltip.
    final primary = switch (journey.move) {
      InvoiceMove.issuerRefunds => _Primary(
          key: 'invoice-refund-$id',
          icon: Icons.currency_exchange,
          label: l10n?.invoiceRefundButton ?? 'Record the refund',
          onPressed: () => actions.onRefund(entry),
        ),
      InvoiceMove.issuerMatchesPayment => _Primary(
          key: 'invoice-match-$id',
          icon: Icons.price_check_outlined,
          label: l10n?.invoiceMatchAction ?? 'Mark as paid',
          onPressed: () => actions.onMatch(entry),
        ),
      InvoiceMove.adminConfirmsPayment => _Primary(
          key: 'invoice-events-$id',
          icon: Icons.how_to_vote_outlined,
          label: l10n?.journeyPrimaryConfirmInEvents ?? 'Open Events',
          onPressed: () => actions.onEvents(entry),
        ),
      InvoiceMove.memberPays ||
      InvoiceMove.memberPaysRemainder when due != null =>
        _Primary(
          key: 'invoice-remind-$id',
          icon: Icons.notification_important,
          label: l10n?.journeyPrimaryRemind(due) ?? 'Send reminder $due',
          onPressed: () => actions.onRemind(entry),
        ),
      _ => null,
    };
    final creditNote = invoice.totalCents < 0;
    final standingPartial =
        entry.pendingMatch != null && !entry.pendingMatch!.pending;
    final pendingMatch = entry.pendingMatch != null && entry.pendingMatch!.pending;

    Widget icon({
      required String key,
      required IconData icon,
      required String tooltip,
      required VoidCallback onPressed,
      Color? color,
      bool tonal = false,
    }) =>
        tonal
            ? IconButton.filledTonal(
                key: ValueKey(key),
                tooltip: tooltip,
                icon: Icon(icon, color: color),
                onPressed: onPressed,
              )
            : IconButton(
                key: ValueKey(key),
                tooltip: tooltip,
                icon: Icon(icon, color: color),
                onPressed: onPressed,
              );
    bool isPrimary(String key) => primary?.key == key;

    final secondary = <Widget>[
      if (!standingPartial && !pendingMatch)
        icon(
          key: 'invoice-void-open-$id',
          icon: Icons.block_outlined,
          tooltip: l10n?.invoiceVoidAction ?? 'Mark erroneous',
          onPressed: () => actions.onVoid(entry),
        ),
      if (!creditNote && !standingPartial && !pendingMatch)
        icon(
          key: 'invoice-proforma-$id',
          icon: Icons.description_outlined,
          tooltip: l10n?.invoiceProformaAction ?? 'Proforma invoice',
          onPressed: () => actions.onProforma(entry),
        ),
      if (!creditNote && !pendingMatch && !isPrimary('invoice-remind-$id'))
        icon(
          key: 'invoice-remind-$id',
          icon: Icons.notifications_outlined,
          tooltip: l10n?.invoiceRemindAction ?? 'Send a reminder',
          onPressed: () => actions.onRemind(entry),
        ),
      if (!creditNote && !pendingMatch && !isPrimary('invoice-match-$id'))
        icon(
          key: 'invoice-match-$id',
          icon: Icons.price_check_outlined,
          tooltip: l10n?.invoiceMatchAction ?? 'Mark as paid',
          onPressed: () => actions.onMatch(entry),
          tonal: primary == null,
        ),
      if (standingPartial)
        if (journey.facts.writeoffPending)
          Chip(
            key: ValueKey('invoice-writeoff-pending-$id'),
            avatar: const Icon(Icons.how_to_vote_outlined, size: 18),
            label: Text(
              l10n?.invoiceMatchPendingBadge ?? 'Awaiting validation',
            ),
          )
        else
          icon(
            key: 'invoice-writeoff-$id',
            icon: Icons.money_off_csred_outlined,
            tooltip: l10n?.invoiceWriteoffButton ?? 'Cancel outstanding amount',
            onPressed: () => actions.onWriteoff(entry),
          ),
      if (creditNote && !isPrimary('invoice-refund-$id'))
        icon(
          key: 'invoice-refund-$id',
          icon: Icons.currency_exchange,
          tooltip: l10n?.invoiceRefundButton ?? 'Record the refund',
          onPressed: () => actions.onRefund(entry),
          tonal: true,
        ),
      if (pendingMatch)
        Chip(
          key: ValueKey('invoice-match-pending-$id'),
          avatar: const Icon(Icons.how_to_vote_outlined, size: 18),
          label: Text(
            l10n?.invoiceMatchPendingBadge ?? 'Awaiting validation',
          ),
        ),
    ];

    // The figure the move is about, beside the actions: what is left on
    // a partial, what the workspace pays back on a credit note.
    final figure = creditNote
        ? '${l10n?.invoiceRefundLabel ?? 'To refund'}: '
            '${currency.formatMinor(-invoice.totalCents)}'
        : standingPartial
            ? '${l10n?.invoiceRemainingLabel ?? 'Remaining'}: '
                '${currency.formatMinor(journey.remainingCents)}'
            : null;

    return Card(
      child: InkWell(
        onTap: () => actions.onOpen(entry),
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.xs,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    '${invoice.number} · ${invoice.memberName}',
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                Text(
                  currency.formatMinor(invoice.totalCents),
                  style: theme.textTheme.titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ]),
              const SizedBox(height: AppSpacing.xs),
              Padding(
                padding: const EdgeInsets.only(right: AppSpacing.sm),
                child: InvoiceJourneyBar(journey: journey),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text.rich(
                TextSpan(style: muted, children: [
                  TextSpan(text: dateFormat.format(invoice.issuedAt)),
                  const TextSpan(text: ' · '),
                  TextSpan(text: l10n?.invoiceOpenAge(days) ?? '${days}d'),
                  if (journey.reminderCount > 0) ...[
                    const TextSpan(text: ' · '),
                    TextSpan(
                      text: l10n?.invoiceRemindedBadge(journey.reminderCount) ??
                          'Reminded ×${journey.reminderCount}',
                    ),
                  ],
                ]),
              ),
              const SizedBox(height: AppSpacing.xs),
              InvoiceMoveLine(
                journey: journey,
                invoice: invoice,
                match: entry.pendingMatch,
                issuer: true,
              ),
              if (due != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  child: Chip(
                    key: ValueKey('invoice-dunning-due-$id'),
                    visualDensity: VisualDensity.compact,
                    avatar: Icon(
                      Icons.notification_important,
                      size: 18,
                      color: theme.colorScheme.error,
                    ),
                    label: Text(
                      l10n?.dunningDueChip(due) ?? 'Reminder $due due',
                    ),
                  ),
                ),
              Row(children: [
                if (figure != null)
                  Expanded(
                    child: Text(
                      figure,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: creditNote
                            ? theme.colorScheme.tertiary
                            : theme.colorScheme.error,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                ...secondary,
                if (primary != null)
                  Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.xs),
                    child: FilledButton.icon(
                      key: ValueKey(primary.key),
                      onPressed: primary.onPressed,
                      icon: Icon(primary.icon, size: 18),
                      label: Text(primary.label),
                    ),
                  ),
              ]),
            ],
          ),
        ),
      ),
    );
  }
}

class _Primary {
  const _Primary({
    required this.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final String key;
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}
