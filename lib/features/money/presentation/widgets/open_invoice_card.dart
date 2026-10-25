// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/open_invoice_rows.dart';
import '../../domain/accounting_view.dart';
import '../../domain/billing_rules.dart';
import '../../domain/dunning.dart';
import '../../domain/invoice.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart';
import '../invoice_journey.dart';
import 'invoice_journey_view.dart';
import 'open_invoice_act_view.dart';

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
    final l10n = context.l10n;
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
                ? (l10n.settlementPaidThrough(settlement.number))
                : (l10n.settlementFoldedIn(settlement.number)),
            key: ValueKey('$keyPrefix-status-${source.invoiceId}'),
            style: muted,
          ),
          trailing: full == null
              ? null
              : IconButton(
                  key: ValueKey('$keyPrefix-pdf-${source.invoiceId}'),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  tooltip: l10n.settlementSourcePdf,
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

  /// The move names ONE expected action; it gets the label (#812).
  OpenInvoiceAct? get _primary => switch (journey.move) {
        InvoiceMove.issuerRefunds => OpenInvoiceAct.refund,
        InvoiceMove.issuerMatchesPayment => OpenInvoiceAct.match,
        InvoiceMove.adminConfirmsPayment => OpenInvoiceAct.confirmInEvents,
        InvoiceMove.memberPays ||
        InvoiceMove.memberPaysRemainder when journey.reminderDue != null =>
          OpenInvoiceAct.remind,
        _ => null,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final invoice = entry.invoice;
    return Card(
      child: InkWell(
        key: const ValueKey('open-invoice-card-invoice-open-age'),
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
                    // #910 — the client, company included; and no
                    // separator hanging off a name nobody has.
                    [invoice.number, invoice.clientName]
                        .where((p) => p.isNotEmpty)
                        .join(' · '),
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
              ..._standing(context),
              _actionRow(context),
            ],
          ),
        ),
      ),
    );
  }

  /// The age line, the next move and the due dunning level.
  List<Widget> _standing(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final invoice = entry.invoice;
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final days = now.difference(invoice.issuedAt).inDays;
    final due = journey.reminderDue;
    return [
      Text.rich(
        TextSpan(style: muted, children: [
          TextSpan(text: dateFormat.format(invoice.issuedAt)),
          const TextSpan(text: ' · '),
          TextSpan(text: l10n.invoiceOpenAge(days)),
          if (journey.reminderCount > 0) ...[
            const TextSpan(text: ' · '),
            TextSpan(
              text: l10n.invoiceRemindedBadge(journey.reminderCount),
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
            key: ValueKey('invoice-dunning-due-${invoice.id}'),
            visualDensity: VisualDensity.compact,
            avatar: Icon(
              Icons.notification_important,
              size: 18,
              color: theme.colorScheme.error,
            ),
            label: Text(
              l10n.dunningDueChip(due),
            ),
          ),
        ),
    ];
  }

  /// The figure the move is about, the other actions the lifecycle still
  /// permits as icons with tooltips, and the move's labelled button.
  Widget _actionRow(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final invoice = entry.invoice;
    final primaryAct = _primary;
    final primary = primaryAct == null
        ? null
        : OpenInvoiceActView(primaryAct, entry, actions);
    final creditNote = invoice.totalCents < 0;
    final standingPartial =
        entry.pendingMatch != null && !entry.pendingMatch!.pending;
    // What is left on a partial, what the workspace pays back on a
    // credit note.
    final figure = creditNote
        ? '${l10n.invoiceRefundLabel}: '
            '${currency.formatMinor(-invoice.totalCents)}'
        : standingPartial
            ? '${l10n.invoiceRemainingLabel}: '
                '${currency.formatMinor(journey.remainingCents)}'
            : null;
    return Row(children: [
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
      for (final choice in OpenInvoiceRows.journeyActs(entry,
          primary: primaryAct,
          writeoffPending: journey.facts.writeoffPending))
        _secondary(choice, l10n),
      if (primary != null)
        Padding(
          padding: const EdgeInsets.only(left: AppSpacing.xs),
          child: FilledButton.icon(
            key: ValueKey(primary.key),
            onPressed: primary.onPressed,
            icon: Icon(
              primaryAct == OpenInvoiceAct.remind
                  ? Icons.notification_important
                  : primary.icon,
              size: 18,
            ),
            label: Text(primaryAct == OpenInvoiceAct.remind
                ? l10n.journeyPrimaryRemind(journey.reminderDue!)
                : primary.label(l10n)),
          ),
        ),
    ]);
  }

  Widget _secondary(OpenInvoiceActChoice choice, AppLocalizations l10n) {
    final view = OpenInvoiceActView(choice.act, entry, actions);
    final chip = view.chip(l10n);
    if (chip != null) return chip;
    return choice.tonal
        // The expected move is named, not guessed from an icon.
        ? FilledButton.tonalIcon(
            key: ValueKey(view.key),
            onPressed: view.onPressed,
            icon: Icon(view.icon),
            label: Text(view.label(l10n)),
          )
        : IconButton(
            key: ValueKey(view.key),
            tooltip: view.label(l10n),
            icon: Icon(view.icon),
            onPressed: view.onPressed,
          );
  }
}
