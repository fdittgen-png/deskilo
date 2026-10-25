// SPDX-License-Identifier: AGPL-3.0-or-later
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/workspace_feature.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/open_invoice_rows.dart';
import '../../domain/dunning.dart';
import '../../providers/money_providers.dart';
import 'open_invoice_act_view.dart';
import 'open_invoice_card.dart';
import 'open_invoice_subtitle.dart';

/// OPEN: issued invoices whose month still carries a positive LIVE
/// solde — with age, reminder history and a direct Remind button.
class OpenInvoicesTab extends ConsumerWidget {
  const OpenInvoicesTab({
    super.key,
    required this.currency,
    required this.onOpen,
    required this.onRemind,
    required this.onMatch,
    required this.onWriteoff,
    required this.onRefund,
    required this.onVoid,
    required this.onProforma,
    this.onEvents,
  });

  final MoneyFormat currency;

  /// #812 — the move "another admin confirms the declared payment"
  /// points at the Events tab.
  final void Function(OpenInvoiceEntry entry)? onEvents;

  /// Reading the document: the same detail sheet the archive opens.
  final void Function(OpenInvoiceEntry entry) onOpen;

  final void Function(OpenInvoiceEntry entry) onRemind;

  /// Opens the match dialog (0067): the ONLY way an invoice closes.
  final void Function(OpenInvoiceEntry entry) onMatch;

  /// #504 — request the validated write-off of the remainder.
  final void Function(OpenInvoiceEntry entry) onWriteoff;

  /// #508 — record the refund the workspace paid on a credit note.
  final void Function(OpenInvoiceEntry entry) onRefund;

  /// Tags the OPEN invoice erronée so it can be corrected (0068 field
  /// decision: en-cours invoices are cancellable; PAID ones are not).
  final void Function(OpenInvoiceEntry entry) onVoid;

  /// Re-renders the issued invoice as a PROFORMA payment request — same
  /// figures, no signature, and stamped so it cannot pass for the
  /// original.
  final void Function(OpenInvoiceEntry entry) onProforma;

  OpenInvoiceActions get _actions => (
        onOpen: onOpen,
        onRemind: onRemind,
        onMatch: onMatch,
        onWriteoff: onWriteoff,
        onRefund: onRefund,
        onVoid: onVoid,
        onProforma: onProforma,
        onEvents: onEvents ?? (_) {},
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final overview = ref.watch(invoicingOverviewProvider).value;
    final reminders =
        ref.watch(invoiceRemindersProvider).value ??
            const <String, ({int count, DateTime last})>{};
    // Mahnwesen (#472): the rules say when a reminder is DUE — the card
    // flags it and the bell icon fills. A human still sends.
    final dunningOn = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.dunning);
    // #504 — write-offs already filed and awaiting their quorum.
    final pendingWriteoffs = OpenInvoiceRows.pendingWriteoffs(
        ref.watch(eventsProvider).value ?? const []);
    final dunning =
        ref.watch(dunningRulesProvider).value ?? DunningRules.defaults;
    if (overview == null) return const LoadingView();
    if (overview.open.isEmpty) {
      return EmptyState(
        icon: Icons.price_check_outlined,
        title: l10n.invoiceNoOpen,
      );
    }
    // #812 — the process view: journey bar, next move, labelled action.
    if (ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.invoiceJourney)) {
      return OpenInvoiceJourneyList(
        entries: overview.open,
        currency: currency,
        actions: _actions,
      );
    }
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    // One instant for the whole list, not one clock read per row.
    final now = ref.read(clockProvider).now();
    final rows = OpenInvoiceRows.of(
      overview.open,
      dueLevels: OpenInvoiceRows.dueLevels(
        overview.open,
        dunningOn: dunningOn,
        reminders: reminders,
        rules: dunning,
        now: now,
      ),
      pendingWriteoffs: pendingWriteoffs,
    );
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        for (final row in rows)
          _OpenInvoiceRowCard(
            row: row,
            currency: currency,
            actions: _actions,
            subtitle: openInvoiceSubtitle(
                context, l10n, row.entry, reminders, dateFormat, now),
          ),
      ],
    );
  }

}

