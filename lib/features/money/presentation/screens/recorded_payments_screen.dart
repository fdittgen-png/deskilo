// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2578 — the payments behind the collected figure: one row per payment a
// match consumed, newest first, a bounded page at a time. Opened by the
// figure's drill with the figure's own window (`?from=&to=`); anything
// missing or malformed shows the current month.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/adaptive/window_class.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../domain/payment_intent.dart';
import '../../domain/recorded_payments.dart';
import '../../domain/register_period.dart';
import '../../providers/money_queries_providers.dart';
import '../../providers/recorded_payments_providers.dart';
import '../widgets/recorded_payments_table.dart';
import 'money_view_data.dart';

class RecordedPaymentsScreen extends ConsumerWidget {
  const RecordedPaymentsScreen({super.key, this.from, this.to});

  final String? from;
  final String? to;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final period = RegisterPeriod.parse(from, to);
    // The fallback month is the clock's; the figure's own window always
    // arrives in the address.
    final today = ref.watch(clockProvider).now();
    final first = period?.first ?? DateTime(today.year, today.month);
    final last = period?.last ?? DateTime(today.year, today.month + 1, 0);
    final dateFormat = ref.watch(appFormatProvider).dates(DateShape.date);
    return Scaffold(
      appBar: AppBar(title: PageTitle(l10n.recordedPaymentsTitle)),
      body: workspace == null
          ? const SizedBox.shrink()
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Reversals(
                  workspaceId: workspace.id,
                  currencyCode: workspace.currencyCode,
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: Text(
                    l10n.recordedPaymentsPeriod(
                      dateFormat.format(first),
                      dateFormat.format(last),
                    ),
                    key: const ValueKey('recorded-payments-period'),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                Expanded(
                  child: _FirstPage(
                    pageKey: (
                      workspaceId: workspace.id,
                      from: first,
                      to: last,
                      afterMatchedAt: null,
                      afterId: null,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

/// The first page: its own state, and the list that grows from it.
class _FirstPage extends ConsumerWidget {
  const _FirstPage({required this.pageKey});

  final RecordedPaymentsPageKey pageKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final provider = recordedPaymentsPageProvider(pageKey);
    final value = ref.watch(provider);
    void retry() => ref.invalidate(provider);

    final error = value.hasError && !value.hasValue ? value.error : null;
    if (error is RecordedPaymentsSwitchedOff) {
      return ListView(
        padding: AppSpacing.mdAll,
        children: [
          InlineBanner(
            key: const ValueKey('recorded-payments-off'),
            icon: Icons.toggle_off_outlined,
            text: l10n.recordedPaymentsOff,
          ),
        ],
      );
    }
    if (error is RecordedPaymentsForbidden) {
      return ListView(
        padding: AppSpacing.mdAll,
        children: [
          InlineBanner(
            key: const ValueKey('read-failure'),
            icon: Icons.lock_outline,
            text: l10n.readStateDenied,
            actionLabel: l10n.commonRetry,
            onAction: retry,
          ),
        ],
      );
    }
    return AsyncReadBody<RecordedPaymentsPage>(
      value: value,
      onRetry: retry,
      data: (page) => page.items.isEmpty
          ? ListView(
              padding: AppSpacing.mdAll,
              children: [
                Text(
                  l10n.recordedPaymentsEmpty,
                  key: const ValueKey('recorded-payments-empty'),
                ),
              ],
            )
          : _PaymentsList(first: page, key: _listKey(pageKey), base: pageKey),
    );
  }
}

ValueKey<String> _listKey(RecordedPaymentsPageKey k) =>
    ValueKey('recorded-payments-${k.workspaceId}-${k.from}-${k.to}');

/// The rows of the first page, then the pages the person asked for, each
/// read on its own so one failing page leaves the others on screen.
class _PaymentsList extends ConsumerStatefulWidget {
  const _PaymentsList({super.key, required this.first, required this.base});

  final RecordedPaymentsPage first;
  final RecordedPaymentsPageKey base;

  @override
  ConsumerState<_PaymentsList> createState() => _PaymentsListState();
}

class _PaymentsListState extends ConsumerState<_PaymentsList> {
  /// The cursors asked for so far, in order.
  final List<RecordedPaymentsCursor> _more = [];

  RecordedPaymentsPageKey _keyAfter(RecordedPaymentsCursor c) => (
    workspaceId: widget.base.workspaceId,
    from: widget.base.from,
    to: widget.base.to,
    afterMatchedAt: c.matchedAt,
    afterId: c.id,
  );

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rows = <Widget>[
      for (final p in widget.first.items) _PaymentRow(payment: p),
    ];
    // #3627 — the payments themselves, for the desk's table; [tail] what
    // follows them (a failed page, a page being read, the next page).
    final payments = [...widget.first.items];
    final tail = <Widget>[];
    RecordedPaymentsCursor? next = widget.first.nextCursor;
    for (final cursor in _more) {
      final key = _keyAfter(cursor);
      final provider = recordedPaymentsPageProvider(key);
      final value = ref.watch(provider);
      if (value.hasValue) {
        final page = value.requireValue;
        rows.addAll([for (final p in page.items) _PaymentRow(payment: p)]);
        payments.addAll(page.items);
        next = page.nextCursor;
      } else if (value.hasError && !value.isLoading) {
        tail.add(
          ReadFailureBanner(
            error: value.error!,
            onRetry: () => ref.invalidate(provider),
          ),
        );
        next = null;
      } else {
        tail.add(
          const LinearProgressIndicator(key: ValueKey('read-refreshing')),
        );
        next = null;
      }
    }
    final complete = next == null && tail.isEmpty;
    if (next != null) {
      final cursor = next;
      tail.add(
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            key: const ValueKey('recorded-payments-more'),
            onPressed: () => setState(() => _more.add(cursor)),
            child: Text(l10n.recordedPaymentsMore),
          ),
        ),
      );
    }
    if (WindowClass.of(context).index >= WindowClass.expanded.index) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: RecordedPaymentsTable(
              payments: payments,
              complete: complete,
              cardBuilder: (_, p) => _PaymentRow(payment: p),
            ),
          ),
          ...tail,
        ],
      );
    }
    return ListView(padding: AppSpacing.mdAll, children: [...rows, ...tail]);
  }
}

