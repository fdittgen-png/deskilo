// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2557 C4 — Me › Finances, one document at a time. A wide window reads
// the documents as rows: document and period, issuing workspace, document
// state and payment state, amount, Open and Export. A phone reads compact
// cards: the document and its date, then workspace, state and amount, with
// Open dominant and Export beside it. Never a horizontally scrolling
// accounting table. Document state and payment state are separate facts:
// an issued invoice can be unpaid, a credit note can be refunded. Export
// writes that one document's line to a CSV file — never a payment and
// never a delivery confirmation. C5: a compact card hides its amount (the
// currency stays) until its reveal action shows it.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_radius.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../../core/theme/status_colors.dart';
import '../../../../core/ui/private_value.dart';
import '../../../../l10n/app_localizations.dart';
import '../../domain/finance_overview.dart';
import 'dev_label.dart';
import 'own_finance_export_menu.dart';

/// From this width on, the documents are rows; below it, cards.
const double _rowsMinWidth = 800;

/// The payment state, as the server derived it.
String _paymentState(AppLocalizations l10n, FinanceState state) =>
    switch (state) {
      FinanceState.open => l10n.financesStateUnpaid,
      FinanceState.awaitingValidation => l10n.financesAwaitingValidation,
      FinanceState.partiallyPaid => l10n.financesPartlyPaid,
      FinanceState.paid => l10n.financesStatePaid,
      FinanceState.refunded => l10n.financesStateRefunded,
      FinanceState.closed => l10n.financesStateClosed,
    };

/// The amount a document shows: what remains while owed, else its face.
int _shownAmount(FinanceInvoice i) =>
    i.state.owed ? i.remainingCents : i.totalCents;

/// The documents of one list, as rows or as cards by the width they get.
class FinanceDocumentList extends StatelessWidget {
  const FinanceDocumentList({
    super.key,
    required this.invoices,
    required this.documents,
    required this.now,
    required this.onOpen,
    this.isDev = false,
  });

  final List<FinanceInvoice> invoices;

  /// Opens a document in its own workspace (the screen decides how).
  final ValueChanged<FinanceInvoice> onOpen;

  /// The overview the documents come from: a document's Export carries its
  /// coverage (a host that did not answer is noted inside the file).
  final FinanceOverview documents;
  final DateTime now;

  /// Development documents: tinted and labelled DEV.
  final bool isDev;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final wide = box.maxWidth >= _rowsMinWidth;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (wide && invoices.isNotEmpty) const _RowsHeader(),
          // Keyed by the qualified id: two hosts' equal local ids in
          // different workspaces are two documents (#2557 C5).
          for (final invoice in invoices)
            KeyedSubtree(
              key: ValueKey((invoice.workspaceId, invoice.id)),
              child: _FinanceDocument(
                invoice: invoice,
                documents: documents,
                now: now,
                isDev: isDev,
                wide: wide,
                onOpen: onOpen,
              ),
            ),
        ],
      );
    },
  );
}

class _RowsHeader extends StatelessWidget {
  const _RowsHeader();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final style = theme.textTheme.labelMedium?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );
    return Padding(
      key: const ValueKey('finances-rows-header'),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        0,
        AppSpacing.md,
        AppSpacing.sm,
      ),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(l10n.financesColumnDocument, style: style),
          ),
          Expanded(
            flex: 3,
            child: Text(l10n.financesColumnWorkspace, style: style),
          ),
          Expanded(
            flex: 4,
            child: Text(l10n.financesColumnState, style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(
              l10n.financesColumnAmount,
              textAlign: TextAlign.end,
              style: style,
            ),
          ),
          const SizedBox(width: _actionsWidth),
        ],
      ),
    );
  }
}

/// The room Open and Export take at the end of a row.
const double _actionsWidth = 200;

class _FinanceDocument extends ConsumerWidget {
  const _FinanceDocument({
    required this.invoice,
    required this.documents,
    required this.now,
    required this.isDev,
    required this.wide,
    required this.onOpen,
  });

  final FinanceInvoice invoice;
  final FinanceOverview documents;
  final DateTime now;
  final bool isDev;
  final bool wide;
  final ValueChanged<FinanceInvoice> onOpen;

