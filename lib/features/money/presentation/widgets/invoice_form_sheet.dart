// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/i18n/money_format.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/time/date_text.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_sheet.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../reservations/providers/reservation_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice.dart';
import '../../domain/invoice_line_text.dart';
import '../../domain/vat_rate.dart';
import '../../providers/money_providers.dart';
import '../report_strings_l10n.dart';
import 'invoice_correction_reason_field.dart';

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
  final l10n = context.l10n;
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
  final result = await showAppSheet<
      ({String memberId, String period, bool detailed,
        String buyerReference, String purchaseOrder, String correctionReason})>(
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
      readiness: (memberId, period, correctionReason) =>
          repo.invoiceIssueReadiness(
        workspaceId: workspace.id,
        memberId: memberId,
        period: period,
        replacesId: replaces?.id,
        correctionReason: correctionReason,
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
          buyerReference: result.buyerReference,
          purchaseOrder: result.purchaseOrder,
          correctionReason: result.correctionReason,
        );
  } on Object catch (e, st) {
    TraceLogger.instance
        .error('money', 'invoice issue failed', error: e, stackTrace: st);
    if (!context.mounted) return;
    // 0067 — one active invoice per member+month (pinned substring).
    AppSnack.error(
      context,
      e.toString().contains('already invoiced')
          ? (l10n.invoiceAlreadyInvoiced)
          : e.toString().contains('invoice_feature_disabled')
              ? (l10n.invoiceFeatureDisabled)
          : e.toString().contains('invoice_essentials_missing')
              ? (l10n.invoiceEssentialsRefused)
              : (l10n.workspaceGenericError),
    );
    return;
  }
  ref.invalidate(invoicesProvider);
  if (!context.mounted) return;
  AppSnack.success(context, l10n.invoiceIssued);
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
    required this.readiness,
    required this.initialPeriod,
    required this.now,
    this.initialMemberId,
    this.initialDetailed = false,
    this.replacesNumber,
  });

  /// #870 — an association collects a participation.
  final bool association;

  final AppLocalizations l10n;
  final List<({String id, String name})> members;
  final MoneyFormat currency;
  final Future<({List<InvoiceLine> lines, int totalCents})> Function(
      String memberId, String period) preview;

  /// #1916 — what the server would refuse to issue for, as stable keys.
  final Future<List<String>> Function(
      String memberId, String period, String correctionReason) readiness;
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
  // #922 — for a public-sector buyer; empty for everyone else. The two
  // fields hide behind a switch that is OFF by default: a member's
  // invoice is derived and has nothing to type, and that stays true.
  bool _publicBuyer = false;
  final _buyerReference = TextEditingController();
  final _purchaseOrder = TextEditingController();
  ({List<InvoiceLine> lines, int totalCents})? _preview;
  // #1916 — the essentials the server would refuse to issue without.
  List<String> _missing = const [];
  bool _loading = false;
  // #2440 — RD 1619/2012 art. 15 (R1-R5); asked only when the server
  // names it as missing, so no country is guessed here.
  String _correctionReason = '';

  @override
  void initState() {
    super.initState();
    unawaited(_load());
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
      var missing = const <String>[];
      try {
        missing = await widget.readiness(memberId, period, _correctionReason);
      } on Object catch (e, st) {
        // Advisory: the server still refuses an incomplete issue.
        TraceLogger.instance.error('money', 'invoice readiness failed',
            error: e, stackTrace: st);
      }
      if (!mounted || _memberId != memberId || _period != period) return;
      setState(() {
        _preview = result;
        _missing = missing;
        _loading = false;
      });
    } on Object catch (e, st) {
      // The preview is advisory (issuing re-derives server-side), but a
      // failing fetch still leaves a breadcrumb.
      TraceLogger.instance
          .error('money', 'invoice preview failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _preview = (lines: const <InvoiceLine>[], totalCents: 0);
        _missing = const [];
        _loading = false;
      });
    }
  }

  // #2440 — the reason joins the readiness question; the preview reloads.
  void _setCorrectionReason(String? reason) {
    _correctionReason = reason ?? '';
    unawaited(_load());
  }

  void _shiftMonth(int delta) {
    final next = DateTime(_month.year, _month.month + delta);
    final now = widget.now;
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    setState(() {
      _period = yearMonth(next.year, next.month);
      _preview = null;
      _missing = const [];
    });
    unawaited(_load());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final replacesNumber = widget.replacesNumber;
    final replacesBanner = replacesNumber == null
        ? null
        : '${l10n.invoicePdfReplaces} $replacesNumber';
    final monthLabel = DateFormat.yMMMM(
      Localizations.maybeLocaleOf(context)?.toString(),
    ).format(_month);
    final now = widget.now;
    final atCurrent = _month.year == now.year && _month.month == now.month;
    final preview = _preview;
    final lines = preview?.lines ?? const <InvoiceLine>[];

    return SheetShell(
      title: l10n.invoiceCreate,
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
              _missing = const [];
            });
            unawaited(_load());
          },
          decoration: InputDecoration(
            labelText: l10n.invoiceMemberLabel,
          ),
        ),
        const SizedBox(height: 8),
        Row(children: [
          IconButton(
            tooltip: MaterialLocalizations.of(context).previousMonthTooltip,
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
            tooltip: MaterialLocalizations.of(context).nextMonthTooltip,
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
            text: l10n.invoiceRunningMonth,
            severity: InlineBannerSeverity.info,
          ),
        const SizedBox(height: 8),
        // The derived positions — read-only by design (0062).
        if (_memberId == null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              l10n.invoicePickMember,
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
              l10n.invoiceNothingToInvoice,
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
                  Expanded(child: Text(invoiceLineText(reportStringsOf(l10n), line,
                      association: widget.association, period: _period))),
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
                      '${l10n.vatPdfVat} '
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
                  l10n.invoiceBalance,
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
            l10n.invoiceDetailedToggle,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        // #922 — Chorus Pro refuses a public-sector deposit without an
        // engagement number or a service code. A member is not a mairie,
        // so the two fields appear only when the buyer is a public body.
        SwitchListTile(
          key: const ValueKey('invoice-form-public-buyer'),
          contentPadding: EdgeInsets.zero,
          value: _publicBuyer,
          onChanged: (value) => setState(() => _publicBuyer = value),
          title: Text(
            l10n.invoicePublicBuyer,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
        if (_publicBuyer)
        TextField(
          key: const ValueKey('invoice-form-purchase-order'),
          controller: _purchaseOrder,
          decoration: InputDecoration(
            labelText: l10n.invoicePurchaseOrder,
            helperText: l10n.invoicePurchaseOrderHint,
            helperMaxLines: 2,
          ),
        ),
        if (_publicBuyer)
        TextField(
          key: const ValueKey('invoice-form-buyer-reference'),
          controller: _buyerReference,
          decoration: InputDecoration(
            labelText: l10n.invoiceBuyerReference,
            helperText: l10n.invoiceBuyerReferenceHint,
            helperMaxLines: 2,
          ),
        ),
        if (lines.isNotEmpty &&
            (_missing.contains('correction_reason') ||
                _correctionReason.isNotEmpty))
          InvoiceCorrectionReasonField(
            key: const ValueKey('invoice-correction-reason-field'),
            value: _correctionReason,
            onChanged: _setCorrectionReason,
          ),
        if (_missing.isNotEmpty && lines.isNotEmpty)
          InlineBanner(
            key: const ValueKey('invoice-missing-essentials'),
            icon: Icons.rule_folder_outlined,
            text: '${_missing.contains('invoice_feature_disabled')
                ? l10n.invoiceIssuingUnavailable
                : _missing.contains('vat_treatment_unreviewed')
                ? l10n.invoiceExternalIssuingTitle
                : l10n.invoiceMissingTitle}:\n'
                '${[for (final key in _missing) '• ${invoiceMissingLabel(l10n, key)}'].join('\n')}',
          ),
        const SizedBox(height: 4),
        FilledButton(
          key: const ValueKey('invoice-submit'),
          onPressed: _memberId == null || lines.isEmpty || _missing.isNotEmpty
              ? null
              : () => Navigator.of(context).pop((
                    memberId: _memberId!,
                    period: _period,
                    detailed: _detailed,
                    buyerReference:
                        _publicBuyer ? _buyerReference.text.trim() : '',
                    purchaseOrder:
                        _publicBuyer ? _purchaseOrder.text.trim() : '',
                    correctionReason: _correctionReason,
                  )),
          child: Text(l10n.invoiceIssue),
        ),
      ],
    );
  }
}