class _PaymentRow extends ConsumerWidget {
  const _PaymentRow({required this.payment});

  final RecordedPayment payment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final format = ref.watch(appFormatProvider);
    final invoice = payment.invoiceNumber;
    final payer = payment.payerName;
    return ListTile(
      key: ValueKey('recorded-payment-${payment.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(
        [?invoice, ?payer].isEmpty
            ? l10n.eventTypePayment
            : [?invoice, ?payer].join(' · '),
      ),
      subtitle: Text(
        [
          format.date(payment.matchedAt),
          if (payment.label case final label? when label.isNotEmpty) label,
        ].join(' · '),
      ),
      trailing: Text(
        format.money(payment.amountMinor, currency: payment.currency),
      ),
    );
  }
}

/// #3925 — the payments a provider reversed that nobody who sees the
/// finances has looked at yet: each with its reference and what the provider
/// reported, and the way to say it was looked at once the books are
/// corrected. Nothing shows when none waits.
class _Reversals extends ConsumerStatefulWidget {
  const _Reversals({required this.workspaceId, required this.currencyCode});

  final String workspaceId;
  final String currencyCode;

  @override
  ConsumerState<_Reversals> createState() => _ReversalsState();
}

class _ReversalsState extends ConsumerState<_Reversals> {
  late Future<List<PaymentIntent>> _waiting = _read();

  Future<List<PaymentIntent>> _read() async => [
    for (final p in await ref
        .read(paymentGatewayRepositoryProvider)
        .fetchPaymentIntents(widget.workspaceId))
      if (p.awaitsReview) p,
  ];

  Future<void> _review(PaymentIntent intent) async {
    await runGuarded(
      context,
      domain: 'money',
      message: 'payment reversal review failed',
      errorText: context.l10n.workspaceGenericError,
      action: () => ref
          .read(paymentGatewayRepositoryProvider)
          .reviewPaymentReversal(intent.id),
    );
    if (!mounted) return;
    setState(() {
      _waiting = _read();
    });
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<List<PaymentIntent>>(
    future: _waiting,
    builder: (context, snapshot) {
      final waiting = snapshot.data ?? const <PaymentIntent>[];
      if (waiting.isEmpty) return const SizedBox.shrink();
      final l10n = context.l10n;
      final money = ref.watch(appFormatProvider).moneyIn(widget.currencyCode);
      return Card(
        key: const ValueKey('payment-reversals'),
        margin: AppSpacing.mdAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ListTile(
              title: Text(l10n.recordedPaymentsReversalsTitle),
              subtitle: Text(l10n.recordedPaymentsReversalsHint),
            ),
            for (final intent in waiting)
              ListTile(
                key: ValueKey('payment-reversal-${intent.id}'),
                leading: const Icon(Icons.undo_outlined),
                title: Text(
                  '${intent.reference} · '
                  '${money.formatMinor(intent.reversedMinor(widget.currencyCode) ?? intent.amountCents)}',
                ),
                subtitle: Text(intent.reversalReason),
                trailing: TextButton(
                  key: ValueKey('payment-reversal-reviewed-${intent.id}'),
                  onPressed: () => _review(intent),
                  child: Text(l10n.recordedPaymentsReversalReviewed),
                ),
              ),
          ],
        ),
      );
    },
  );
}