  Future<void> _export(BuildContext context, WidgetRef ref) =>
      OwnFinanceExportMenu.export(
        context,
        ref,
        documents: documents.where(
          (i) => i.id == invoice.id && i.workspaceId == invoice.workspaceId,
        ),
        label: '${invoice.workspaceName} ${invoice.number}',
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final format = DateFormat.yMMMd(
      Localizations.localeOf(context).toLanguageTag(),
    );
    final overdue = invoice.overdueAt(now);
    final due = invoice.dueOn;
    final devTone = AppEnvironmentColors.developmentOf(theme.brightness);
    final muted = theme.textTheme.bodySmall?.copyWith(
      color: scheme.onSurfaceVariant,
    );
    final period = invoice.state.owed && due != null
        ? Text(
            overdue
                ? l10n.financesOverdueSince(format.format(due))
                : l10n.financesDueOn(format.format(due)),
            style: theme.textTheme.bodySmall?.copyWith(
              color: overdue ? scheme.error : scheme.onSurfaceVariant,
            ),
          )
        : Text(format.format(invoice.issuedAt.toLocal()), style: muted);
    final workspace = isDev
        ? DevLabel(name: invoice.workspaceName, small: true)
        : Text(
            invoice.workspaceName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: muted,
          );
    final states = Wrap(
      spacing: 6,
      runSpacing: 4,
      children: [
        _StateChip(
          invoice.isCreditNote
              ? l10n.financesTypeCreditNote
              : l10n.financesTypeInvoice,
        ),
        _StateChip(_paymentState(l10n, invoice.state)),
        if (invoice.reminderCount > 0 && invoice.state.owed)
          _StateChip(l10n.financesRemindedTimes(invoice.reminderCount)),
      ],
    );
    final amount = Text(
      moneyFormat(invoice.currency).formatMinor(_shownAmount(invoice)),
      textAlign: TextAlign.end,
      style: theme.textTheme.titleSmall?.strong.copyWith(
        color: overdue ? scheme.error : null,
      ),
    );
    final number = Text(
      invoice.number,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: theme.textTheme.titleSmall,
    );
    final export = IconButton(
      key: ValueKey('finances-export-${invoice.id}'),
      tooltip: l10n.financesExportDocument,
      icon: const Icon(Icons.download_outlined),
      onPressed: () => _export(context, ref),
    );
    final Widget body = wide
        ? Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [number, period],
                ),
              ),
              Expanded(flex: 3, child: workspace),
              Expanded(flex: 4, child: states),
              Expanded(flex: 2, child: amount),
              SizedBox(
                width: _actionsWidth,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    FilledButton.tonal(
                      key: ValueKey('finances-open-${invoice.id}'),
                      onPressed: () => onOpen(invoice),
                      child: Text(l10n.financesOpenDocument),
                    ),
                    export,
                  ],
                ),
              ),
            ],
          )
        : InkWell(
            key: ValueKey('finances-open-${invoice.id}'),
            onTap: () => onOpen(invoice),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                0,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        number,
                        period,
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 4),
                          child: workspace,
                        ),
                        states,
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  _CardAmount(invoice, amount),
                  export,
                ],
              ),
            ),
          );
    return Card(
      key: ValueKey('finances-invoice-${invoice.id}'),
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      clipBehavior: Clip.antiAlias,
      color: isDev ? devTone.withValues(alpha: .10) : null,
      shape: isDev
          ? RoundedRectangleBorder(
              borderRadius: AppRadius.lgAll,
              side: BorderSide(color: devTone.withValues(alpha: .55)),
            )
          : null,
      child: wide
          ? Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: body,
            )
          : body,
    );
  }
}

class _StateChip extends StatelessWidget {
  const _StateChip(this.label);

  final String label;

  @override
  Widget build(BuildContext context) =>
      Chip(label: Text(label), visualDensity: VisualDensity.compact);
}

/// #2557 C5 / #2552 XPRIV-01 — a phone is read where others can see it: a
/// compact card's amount waits to be revealed (the currency stays).
class _CardAmount extends StatelessWidget {
  const _CardAmount(this.invoice, this.amount);

  final FinanceInvoice invoice;
  final Widget amount;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PrivateValue(
      revealKey: ValueKey('finances-amount-${invoice.id}'),
      maskedText: l10n.financesAmountMasked(invoice.currency),
      hiddenLabel: l10n.financesAmountHidden,
      showLabel: l10n.financesShowAmount,
      hideLabel: l10n.financesHideAmount,
      child: amount,
    );
  }
}
