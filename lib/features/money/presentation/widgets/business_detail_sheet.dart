// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4167 -- the rows behind a figure of My businesses: the invoices of one
// business, one currency and (when a state was tapped) one state, or the
// obligations it has to pay in that currency, paged to completion with an
// explicit continuation. A refused read and a failed read each say so, with Try
// again for the failure: neither is an empty list. A row opens its business with
// the captured installation and workspace; the business's own screens decide who
// may act.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/backend/operation_context.dart' show WorkspaceTarget;
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/business_payables.dart';
import '../../domain/business_receivables.dart';
import '../../domain/purchase_obligation.dart';
import '../../domain/supplier_payables_page.dart';
import '../../providers/business_receivables_providers.dart';
import '../my_finances_open.dart';

/// Which rows a tap on a figure asks for.
sealed class BusinessDetail {
  const BusinessDetail(this.target, this.name, this.currency);

  final WorkspaceTarget target;
  final String name;
  final String currency;
}

/// The invoices of a business, in one currency and optionally one state.
final class ReceivablesDetail extends BusinessDetail {
  const ReceivablesDetail(super.target, super.name, super.currency, this.state);

  final ReceivableState? state;
}

/// The obligations a business has to pay, in one currency and optionally of one
/// creditor kind (`supplier` or `member`).
final class PayablesDetail extends BusinessDetail {
  const PayablesDetail(super.target, super.name, super.currency, this.creditorKind);

  final String? creditorKind;
}

/// Opens the rows behind a figure of My businesses.
Future<void> showBusinessDetail(
  BuildContext context,
  BusinessDetail detail,
) => showAppSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  useSafeArea: true,
  builder: (_) => BusinessDetailSheet(detail: detail),
);

@visibleForTesting
class BusinessDetailSheet extends ConsumerWidget {
  const BusinessDetailSheet({super.key, required this.detail});

  final BusinessDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final money = personalFormatOf(context).moneyNamed(detail.currency);
    final format = personalFormatOf(context);
    final title = '${detail.name} · ${detail.currency}';
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      builder: (context, scroll) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.md, 0, AppSpacing.md, AppSpacing.sm),
            child: Text(title, style: Theme.of(context).textTheme.titleMedium),
          ),
          Expanded(
            child: switch (detail) {
              final ReceivablesDetail d => _PagedRows<ReceivableInvoiceRow, ReceivablesCursor>(
                key: ValueKey('business-detail-${d.target.financeKey}-${d.currency}-${d.state?.wire}'),
                scroll: scroll,
                load: (after) async {
                  final page = await ref.read(businessDetailLoaderProvider).receivables(
                    d.target.workspaceId,
                    d.currency,
                    state: d.state,
                    after: after,
                  );
                  return (rows: page.rows, next: page.next);
                },
                isRefusal: (e) => e is BusinessReceivablesRefusal,
                rowBuilder: (r) => ListTile(
                  key: ValueKey('business-detail-row-${r.invoiceId}'),
                  title: Text('${r.number} · ${r.memberName}'),
                  subtitle: Text(l10n.myBusinessIssued(format.dates(DateShape.date).format(format.wall(r.issuedAt)))),
                  trailing: Text(
                    money.formatMinor(r.stillDueCents + r.awaitingCents),
                    key: ValueKey('business-detail-amount-${r.invoiceId}'),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(openMyInvoice(context, ref, d.target, r.invoiceId, d.name));
                  },
                ),
              ),
              final PayablesDetail d => _PagedRows<PayableRow, SupplierPayablesCursor>(
                key: ValueKey('business-detail-${d.target.financeKey}-${d.currency}-${d.creditorKind}'),
                scroll: scroll,
                load: (after) async {
                  final page = await ref.read(businessDetailLoaderProvider).payables(
                    d.target.workspaceId,
                    d.currency,
                    creditorKind: d.creditorKind,
                    after: after,
                  );
                  return (rows: page.rows, next: page.next);
                },
                isRefusal: (e) => e is BusinessPayablesRefusal,
                rowBuilder: (r) => ListTile(
                  key: ValueKey('business-detail-row-${r.obligation.id}'),
                  title: Text(r.obligation.creditorName ?? l10n.myBusinessMemberExpenses),
                  subtitle: r.purchase.reference.isEmpty ? null : Text(r.purchase.reference),
                  trailing: Text(
                    money.formatMinor(r.obligation.remainingCents),
                    key: ValueKey('business-detail-amount-${r.obligation.id}'),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    unawaited(openMyInvoice(context, ref, d.target, null, d.name));
                  },
                ),
              ),
            },
          ),
        ],
      ),
    );
  }
}

typedef _Page<R, C> = ({List<R> rows, C? next});

/// Rows loaded page by page: the continuation is the server's, a refusal and a
/// failure are each said, and nothing is dropped between pages.
class _PagedRows<R, C> extends StatefulWidget {
  const _PagedRows({
    super.key,
    required this.scroll,
    required this.load,
    required this.isRefusal,
    required this.rowBuilder,
  });

  final ScrollController scroll;
  final Future<_Page<R, C>> Function(C? after) load;
  final bool Function(Object error) isRefusal;
  final Widget Function(R row) rowBuilder;

  @override
  State<_PagedRows<R, C>> createState() => _PagedRowsState<R, C>();
}

class _PagedRowsState<R, C> extends State<_PagedRows<R, C>> {
  final _rows = <R>[];
  C? _next;
  bool _started = false;
  bool _loading = false;
  bool _refused = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_more());
  }

  Future<void> _more() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final page = await widget.load(_next);
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.rows);
        _next = page.next;
        _started = true;
      });
    } on Object catch (e, st) {
      if (!mounted) return;
      if (widget.isRefusal(e)) {
        setState(() => _refused = true);
      } else {
        TraceLogger.instance.warn(
          'money',
          'a page of the rows behind a figure of My businesses could not be read',
          error: e,
          stackTrace: st,
        );
        setState(() => _failed = true);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (_refused) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Text(l10n.myBusinessDetailRefused, key: const ValueKey('business-detail-refused')),
      );
    }
    return ListView(
      key: const ValueKey('business-detail-rows'),
      controller: widget.scroll,
      children: [
        for (final r in _rows) widget.rowBuilder(r),
        if (_started && _rows.isEmpty)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Text(l10n.myBusinessDetailEmpty),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(AppSpacing.md),
            child: LimitedBox(maxHeight: 64, child: LoadingView()),
          ),
        if (_failed)
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.myBusinessUnavailable, key: const ValueKey('business-detail-failed')),
                TextButton(
                  key: const ValueKey('business-detail-retry'),
                  onPressed: _more,
                  child: Text(l10n.myBusinessRetry),
                ),
              ],
            ),
          ),
        if (!_loading && !_failed && _started && _next != null)
          TextButton(
            key: const ValueKey('business-detail-more'),
            onPressed: _more,
            child: Text(l10n.portalDirectoryShowMore),
          ),
      ],
    );
  }
}
