// SPDX-License-Identifier: AGPL-3.0-or-later
part of 'invoicing_dashboard.dart';


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
    final pendingWriteoffs = {
      for (final event in ref.watch(eventsProvider).value ?? const <WorkspaceEvent>[])
        if (event.isPending && event.type == EventType.invoiceWriteoff)
          event.payload['invoice_id'] as String? ?? '',
    };
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
        actions: (
          onOpen: onOpen,
          onRemind: onRemind,
          onMatch: onMatch,
          onWriteoff: onWriteoff,
          onRefund: onRefund,
          onVoid: onVoid,
          onProforma: onProforma,
          onEvents: onEvents ?? (_) {},
        ),
      );
    }
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    // One instant for the whole list, not one clock read per row.
    final now = ref.read(clockProvider).now();
    final dueLevels = !dunningOn
        ? const <String, int>{}
        : {
      for (final e in overview.open)
        // #508 — a credit note owes the MEMBER nothing; never remind.
        if (e.invoice.totalCents > 0)
          e.invoice.id: dueReminderLevel(
          dueOn: e.invoice.dueOn,
          issuedAt: e.invoice.issuedAt,
          reminderCount: reminders[e.invoice.id]?.count ?? 0,
          lastReminderAt: reminders[e.invoice.id]?.last,
          rules: dunning,
          now: now,
        ),
    };
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        for (final entry in overview.open)
          Card(
            key: ValueKey('invoice-open-${entry.invoice.id}'),
            child: InkWell(
              key: ValueKey('invoice-open-tap-${entry.invoice.id}'),
              // The card reads the invoice; the buttons act on it.
              onTap: () => onOpen(entry),
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
                  openInvoiceSubtitle(
                      context, l10n, entry, reminders, dateFormat, now),
                  if (dueLevels[entry.invoice.id]
                      case final int dueLevel)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding:
                            const EdgeInsets.symmetric(vertical: 4),
                        child: Chip(
                          key: ValueKey(
                              'invoice-dunning-due-${entry.invoice.id}'),
                          visualDensity: VisualDensity.compact,
                          avatar: Icon(Icons.notification_important,
                              size: 18,
                              color:
                                  Theme.of(context).colorScheme.error),
                          label: Text(
                            l10n.dunningDueChip(dueLevel),
                          ),
                        ),
                      ),
                    ),
                  if (entry.invoice.totalCents < 0 &&
                      entry.pendingMatch == null)
                    // #508 — a NEGATIVE document is a credit note the
                    // WORKSPACE pays: no reminders, no member-payment
                    // matching — record the refund.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${l10n.invoiceRefundLabel}: '
                            '${currency.formatMinor(-entry.invoice.totalCents)}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .tertiary),
                          ),
                        ),
                        IconButton(
                          key: ValueKey(
                              'invoice-void-open-${entry.invoice.id}'),
                          tooltip: l10n.invoiceVoidAction,
                          icon: const Icon(Icons.block_outlined),
                          onPressed: () => onVoid(entry),
                        ),
                        IconButton.filledTonal(
                          key: ValueKey(
                              'invoice-refund-${entry.invoice.id}'),
                          tooltip: l10n.invoiceRefundButton,
                          icon: const Icon(Icons.currency_exchange),
                          onPressed: () => onRefund(entry),
                        ),
                      ],
                    )
                  else if (entry.pendingMatch != null &&
                      !entry.pendingMatch!.pending)
                    // #504 — STANDING partial match: the remainder is
                    // still owed. Remind, or request the validated
                    // write-off; nothing else applies to a matched
                    // invoice.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            '${l10n.invoiceRemainingLabel}: '
                            '${currency.formatMinor(entry.invoice.totalCents - entry.pendingMatch!.paidCents)}',
                            style: Theme.of(context)
                                .textTheme
                                .labelMedium
                                ?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .error),
                          ),
                        ),
                        IconButton(
                          key: ValueKey(
                              'invoice-remind-${entry.invoice.id}'),
                          tooltip: l10n.invoiceRemindAction,
                          icon: Icon(
                            dueLevels[entry.invoice.id] != null
                                ? Icons.notification_important
                                : Icons.notifications_outlined,
                            color: dueLevels[entry.invoice.id] != null
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                          onPressed: () => onRemind(entry),
                        ),
                        // #506 — new payments keep coming in: match
                        // them against the REMAINING amount, maybe
                        // until fully paid.
                        IconButton.filledTonal(
                          key: ValueKey(
                              'invoice-match-${entry.invoice.id}'),
                          tooltip:
                              l10n.invoiceMatchAction,
                          icon: const Icon(Icons.price_check_outlined),
                          onPressed: () => onMatch(entry),
                        ),
                        if (pendingWriteoffs
                            .contains(entry.invoice.id))
                          Chip(
                            key: ValueKey(
                                'invoice-writeoff-pending-${entry.invoice.id}'),
                            avatar: const Icon(Icons.how_to_vote_outlined,
                                size: 18),
                            label: Text(l10n.invoiceMatchPendingBadge),
                          )
                        else
                          IconButton.filledTonal(
                            key: ValueKey(
                                'invoice-writeoff-${entry.invoice.id}'),
                            tooltip: l10n.invoiceWriteoffButton,
                            icon: const Icon(
                                Icons.money_off_csred_outlined),
                            onPressed: () => onWriteoff(entry),
                          ),
                      ],
                    )
                  else if (entry.pendingMatch != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Chip(
                          key: ValueKey(
                              'invoice-match-pending-${entry.invoice.id}'),
                          avatar:
                              const Icon(Icons.how_to_vote_outlined, size: 18),
                          label: Text(l10n.invoiceMatchPendingBadge),
                        ),
                      ),
                    )
                  else
                    // Icons, not sentences: three localized labels side by
                    // side ran off the card on a phone (field report).
                    // Every one keeps its tooltip, and the card itself
                    // opens the invoice where the actions are spelled out.
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        IconButton(
                          key: ValueKey(
                              'invoice-void-open-${entry.invoice.id}'),
                          tooltip: l10n.invoiceVoidAction,
                          icon: const Icon(Icons.block_outlined),
                          onPressed: () => onVoid(entry),
                        ),
                        IconButton(
                          key: ValueKey(
                              'invoice-proforma-${entry.invoice.id}'),
                          tooltip: l10n.invoiceProformaAction,
                          icon: const Icon(Icons.description_outlined),
                          onPressed: () => onProforma(entry),
                        ),
                        IconButton(
                          key: ValueKey(
                              'invoice-remind-${entry.invoice.id}'),
                          tooltip: l10n.invoiceRemindAction,
                          // Filled + error tone while a level is due
                          // (#472) — the suggested action stands out.
                          icon: Icon(
                            dueLevels[entry.invoice.id] != null
                                ? Icons.notification_important
                                : Icons.notifications_outlined,
                            color: dueLevels[entry.invoice.id] != null
                                ? Theme.of(context).colorScheme.error
                                : null,
                          ),
                          onPressed: () => onRemind(entry),
                        ),
                        IconButton.filledTonal(
                          key:
                              ValueKey('invoice-match-${entry.invoice.id}'),
                          tooltip:
                              l10n.invoiceMatchAction,
                          icon: const Icon(Icons.price_check_outlined),
                          onPressed: () => onMatch(entry),
                        ),
                      ],
                    ),
                ],
              ),
              ),
            ),
          ),
      ],
    );
  }

}

/// What the match dialog returns (0068): the selected REGISTERED
/// payment plus the resolution its amount demands.
typedef MatchChoice = ({
  String paymentLedgerId,
  String resolution,
  String note,
});

/// The payment-match dialog (0068): the user MAPS the invoice to one
/// of the member's registered payments — confirmed ledger payment
/// credits, which is also where online payments land — never a typed
/// amount. The selected payment's amount drives the resolution: exact,
/// overpaid (forced with a mandatory note OR a credit note over the
/// excess), underpaid accepted with a mandatory note.
class MatchInvoiceDialog extends StatefulWidget {
  const MatchInvoiceDialog({
    super.key,
    required this.dueCents,
    required this.currency,
    required this.payments,
  });

  final int dueCents;
  final MoneyFormat currency;

  /// The member's not-yet-consumed registered payments.
  final List<LedgerEntry> payments;

  @override
  State<MatchInvoiceDialog> createState() => _MatchInvoiceDialogState();
}
