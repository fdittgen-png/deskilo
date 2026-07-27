// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/ledger_entry.dart';
import '../../providers/money_providers.dart';
import '../period_label.dart';

/// How old an open invoice has to be before the hub starts pointing at it.
const _overdueDays = 30;

/// The issuer's invoicing summary strip (field request: "everything an
/// invoicing tool would need"): how many months wait to be invoiced and
/// how much is outstanding, at a glance.
///
/// Two pills rather than one grey sentence — and the money turns red once
/// something has been waiting longer than [_overdueDays].
class InvoicingSummaryBar extends ConsumerWidget {
  const InvoicingSummaryBar({super.key, required this.currency});

  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(invoicingOverviewProvider).value;
    if (overview == null) return const SizedBox.shrink();
    if (overview.toInvoice.isEmpty && overview.open.isEmpty) {
      return const SizedBox.shrink();
    }
    final outstanding =
        overview.open.fold(0, (sum, e) => sum + e.invoice.totalCents);
    final now = DateTime.now();
    final overdue = overview.open.any(
      (e) => now.difference(e.invoice.issuedAt).inDays >= _overdueDays,
    );
    return Padding(
      key: const ValueKey('invoicing-summary'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        0,
      ),
      child: Wrap(
        spacing: AppSpacing.sm,
        runSpacing: AppSpacing.xs,
        children: [
          if (overview.toInvoice.isNotEmpty)
            _Pill(
              icon: Icons.pending_actions_outlined,
              text: l10n?.invoiceSummaryToInvoice(overview.toInvoice.length) ??
                  '${overview.toInvoice.length} to invoice',
            ),
          if (overview.open.isNotEmpty)
            _Pill(
              icon: Icons.hourglass_bottom_outlined,
              alert: overdue,
              text: l10n?.invoiceSummaryOpen(
                    overview.open.length,
                    currency.format(outstanding / 100),
                  ) ??
                  '${overview.open.length} open · '
                      '${currency.format(outstanding / 100)} outstanding',
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.text, this.alert = false});

  final IconData icon;
  final String text;
  final bool alert;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final background =
        alert ? colors.errorContainer : colors.surfaceContainerHighest;
    final foreground =
        alert ? colors.onErrorContainer : colors.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: AppRadius.xlAll,
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 16, color: foreground),
        const SizedBox(width: AppSpacing.xs),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foreground,
                fontWeight: FontWeight.w600,
              ),
        ),
      ]),
    );
  }
}

/// TO INVOICE: the previous month's uninvoiced members, each with the
/// derived total, a per-member Issue button and an Invoice-all sweep.
class ToInvoiceTab extends ConsumerWidget {
  const ToInvoiceTab({
    super.key,
    required this.currency,
    required this.onIssue,
    required this.onIssueAll,
    required this.onProforma,
  });

  final NumberFormat currency;
  final void Function(String memberId, String period) onIssue;

  /// Shares the month as a PROFORMA — what the member will owe, before
  /// anything is issued.
  final void Function(String memberId, String period) onProforma;
  final void Function(List<ToInvoiceEntry> entries, String period)
      onIssueAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overviewAsync = ref.watch(invoicingOverviewProvider);
    final overview = overviewAsync.value;
    if (overview == null) return const LoadingView();
    if (overview.toInvoice.isEmpty) {
      return EmptyState(
        icon: Icons.task_alt_outlined,
        title: l10n?.invoiceAllCaughtUp ??
            'All caught up — nothing to invoice.',
      );
    }
    final total =
        overview.toInvoice.fold(0, (sum, e) => sum + e.totalCents);
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        Row(children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monthLabel(context, overview.period),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                // What the sweep is worth, before it runs.
                Text(
                  currency.format(total / 100),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('invoice-issue-all'),
            onPressed: () => onIssueAll(overview.toInvoice, overview.period),
            icon: const Icon(Icons.playlist_add_check_outlined),
            label: Text(l10n?.invoiceIssueAll ?? 'Invoice all'),
          ),
        ]),
        const SizedBox(height: 4),
        for (final entry in overview.toInvoice)
          Card(
            child: ListTile(
              key: ValueKey('invoice-todo-${entry.memberId}'),
              title: Text(entry.name),
              subtitle: Text(currency.format(entry.totalCents / 100)),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                IconButton(
                  key: ValueKey('invoice-proforma-${entry.memberId}'),
                  tooltip: l10n?.invoiceProformaAction ?? 'Proforma invoice',
                  icon: const Icon(Icons.description_outlined),
                  onPressed: () =>
                      onProforma(entry.memberId, overview.period),
                ),
                FilledButton(
                  key: ValueKey('invoice-issue-${entry.memberId}'),
                  onPressed: () => onIssue(entry.memberId, overview.period),
                  child: Text(l10n?.invoiceIssueOne ?? 'Issue'),
                ),
              ]),
            ),
          ),
      ],
    );
  }
}

