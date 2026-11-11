// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3671 (part 2) -- "Assign to invoices": one payment, several invoices. The
// head says whose money it is and what is left of it; the list holds the
// customer's open invoices, oldest due first, each with a tick and an amount
// (prefilled oldest first until the money is used up; the last may be a
// part); the running line says what stays as credit, or that the parts are
// more than what is left. A part below what is due asks for ONE note
// (prefilled, editable). The server decides (`apply_payment_to_invoices`,
// all or nothing); a refusal is said in the app's own words and the payment
// is read again, what was typed kept where it still fits.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/format/cents.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/kit/kit_action_button.dart';
import '../../../../core/ui/kit/kit_metrics.dart';
import '../../../../core/ui/loading_view.dart';
import '../../../../core/ui/task_surface.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/assign_payment_plan.dart';
import '../../application/receivables.dart';
import '../../providers/money_providers.dart';
import 'invoicing_home.dart' show InvoicingSource;
import 'invoicing_reads.dart';

/// Opens the sheet (a phone) or the dialog (the desk) for [paymentId] of
/// [customerId] in the business's [currency].
Future<void> showAssignPayment(
  BuildContext context, {
  required String paymentId,
  required String customerId,
  required String customerName,
  required String currency,
}) => showTaskSurface<void>(
  context: context,
  builder: (_) => _AssignPaymentBody(
    paymentId: paymentId,
    customerId: customerId,
    customerName: customerName,
    currency: currency,
  ),
);

/// What the call ended in, for the result lines.
typedef _Outcome = ({int full, int part, int leftCents, bool pending});

class _AssignPaymentBody extends ConsumerStatefulWidget {
  const _AssignPaymentBody({
    required this.paymentId,
    required this.customerId,
    required this.customerName,
    required this.currency,
  });

  final String paymentId;
  final String customerId;
  final String customerName;

  /// The business's currency: the payment's and its invoices'.
  final String currency;

  @override
  ConsumerState<_AssignPaymentBody> createState() => _AssignPaymentBodyState();
}

class _AssignPaymentBodyState extends ConsumerState<_AssignPaymentBody> {
  /// The amount typed per invoice id, and the rows ticked: kept across a
  /// re-read, so a refusal does not lose what the person typed.
  final _amounts = <String, TextEditingController>{};
  final _ticked = <String>{};
  TextEditingController? _noteField;
  bool _prefilled = false;
  bool _busy = false;
  PaymentRefusal? _refusal;
  _Outcome? _outcome;

  @override
  void dispose() {
    for (final c in _amounts.values) {
      c.dispose();
    }
    _noteField?.dispose();
    super.dispose();
  }

  TextEditingController _amount(String invoiceId) =>
      _amounts.putIfAbsent(invoiceId, TextEditingController.new);

  TextEditingController get _note => _noteField ??= TextEditingController(
    text: context.l10n.assignPaymentNoteDefault,
  );

  int _typed(String invoiceId) =>
      appFormatOf(context).parseMinor(_amount(invoiceId).text) ?? 0;

  /// The parts as typed: the ticked rows with an amount, in list order.
  PaymentPlan _plan(List<Receivable> rows, int left) => PaymentPlan(
    leftCents: left,
    dueCents: {for (final r in rows) r.invoiceId: r.openMinor},
    parts: [
      for (final r in rows)
        if (_ticked.contains(r.invoiceId) && _typed(r.invoiceId) > 0)
          (invoiceId: r.invoiceId, amountCents: _typed(r.invoiceId)),
    ],
  );

  void _prefill(List<Receivable> rows, int left) {
    if (_prefilled) return;
    _prefilled = true;
    final parts = prefillOldestFirst(rows, left);
    for (final MapEntry(key: id, value: cents) in parts.entries) {
      _amount(id).text = centsToMajor(cents);
      _ticked.add(id);
    }
  }

  void _tick(Receivable r, bool on, List<Receivable> rows, int left) {
    setState(() {
      if (!on) {
        _ticked.remove(r.invoiceId);
        return;
      }
      _ticked.add(r.invoiceId);
      if (_typed(r.invoiceId) <= 0) {
        final others = _plan(rows, left).parts
            .where((p) => p.invoiceId != r.invoiceId)
            .fold(0, (sum, p) => sum + p.amountCents);
        final room = left - others;
        final part = room < r.openMinor ? room : r.openMinor;
        if (part > 0) _amount(r.invoiceId).text = centsToMajor(part);
      }
    });
  }

  /// The note or an amount was edited: a typed amount ticks its row.
  void _touch([String? invoiceId]) => setState(() {
    if (invoiceId != null && _typed(invoiceId) > 0) _ticked.add(invoiceId);
  });

