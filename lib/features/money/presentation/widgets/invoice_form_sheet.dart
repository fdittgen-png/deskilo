// SPDX-License-Identifier: 0BSD
import 'package:flutter/material.dart';
import '../../../../core/i18n/money_format.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice.dart';
import '../../domain/vat_rate.dart';
import '../../providers/money_providers.dart';
import '../invoice_line_text.dart';
import '../../../../core/time/clock.dart';

/// Issues an invoice — plain, or a REPLACEMENT (0061) prefilled from
/// [replaces]. Since 0062 nothing is typed here: the issuer picks the
/// member and the MONTH, the sheet previews the positions the server
/// derives from that month's tracked data, and issuing snapshots exactly
/// those.
///
/// The month defaults to the PREVIOUS one — the completed month whose
/// positions no longer move — matching the hub's to-invoice list. Issuing
/// the running month is still possible (a member leaving mid-month), but
/// the sheet warns, because the month can only be invoiced ONCE (0067).
Future<void> showInvoiceIssueSheet(
  BuildContext context,
  WidgetRef ref, {
  Invoice? replaces,
  String? memberId,
  String? period,
}) async {
  final l10n = AppLocalizations.of(context);
  final workspace = ref.read(currentWorkspaceProvider).value;
  if (workspace == null) return;
  final members = (await ref.read(workspaceMembersProvider.future))
      .where((m) => m.status == MemberStatus.active && !m.isKiosk)
      .toList();
  final names = await ref.read(memberNamesProvider.future);
  if (!context.mounted) return;

  final repo = ref.read(moneyRepositoryProvider);
  // One instant for the whole sheet: the month ceiling and the default
  // period must not straddle a midnight (or month) tick.
  final now = ref.read(clockProvider).now();
  final result = await showModalBottomSheet<
      ({String memberId, String period, bool detailed})>(
    context: context,
    isScrollControlled: true,
    builder: (context) => _InvoiceForm(
      association: ref.read(sellerIsAssociationProvider),
      now: now,
      l10n: l10n,
      members: [
        for (final member in members)
          (id: member.id, name: names[member.id] ?? ''),
      ],
      currency: moneyFormat(workspace.currencyCode),
      preview: (memberId, period) => repo.previewInvoice(
        workspaceId: workspace.id,
        memberId: memberId,
        period: period,
      ),
      // Only preselect a member the dropdown actually offers — the wrong
      // invoice may target a member who has left since.
      initialMemberId:
          members.any((m) => m.id == (memberId ?? replaces?.memberId))
              ? (memberId ?? replaces?.memberId)
              : null,
      initialPeriod: period ?? replaces?.period ?? previousPeriodOf(now),
      initialDetailed: replaces?.detailed ?? false,
      replacesNumber: replaces?.number,
    ),
  );
  if (result == null || !context.mounted) return;

  try {
    await ref.read(moneyRepositoryProvider).createInvoice(
          workspaceId: workspace.id,
          memberId: result.memberId,
          period: result.period,
          replacesId: replaces?.id,
          detailed: result.detailed,
        );
  } catch (e, st) {
    TraceLogger.instance
        .error('money', 'invoice issue failed', error: e, stackTrace: st);
    if (!context.mounted) return;
    // 0067 — one active invoice per member+month (pinned substring).
    AppSnack.error(
      context,
      e.toString().contains('already invoiced')
          ? (l10n?.invoiceAlreadyInvoiced ??
              'This month is already invoiced for this member.')
          : (l10n?.workspaceGenericError ??
              'Something went wrong. Please try again.'),
    );
    return;
  }
  ref.invalidate(invoicesProvider);
  if (!context.mounted) return;
  AppSnack.success(context, l10n?.invoiceIssued ?? 'Invoice issued.');
}

/// The issue form (0062): member + month, and a read-only PREVIEW of the
/// positions the server derives from that month's tracked data. There is
/// no way to type a position — that is the point.
class _InvoiceForm extends StatefulWidget {
  const _InvoiceForm({
    required this.association,
    required this.l10n,
    required this.members,
    required this.currency,
    required this.preview,
    required this.initialPeriod,
    required this.now,
    this.initialMemberId,
    this.initialDetailed = false,
    this.replacesNumber,
  });

  /// #870 — an association collects a participation.
  final bool association;

  final AppLocalizations? l10n;
  final List<({String id, String name})> members;
  final MoneyFormat currency;
  final Future<({List<InvoiceLine> lines, int totalCents})> Function(
      String memberId, String period) preview;
  final String? initialMemberId;
  final String initialPeriod;

  /// The running instant, read from `clockProvider` by the caller — this
  /// sheet is a plain State with no `ref` of its own, and a wall-clock
  /// read here would put the month ceiling back on the real calendar.
  final DateTime now;

  final bool initialDetailed;
  final String? replacesNumber;

  @override
  State<_InvoiceForm> createState() => _InvoiceFormState();
}

class _InvoiceFormState extends State<_InvoiceForm> {
  late String? _memberId = widget.initialMemberId;
  late String _period = widget.initialPeriod;
  late bool _detailed = widget.initialDetailed;
  ({List<InvoiceLine> lines, int totalCents})? _preview;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  DateTime get _month {
    final parts = _period.split('-');
    return DateTime(int.parse(parts[0]), int.parse(parts[1]));
  }