/// OPEN: issued invoices whose month still carries a positive LIVE
/// solde — with age, reminder history and a direct Remind button.
class OpenInvoicesTab extends ConsumerWidget {
  const OpenInvoicesTab({
    super.key,
    required this.currency,
    required this.onOpen,
    required this.onRemind,
    required this.onMatch,
    required this.onVoid,
    required this.onProforma,
  });

  final NumberFormat currency;

  /// Reading the document: the same detail sheet the archive opens.
  final void Function(OpenInvoiceEntry entry) onOpen;

  final void Function(OpenInvoiceEntry entry) onRemind;

  /// Opens the match dialog (0067): the ONLY way an invoice closes.
  final void Function(OpenInvoiceEntry entry) onMatch;

  /// Tags the OPEN invoice erronée so it can be corrected (0068 field
  /// decision: en-cours invoices are cancellable; PAID ones are not).
  final void Function(OpenInvoiceEntry entry) onVoid;

  /// Re-renders the issued invoice as a PROFORMA payment request — same
  /// figures, no signature, and stamped so it cannot pass for the
  /// original.
  final void Function(OpenInvoiceEntry entry) onProforma;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(invoicingOverviewProvider).value;
    final reminders =
        ref.watch(invoiceRemindersProvider).value ?? const {};
    if (overview == null) return const LoadingView();
    if (overview.open.isEmpty) {
      return EmptyState(
        icon: Icons.price_check_outlined,
        title: l10n?.invoiceNoOpen ?? 'No open invoices.',
      );
    }
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        for (final entry in overview.open)
          Card(
            key: ValueKey('invoice-open-${entry.invoice.id}'),
            child: InkWell(
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
                      currency.format(entry.invoice.totalCents / 100),
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ]),
                  const SizedBox(height: 2),
                  _openSubtitle(context, l10n, entry, reminders, dateFormat),
                  if (entry.pendingMatch != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Chip(
                          key: ValueKey(
                              'invoice-match-pending-${entry.invoice.id}'),
                          avatar:
                              const Icon(Icons.how_to_vote_outlined, size: 18),
                          label: Text(l10n?.invoiceMatchPendingBadge ??
                              'Awaiting validation'),
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
                          tooltip: l10n?.invoiceVoidAction ??
                              'Mark erroneous',
                          icon: const Icon(Icons.block_outlined),
                          onPressed: () => onVoid(entry),
                        ),
                        IconButton(
                          key: ValueKey(
                              'invoice-proforma-${entry.invoice.id}'),
                          tooltip: l10n?.invoiceProformaAction ??
                              'Proforma invoice',
                          icon: const Icon(Icons.description_outlined),
                          onPressed: () => onProforma(entry),
                        ),
                        IconButton(
                          key: ValueKey(
                              'invoice-remind-${entry.invoice.id}'),
                          tooltip: l10n?.invoiceRemindAction ??
                              'Send a reminder',
                          icon: const Icon(Icons.notifications_outlined),
                          onPressed: () => onRemind(entry),
                        ),
                        IconButton.filledTonal(
                          key:
                              ValueKey('invoice-match-${entry.invoice.id}'),
                          tooltip:
                              l10n?.invoiceMatchAction ?? 'Mark as paid',
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

  /// Issue date · age · reminders — with the AGE in error colors once the
  /// invoice has been waiting too long, so a collections list can be read
  /// at a glance instead of parsed word by word.
  Widget _openSubtitle(
    BuildContext context,
    AppLocalizations? l10n,
    OpenInvoiceEntry entry,
    Map<String, ({int count, DateTime last})> reminders,
    DateFormat dateFormat,
  ) {
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    final days = DateTime.now().difference(entry.invoice.issuedAt).inDays;
    final reminder = reminders[entry.invoice.id];
    return Text.rich(
      TextSpan(style: muted, children: [
        TextSpan(text: dateFormat.format(entry.invoice.issuedAt)),
        const TextSpan(text: ' · '),
        TextSpan(
          text: l10n?.invoiceOpenAge(days) ?? '${days}d',
          style: days >= _overdueDays
              ? muted?.copyWith(
                  color: theme.colorScheme.error,
                  fontWeight: FontWeight.bold,
                )
              : null,
        ),
        if (reminder != null) ...[
          const TextSpan(text: ' · '),
          TextSpan(
            text: l10n?.invoiceRemindedBadge(reminder.count) ??
                'Reminded ×${reminder.count}',
          ),
        ],
      ]),
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
  final NumberFormat currency;

  /// The member's not-yet-consumed registered payments.
  final List<LedgerEntry> payments;

  @override
  State<MatchInvoiceDialog> createState() => _MatchInvoiceDialogState();
}

class _MatchInvoiceDialogState extends State<MatchInvoiceDialog> {
  final _note = TextEditingController();
  String? _paymentId;
  String _overResolution = 'over_credit_note';
  String? _error;

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  LedgerEntry? get _payment => widget.payments
      .where((entry) => entry.id == _paymentId)
      .firstOrNull;

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final payment = _payment;
    if (payment == null) return;
    final paid = payment.amountCents;
    final resolution = paid == widget.dueCents
        ? 'exact'
        : paid > widget.dueCents
            ? _overResolution
            : 'under_accepted';
    final noteRequired =
        resolution == 'over_forced' || resolution == 'under_accepted';
    if (noteRequired && _note.text.trim().isEmpty) {
      setState(() =>
          _error = l10n?.invoiceMatchNoteRequired ?? 'A note is required.');
      return;
    }
    Navigator.of(context).pop<MatchChoice>((
      paymentLedgerId: payment.id,
      resolution: resolution,
      note: _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final dateFormat = DateFormat.yMMMd(
      Localizations.maybeLocaleOf(context)?.toString(),
    );
    final payment = _payment;
    final paid = payment?.amountCents;
    final over = paid != null && paid > widget.dueCents;
    final under = paid != null && paid < widget.dueCents;
    return AlertDialog(
      title: Text(l10n?.invoiceMatchAction ?? 'Mark as paid'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n?.invoiceMatchPickPayment ??
                  'Select the registered payment',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            if (widget.payments.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  l10n?.invoiceMatchNoPayments ??
                      'No registered payment to match — record or '
                          'confirm it first.',
                  key: const ValueKey('invoice-match-no-payments'),
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              RadioGroup<String>(
                groupValue: _paymentId,
                onChanged: (value) => setState(() {
                  _paymentId = value;
                  _error = null;
                }),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in widget.payments)
                      RadioListTile<String>(
                        key: ValueKey('invoice-match-payment-${entry.id}'),
                        value: entry.id,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(
                          '${widget.currency.format(entry.amountCents / 100)}'
                          ' · ${dateFormat.format(entry.on)}'
                          '${entry.description.isEmpty ? '' : ' · ${entry.description}'}',
                        ),
                      ),
                  ],
                ),
              ),
            if (over) ...[
              const SizedBox(height: 8),
              Text(
                l10n?.invoiceMatchOver(widget.currency
                        .format((paid - widget.dueCents) / 100)) ??
                    'The member paid '
                        '${widget.currency.format((paid - widget.dueCents) / 100)}'
                        ' more.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              RadioGroup<String>(
                groupValue: _overResolution,
                onChanged: (v) =>
                    setState(() => _overResolution = v ?? _overResolution),
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  RadioListTile<String>(
                    key: const ValueKey('invoice-match-credit-note'),
                    value: 'over_credit_note',
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n?.invoiceMatchCreditNote ??
                        'Create a credit note for the excess'),
                  ),
                  RadioListTile<String>(
                    key: const ValueKey('invoice-match-force'),
                    value: 'over_forced',
                    contentPadding: EdgeInsets.zero,
                    title: Text(l10n?.invoiceMatchForce ??
                        'Accept anyway (note why)'),
                  ),
                ]),
              ),
            ],
            if (under) ...[
              const SizedBox(height: 8),
              Text(
                l10n?.invoiceMatchUnder(widget.currency
                        .format((widget.dueCents - paid) / 100)) ??
                    'The member paid '
                        '${widget.currency.format((widget.dueCents - paid) / 100)}'
                        ' less — accepting requires a note.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('invoice-match-note'),
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l10n?.invoiceMatchNoteLabel ?? 'Note',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.commonCancel ?? 'Cancel'),
        ),
        FilledButton(
          key: const ValueKey('invoice-match-confirm'),
          onPressed: payment == null ? null : _submit,
          child: Text(l10n?.invoiceMatchAction ?? 'Mark as paid'),
        ),
      ],
    );
  }
}