  Future<void> _send(PaymentPlan plan) async {
    setState(() {
      _busy = true;
      _refusal = null;
    });
    _Outcome? outcome;
    PaymentRefusal? refusal;
    try {
      final applied = await ref
          .read(invoiceCommandsProvider)
          .applyPaymentToInvoices(
            workspaceId: ref.read(invoicingBusinessProvider).id,
            paymentLedgerId: widget.paymentId,
            allocations: plan.parts,
            note: plan.hasPartial ? _note.text.trim() : '',
          );
      _readAgain();
      // A workspace that approves payments keeps the matches pending: said
      // from the matches as the server now has them.
      final matches = await ref.read(invoiceMatchesProvider.future);
      outcome = (
        full: plan.fullCount,
        part: plan.partCount,
        leftCents: applied.leftCents,
        pending: plan.parts.any((p) => matches[p.invoiceId]?.pending ?? false),
      );
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'payment assignment refused',
        error: e,
        stackTrace: st,
      );
      // The payment and the invoices are read again: what the server refused
      // over may have changed meanwhile.
      _readAgain();
      refusal = PaymentRefusal.of(e);
    }
    if (!mounted) return;
    setState(() {
      _busy = false;
      _outcome = outcome;
      _refusal = refusal;
    });
  }

  void _readAgain() => ref
    ..invalidate(invoiceMatchesProvider)
    ..invalidate(invoicesProvider)
    ..invalidate(unassignedMoneyProvider);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SheetShell(
      title: l10n.moneyRecordPayment,
      children: [
        const SizedBox(height: AppSpacing.md),
        if (_outcome case final done?)
          ..._result(context, done)
        else ...[
          if (_refusal case final why?) _refusalLine(context, why),
          ..._content(context),
        ],
      ],
    );
  }

  List<Widget> _content(BuildContext context) {
    final l10n = context.l10n;
    final money = ref.watch(unassignedMoneyProvider);
    final receivables = ref.watch(invoicingReceivablesProvider);
    final failed = ref.watch(invoicingFailedSourcesProvider);
    if (failed.isNotEmpty) return _failed(context, failed);
    final known = unassignedMoneyKnown(money);
    if (known == null || receivables == null) {
      return const [LoadingView()];
    }
    final payment = known.paymentsOf[widget.customerId]
        ?.where((p) => p.id == widget.paymentId)
        .firstOrNull;
    if (payment == null) return [_close(context)];
    final rows = invoicesToPay(
      receivables: receivables,
      customerId: widget.customerId,
      currency: widget.currency,
    );
    final format = appFormatOf(context);
    final moneyIn = format.moneyIn(widget.currency);
    final head = <Widget>[
      Text(widget.customerName, style: Theme.of(context).textTheme.titleSmall),
      Text(
        payment.isPartlyUsed
            ? l10n.assignPaymentUsedHead(
                moneyIn.formatMinor(payment.receivedCents),
                moneyIn.formatMinor(payment.assignedCents),
                moneyIn.formatMinor(payment.leftCents),
              )
            : l10n.assignPaymentReceived(
                moneyIn.formatMinor(payment.receivedCents),
              ),
      ),
      Text(
        format.date(payment.entry.on),
        style: Theme.of(context).textTheme.bodySmall,
      ),
      const FormGap(),
    ];
    if (rows.isEmpty) {
      return [
        ...head,
        Text(
          l10n.assignPaymentNoOpen,
          key: const ValueKey('assign-payment-no-open'),
        ),
        const FormGap(),
        _close(context),
      ];
    }
    _prefill(rows, payment.leftCents);
    final plan = _plan(rows, payment.leftCents);
    final note = _note;
    final canSend = plan.canSend(note: note.text) && !money.isLoading;
    return [
      ...head,
      for (final r in rows) _row(context, r, rows, plan, moneyIn),
      const FormGap.small(),
      _running(context, plan, moneyIn),
      if (plan.hasPartial) ...[
        const FormGap.small(),
        AppTextField(
          key: const ValueKey('assign-payment-note'),
          controller: note,
          label: l10n.assignPaymentNoteLabel,
          maxLines: 3,
          enabled: !_busy,
          error: note.text.trim().isEmpty
              ? l10n.invoiceMatchNoteRequired
              : null,
          onChanged: (_) => _touch(),
        ),
      ],
      const FormGap(),
      KitActionButton(
        key: const ValueKey('assign-payment-confirm'),
        label: l10n.assignPaymentAction,
        busy: _busy,
        onPressed: canSend ? () => _send(plan) : null,
      ),
    ];
  }

  Widget _row(
    BuildContext context,
    Receivable r,
    List<Receivable> rows,
    PaymentPlan plan,
    MoneyFormat moneyIn,
  ) {
    final l10n = context.l10n;
    final format = appFormatOf(context);
    final due = moneyIn.formatMinor(r.openMinor);
    final caption = r.dueOn == null
        ? l10n.assignPaymentRowCaptionNoDate(due)
        : l10n.assignPaymentRowCaption(format.date(r.dueOn!), due);
    return Padding(
      key: ValueKey('assign-payment-row-${r.invoiceId}'),
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SizedBox.square(
                dimension: KitMetrics.minTarget,
                child: Semantics(
                  label: l10n.assignPaymentTickLabel(r.number),
                  child: Checkbox(
                    key: ValueKey('assign-payment-tick-${r.invoiceId}'),
                    value: _ticked.contains(r.invoiceId),
                    onChanged: _busy
                        ? null
                        : (on) => _tick(r, on ?? false, rows, plan.leftCents),
                  ),
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r.number),
                    Text(caption, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
          Semantics(
            label: l10n.assignPaymentAmountLabel(r.number),
            child: AppTextField(
              key: ValueKey('assign-payment-amount-${r.invoiceId}'),
              controller: _amount(r.invoiceId),
              label: l10n.assignPaymentAmountLabel(r.number),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: !_busy,
              error: plan.overDue.contains(r.invoiceId)
                  ? l10n.assignPaymentRowOver
                  : null,
              onChanged: (_) => _touch(r.invoiceId),
            ),
          ),
        ],
      ),
    );
  }

  Widget _running(BuildContext context, PaymentPlan plan, MoneyFormat moneyIn) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final over = plan.overLeft;
    final text = over
        ? l10n.assignPaymentOver
        : plan.staysCents > 0
        ? l10n.assignPaymentStays(moneyIn.formatMinor(plan.staysCents))
        : l10n.assignPaymentStaysNone;
    return Semantics(
      liveRegion: true,
      child: Text(
        text,
        key: ValueKey(over ? 'assign-payment-over' : 'assign-payment-stays'),
        style: theme.textTheme.bodyMedium?.copyWith(
          color: over ? theme.colorScheme.error : null,
        ),
      ),
    );
  }

  List<Widget> _result(BuildContext context, _Outcome done) {
    final l10n = context.l10n;
    final moneyIn = appFormatOf(context).moneyIn(widget.currency);
    return [
      Column(
        key: const ValueKey('assign-payment-result'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (done.full > 0) Text(l10n.assignPaymentFull(done.full)),
          if (done.part > 0) Text(l10n.assignPaymentPart(done.part)),
          Text(
            done.leftCents > 0
                ? l10n.assignPaymentStays(moneyIn.formatMinor(done.leftCents))
                : l10n.assignPaymentStaysNone,
          ),
          if (done.pending) Text(l10n.assignPaymentPending),
        ],
      ),
      const FormGap(),
      _close(context),
    ];
  }

  Widget _close(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerEnd,
    child: TextButton(
      key: const ValueKey('assign-payment-close'),
      style: TextButton.styleFrom(
        minimumSize: const Size.square(KitMetrics.minTarget),
      ),
      onPressed: () => Navigator.of(context).maybePop(),
      child: Text(context.l10n.commonClose),
    ),
  );

  Widget _refusalLine(BuildContext context, PaymentRefusal why) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Semantics(
        liveRegion: true,
        child: Text(
          _refusalText(l10n, why),
          key: const ValueKey('assign-payment-refusal'),
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
      ),
    );
  }

  static String _refusalText(AppLocalizations l10n, PaymentRefusal why) =>
      switch (why) {
        PaymentRefusal.payer => l10n.assignRefusePayer,
        PaymentRefusal.business => l10n.assignRefuseBusiness,
        PaymentRefusal.currency => l10n.assignRefuseCurrency,
        PaymentRefusal.duplicate => l10n.assignRefuseDuplicate,
        PaymentRefusal.partBeyondInvoice => l10n.assignRefusePartOver,
        PaymentRefusal.sumBeyondLeft => l10n.assignRefuseSumOver,
        PaymentRefusal.usedMeanwhile => l10n.assignRefuseUsed,
        PaymentRefusal.noteRequired => l10n.assignRefuseNote,
        PaymentRefusal.generic => l10n.assignRefuseGeneric,
      };

  /// A read that failed: the source is named, there is no button, only Try
  /// again.
  List<Widget> _failed(BuildContext context, Set<InvoicingSource> sources) {
    final l10n = context.l10n;
    return [
      for (final source in sources)
        Text(
          source == InvoicingSource.credits
              ? l10n.assignPaymentReadFailedPayment
              : l10n.assignPaymentReadFailedInvoices,
          key: ValueKey('assign-payment-failed-${source.name}'),
        ),
      TextButton(
        key: const ValueKey('assign-payment-retry'),
        style: TextButton.styleFrom(
          minimumSize: const Size.square(KitMetrics.minTarget),
        ),
        onPressed: () {
          for (final source in sources) {
            retryInvoicingSource(ref, source);
          }
        },
        child: Text(l10n.commonRetry),
      ),
    ];
  }
}