  Future<void> _load() async {
    final memberId = _memberId;
    if (memberId == null) return;
    final period = _period;
    setState(() => _loading = true);
    try {
      final result = await widget.preview(memberId, period);
      if (!mounted || _memberId != memberId || _period != period) return;
      setState(() {
        _preview = result;
        _loading = false;
      });
    } catch (e, st) {
      // The preview is advisory (issuing re-derives server-side), but a
      // failing fetch still leaves a breadcrumb.
      TraceLogger.instance
          .error('money', 'invoice preview failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _preview = (lines: const <InvoiceLine>[], totalCents: 0);
        _loading = false;
      });
    }
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final now = widget.now;
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    setState(() {
      _period = '${next.year}-${next.month.toString().padLeft(2, '0')}';
      _preview = null;
    });
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final replacesNumber = widget.replacesNumber;
    final replacesBanner = replacesNumber == null
        ? null
        : '${l10n?.invoicePdfReplaces ?? 'Replaces'} $replacesNumber';
    final monthLabel = DateFormat.yMMMM(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format(_month);
    final now = widget.now;
    final atCurrent = _month.year == now.year && _month.month == now.month;
    final preview = _preview;
    final lines = preview?.lines ?? const <InvoiceLine>[];

    return SheetShell(
      title: l10n?.invoiceCreate ?? 'New invoice',
      children: [
        if (replacesBanner != null) ...[
          const SizedBox(height: 8),
          InlineBanner(
            key: const ValueKey('invoice-replaces-banner'),
            icon: Icons.published_with_changes_outlined,
            text: replacesBanner,
            severity: InlineBannerSeverity.info,
          ),
        ],
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          key: const ValueKey('invoice-member-dropdown'),
          initialValue: _memberId,
          items: [
            for (final member in widget.members)
              DropdownMenuItem(
                value: member.id,
                child: Text(member.name),
              ),
          ],
          onChanged: (value) {
            setState(() {
              _memberId = value;
              _preview = null;
            });
            _load();
          },
          decoration: InputDecoration(
            labelText: l10n?.invoiceMemberLabel ?? 'Member',
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(
            key: const ValueKey('invoice-period-prev'),
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftMonth(-1),
          ),
          Expanded(
            child: Text(
              monthLabel,
              key: const ValueKey('invoice-period-label'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          IconButton(
            key: const ValueKey('invoice-period-next'),
            icon: const Icon(Icons.chevron_right),
            onPressed: atCurrent ? null : () => _shiftMonth(1),
          ),
        ]),
        // 0067 — a month can be invoiced ONCE; invoicing the running one
        // freezes numbers that are still moving.
        if (atCurrent)
          InlineBanner(
            key: const ValueKey('invoice-running-month-banner'),
            icon: Icons.hourglass_bottom_outlined,
            text: l10n?.invoiceRunningMonth ??
                'This month is still running — its positions can still '
                    'change, and a month can only be invoiced once.',
            severity: InlineBannerSeverity.info,
          ),
        const SizedBox(height: 8),
        // The derived positions — read-only by design (0062).
        if (_memberId == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n?.invoicePickMember ??
                  'Pick a member to see what their month tracked.',
              key: const ValueKey('invoice-pick-member'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          )
        else if (_loading || preview == null)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (lines.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n?.invoiceNothingToInvoice ??
                  'Nothing tracked for this month — nothing to invoice.',
              key: const ValueKey('invoice-preview-empty'),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else ...[
          for (final (i, line) in lines.indexed)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                key: ValueKey('invoice-preview-line-$i'),
                children: [
                  Expanded(child: Text(invoiceLineText(l10n, line,
                      association: widget.association))),
                  Text(widget.currency.formatMinor(line.amountCents)),
                ],
              ),
            ),
          const Divider(),
          // The VAT the document will carry (0072) — computed here exactly
          // as the server computes it at issue time.
          for (final total in vatTotalsOf(
            [
              for (final line in lines)
                (amountCents: line.amountCents, vatPercent: line.vatPercent),
            ],
            // Only taxed rates are shown, so the zero category never
            // reaches the screen.
            zeroCategory: 'O',
          ))
            if (total.vatCents > 0)
              Padding(
                key: ValueKey('invoice-preview-vat-${total.percent}'),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(children: [
                  Expanded(
                    child: Text(
                      '${l10n?.vatPdfVat ?? 'VAT'} '
                      '${total.percent == total.percent.roundToDouble() ? total.percent.toStringAsFixed(0) : total.percent} %',
                      style: TextStyle(color: Theme.of(context).hintColor),
                    ),
                  ),
                  Text(
                    widget.currency.formatMinor(total.vatCents),
                    style: TextStyle(color: Theme.of(context).hintColor),
                  ),
                ]),
              ),
          Row(
            key: const ValueKey('invoice-preview-total'),
            children: [
              Expanded(
                child: Text(
                  // 0063 — the invoice nets consumptions against payments:
                  // the total IS the balance due (solde).
                  l10n?.invoiceBalance ?? 'Balance due',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                widget.currency.formatMinor(preview.totalCents),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ],
        const SizedBox(height: 4),
        // 0064 — snapshot the annex (check-ins, bookings, payments) into
        // the immutable document.
        SwitchListTile(
          key: const ValueKey('invoice-detailed-switch'),
          contentPadding: EdgeInsets.zero,
          value: _detailed,
          onChanged: (value) => setState(() => _detailed = value),
          title: Text(
            l10n?.invoiceDetailedToggle ??
                'Include the detailed annex (check-ins, services, '
                    'payments)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        const SizedBox(height: 4),
        FilledButton(
          key: const ValueKey('invoice-submit'),
          onPressed: _memberId == null || lines.isEmpty
              ? null
              : () => Navigator.of(context).pop((
                    memberId: _memberId!,
                    period: _period,
                    detailed: _detailed,
                  )),
          child: Text(l10n?.invoiceIssue ?? 'Issue invoice'),
        ),
      ],
    );
  }
}