/// #1916 — the words for one missing essential (stable server keys, 0365).
String invoiceMissingLabel(AppLocalizations l10n, String key) => switch (key) {
      'invoice_feature_disabled' => l10n.invoiceFeatureDisabled,
      'seller_address' => l10n.invoiceMissingSellerAddress,
      'seller_vat_id' => l10n.invoiceMissingSellerVatId,
      'exemption_reason' => l10n.invoiceMissingExemptionReason,
      'buyer_name' =>
        l10n.invoiceMissingBuyerName,
      'buyer_address' => l10n.invoiceMissingBuyerAddress,
      'buyer_vat_id' => l10n.invoiceMissingBuyerVatId,
      'seller_country_unsupported' => l10n.invoiceMissingSellerCountry,
      // #2356 — § 14 UStG / NIF, the customer's identifier, art. 230.
      'seller_tax_number' => l10n.invoiceMissingSellerTaxNumber,
      'buyer_tax_id' => l10n.invoiceMissingBuyerTaxId,
      'vat_national_currency' => l10n.invoiceMissingNationalCurrency,
      // #2359 — HMRC's VAT registration number format.
      'seller_vat_id_format' => l10n.invoiceMissingSellerVatIdFormat,
      // #2360 — the Swiss UID with its MWST suffix.
      'seller_uid_format' => l10n.invoiceMissingSellerUidFormat,
      // #2440 — RD 1619/2012 art. 15.
      'correction_reason' => l10n.invoiceMissingCorrectionReason,
      'vat_rate_unresolved' => l10n.invoiceMissingVatRate,
      'vat_line_zero_unexplained' => l10n.invoiceMissingVatZeroLine,
      'vat_charged_not_registered' => l10n.invoiceMissingVatNotRegistered,
      'vat_treatment_unreviewed' => l10n.invoiceMissingVatTreatment,
      // #2354 — a general service to a customer abroad: business or not.
      'vies_unverified' =>
        l10n.invoiceMissingVies,
      'buyer_capacity_unknown' =>
        l10n
            .invoiceMissingBuyerCapacity,
      _ => key,
    };
