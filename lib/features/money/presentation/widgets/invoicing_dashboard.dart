// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/empty_state.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/format/cents.dart';
import '../../providers/money_providers.dart';

/// The issuer's invoicing summary strip (field request: "everything an
/// invoicing tool would need"): how many months wait to be invoiced
/// and how much is outstanding, at a glance.
class InvoicingSummaryBar extends ConsumerWidget {
  const InvoicingSummaryBar({super.key, required this.currency});

  final NumberFormat currency;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final overview = ref.watch(invoicingOverviewProvider).value;
    if (overview == null) return const SizedBox.shrink();
    final outstanding =
        overview.open.fold(0, (sum, e) => sum + e.invoice.totalCents);
    final parts = <String>[
      if (overview.toInvoice.isNotEmpty)
        l10n?.invoiceSummaryToInvoice(overview.toInvoice.length) ??
            '${overview.toInvoice.length} to invoice',
      if (overview.open.isNotEmpty)
        l10n?.invoiceSummaryOpen(
              overview.open.length,
              currency.format(outstanding / 100),
            ) ??
            '${overview.open.length} open · '
                '${currency.format(outstanding / 100)} outstanding',
    ];
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Text(
        parts.join('   ·   '),
        key: const ValueKey('invoicing-summary'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w600,
            ),
      ),
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
  });

  final NumberFormat currency;
  final void Function(String memberId, String period) onIssue;
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
    final monthLabel = _monthLabel(context, overview.period);
    return ListView(
      padding: AppSpacing.mdAll,
      children: [
        Row(children: [
          Expanded(
            child: Text(
              monthLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          FilledButton.tonalIcon(
            key: const ValueKey('invoice-issue-all'),
            onPressed: () =>
                onIssueAll(overview.toInvoice, overview.period),
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
              trailing: FilledButton(
                key: ValueKey('invoice-issue-${entry.memberId}'),
                onPressed: () => onIssue(entry.memberId, overview.period),
                child: Text(l10n?.invoiceIssueOne ?? 'Issue'),
              ),
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
    required this.onRemind,
    required this.onMatch,
  });

  final NumberFormat currency;
  final void Function(OpenInvoiceEntry entry) onRemind;

  /// Opens the match dialog (0067): the ONLY way an invoice closes.
  final void Function(OpenInvoiceEntry entry) onMatch;

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
                  Text(
                    [
                      dateFormat.format(entry.invoice.issuedAt),
                      l10n?.invoiceOpenAge(DateTime.now()
                              .difference(entry.invoice.issuedAt)
                              .inDays) ??
                          '${DateTime.now().difference(entry.invoice.issuedAt).inDays}d',
                      if (reminders[entry.invoice.id] != null)
                        l10n?.invoiceRemindedBadge(
                                reminders[entry.invoice.id]!.count) ??
                            'Reminded ×'
                                '${reminders[entry.invoice.id]!.count}',
                    ].join(' · '),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          key: ValueKey(
                              'invoice-remind-${entry.invoice.id}'),
                          onPressed: () => onRemind(entry),
                          child: Text(l10n?.invoiceRemindAction ??
                              'Send a reminder'),
                        ),
                        FilledButton.tonal(
                          key:
                              ValueKey('invoice-match-${entry.invoice.id}'),
                          onPressed: () => onMatch(entry),
                          child: Text(
                              l10n?.invoiceMatchAction ?? 'Mark as paid'),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

String _monthLabel(BuildContext context, String period) {
  final parts = period.split('-');
  return DateFormat.yMMMM(
    Localizations.maybeLocaleOf(context)?.toString(),
  ).format(DateTime(int.parse(parts[0]), int.parse(parts[1])));
}

/// What the match dialog returns (0067).
typedef MatchChoice = ({int paidCents, String resolution, String note});

/// The payment-match dialog: amount received + the resolution the
/// difference demands — exact, overpaid (forced with a mandatory note
/// OR a credit note over the excess), underpaid accepted with a
/// mandatory note.
class MatchInvoiceDialog extends StatefulWidget {
  const MatchInvoiceDialog({
    super.key,
    required this.dueCents,
    required this.currency,
  });

  final int dueCents;
  final NumberFormat currency;

  @override
  State<MatchInvoiceDialog> createState() => _MatchInvoiceDialogState();
}

class _MatchInvoiceDialogState extends State<MatchInvoiceDialog> {
  late final _amount =
      TextEditingController(text: centsToMajor(widget.dueCents));
  final _note = TextEditingController();
  String _overResolution = 'over_credit_note';
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  int? get _paidCents => parseCentsInput(_amount.text);

  void _submit() {
    final l10n = AppLocalizations.of(context);
    final paid = _paidCents;
    if (paid == null) return;
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
      paidCents: paid,
      resolution: resolution,
      note: _note.text.trim(),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final paid = _paidCents;
    final over = paid != null && paid > widget.dueCents;
    final under = paid != null && paid < widget.dueCents;
    return AlertDialog(
      title: Text(l10n?.invoiceMatchAction ?? 'Mark as paid'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              key: const ValueKey('invoice-match-amount'),
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText:
                    l10n?.invoiceMatchAmountLabel ?? 'Amount received',
              ),
              onChanged: (_) => setState(() => _error = null),
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
          onPressed: paid == null ? null : _submit,
          child: Text(l10n?.invoiceMatchAction ?? 'Mark as paid'),
        ),
      ],
    );
  }
}