/// One card of the classic Open list: the invoice, its age and reminders,
/// the due dunning level, and the actions its standing allows.
class _OpenInvoiceRowCard extends StatelessWidget {
  const _OpenInvoiceRowCard({
    required this.row,
    required this.currency,
    required this.actions,
    required this.subtitle,
  });

  final OpenInvoiceRow row;
  final MoneyFormat currency;
  final OpenInvoiceActions actions;
  final Widget subtitle;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entry = row.entry;
    final id = entry.invoice.id;
    return Card(
      key: ValueKey('invoice-open-$id'),
      child: InkWell(
        key: ValueKey('invoice-open-tap-$id'),
        // The card reads the invoice; the buttons act on it.
        onTap: () => actions.onOpen(entry),
        borderRadius: AppRadius.lgAll,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Expanded(
                  child: Text(
                    '${entry.invoice.number} · '
                    '${entry.invoice.memberName}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Text(
                  currency.formatMinor(entry.invoice.totalCents),
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ]),
              const SizedBox(height: 2),
              subtitle,
              if (row.dueLevel case final int dueLevel)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Chip(
                      key: ValueKey('invoice-dunning-due-$id'),
                      visualDensity: VisualDensity.compact,
                      avatar: Icon(Icons.notification_important,
                          size: 18,
                          color: Theme.of(context).colorScheme.error),
                      label: Text(l10n.dunningDueChip(dueLevel)),
                    ),
                  ),
                ),
              _actionsRow(context, l10n),
            ],
          ),
        ),
      ),
    );
  }

  /// #508 — a credit note is refunded, never reminded; #504 — a standing
  /// partial match is reminded or written off; a pending match only
  /// waits. Icons, not sentences: three localized labels side by side
  /// ran off the card on a phone (field report). Every one keeps its
  /// tooltip, and the card itself opens the invoice where the actions
  /// are spelled out.
  Widget _actionsRow(BuildContext context, AppLocalizations l10n) {
    if (row.standing == OpenInvoiceStanding.matchPending) {
      return Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: OpenInvoiceActView(
                  OpenInvoiceAct.matchPending, row.entry, actions)
              .chip(l10n),
        ),
      );
    }
    final scheme = Theme.of(context).colorScheme;
    final figure = row.figureCents;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (figure != null)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Text(
              '${row.standing == OpenInvoiceStanding.creditNote ? l10n.invoiceRefundLabel : l10n.invoiceRemainingLabel}: '
              '${currency.formatMinor(figure)}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: row.standing == OpenInvoiceStanding.creditNote
                      ? scheme.tertiary
                      : scheme.error),
            ),
          ),
        for (final choice in row.acts) _button(choice, l10n, scheme),
      ],
    );
  }

  Widget _button(
      OpenInvoiceActChoice choice, AppLocalizations l10n, ColorScheme scheme) {
    final view = OpenInvoiceActView(choice.act, row.entry, actions);
    final chip = view.chip(l10n);
    if (chip != null) return chip;
    // Filled + error tone while a level is due (#472) — the suggested
    // action stands out.
    final due = choice.act == OpenInvoiceAct.remind && row.reminderDue;
    final icon = Icon(
      due ? Icons.notification_important : view.icon,
      color: due ? scheme.error : null,
    );
    return choice.tonal
        ? IconButton.filledTonal(
            key: ValueKey(view.key),
            tooltip: view.label(l10n),
            icon: icon,
            onPressed: view.onPressed,
          )
        : IconButton(
            key: ValueKey(view.key),
            tooltip: view.label(l10n),
            icon: icon,
            onPressed: view.onPressed,
          );
  }
}
