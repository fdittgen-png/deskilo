// SPDX-License-Identifier: AGPL-3.0-or-later
import 'dart:async';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/features/enabled_feature_keys.dart';
import '../../../../core/i18n/app_format.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/i18n/money_format.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/adaptive/task_surface.dart';
import '../../../../core/ui/form_sheet.dart';
import '../../../../core/ui/inline_banner.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/issue_invoice.dart';
import '../../domain/invoice_issue_draft.dart';
import '../../domain/invoice_issue_readiness.dart';
import '../../domain/invoice_mail.dart' show invoiceEmailKey;
import '../../providers/money_providers.dart';
import '../e_invoice_identity.dart';
import '../invoice_original_document.dart';
import '../issue_judgement.dart';
import 'einvoice_gaps_warning.dart';
import 'invoice_correction_reason_field.dart';
import 'invoice_issue_runner.dart';
import 'invoice_missing_banner.dart';
import 'invoice_preview_body.dart';

/// Issues an invoice — plain, or a REPLACEMENT (0061) of [replaces]. Since
/// 0062 nothing is typed: the issuer picks the member and the MONTH, the
/// sheet previews what the server derives, and issuing snapshots it.
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

  final repo = ref.read(invoiceQueriesProvider);
  // One instant for the whole sheet: the month ceiling and the default
  // period must not straddle a midnight (or month) tick.
  final now = ref.read(clockProvider).now();
  // #4058 — a task: a sheet on a phone, a side task at the desk; what was
  // chosen survives a resize, and leaving with changes asks.
  final result = await showTask<
      ({String memberId, String period, bool detailed,
        String buyerReference, String purchaseOrder, String correctionReason})>(
    context,
    size: TaskSize.standard,
    sessionKey: ('invoice-issue', workspace.id, replaces?.id),
    builder: (context) => _InvoiceForm(
      canEmail: featureOn(ref.read(enabledFeatureKeysProvider), invoiceEmailKey, byDefault: false),
      countryCode: workspace.countryCode,
      association: ref.read(sellerIsAssociationProvider),
      now: now,
      l10n: l10n,
      members: [
        for (final member in members)
          (id: member.id, name: names[member.id] ?? ''),
      ],
      currency: appFormatOf(context).moneyIn(workspace.currencyCode),
      preview: (memberId, period) => repo.previewInvoice(
        workspaceId: workspace.id,
        memberId: memberId,
        period: period,
      ),
      readiness: (memberId, period, correctionReason) => judgeIssue(ref, workspace.id, (
        memberId: memberId,
        period: period,
        replacesId: replaces?.id,
        kind: replaces?.kind.correctionKind ?? InvoiceKind.full, // #3994
        correctionReason: correctionReason,
      ), iban: workspaceIban(workspace)),
      // Only preselect a member the dropdown offers: the wrong invoice's member may have left.
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

  // The context is captured here: a later workspace never receives this command or its look.
  await runInvoiceIssue(
    context,
    InvoiceIssuance(
      ref.read(invoiceCommandsProvider),
      ref.read(invoiceQueriesProvider),
      ref.read(invoiceActionCommandsProvider),
    ),
    InvoiceIssueAttempt(
      workspaceId: workspace.id,
      memberId: result.memberId,
      period: result.period,
      replacesId: replaces?.id,
      kind: replaces?.kind.correctionKind ?? InvoiceKind.full, // #3994
      detailed: result.detailed,
      buyerReference: result.buyerReference,
      purchaseOrder: result.purchaseOrder,
      correctionReason: result.correctionReason,
      requestId: newRequestId(),
    ),
    // #3853 — its original is kept in the same flow.
    afterIssue: (id) => InvoiceDocumentFlow(context, ref).keep([id]),
  );
  ref.invalidate(invoicesProvider);
}

/// The issue form (0062): member + month, and a read-only PREVIEW of the
/// positions the server derives from that month's tracked data. There is
/// no way to type a position — that is the point.
class _InvoiceForm extends StatefulWidget {
  const _InvoiceForm({
    required this.canEmail,
    required this.countryCode,
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

  /// #4058 — whether an issued invoice can then be sent by e-mail.
  final bool canEmail;

  /// The workspace's country (its law's own correction reason codes).
  final String countryCode;

  /// #870 — an association collects a participation.
  final bool association;

  final AppLocalizations l10n;
  final List<({String id, String name})> members;
  final MoneyFormat currency;
  final Future<({List<InvoiceLine> lines, int totalCents})> Function(
      String memberId, String period) preview;

  /// #1916/#4105 — what the server refuses, and the channel's gaps.
  final Future<IssueJudgement> Function(
      String memberId, String period, String correctionReason) readiness;
  final String? initialMemberId;
  final String initialPeriod;

  /// The running instant from `clockProvider` (never a wall-clock read).
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
  // The preview answer could not be read: unavailable, never an empty month.
  bool _previewFailed = false;
  // #1916 — the essentials the server would refuse to issue without.
  IssueJudgement _judged = noJudgement;
  List<String> get _missing => _judged.missing;
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
      var judged = noJudgement;
      try {
        judged = await widget.readiness(memberId, period, _correctionReason);
      } on Object catch (e, st) {
        // Advisory: the server still refuses an incomplete issue.
        TraceLogger.instance.error('money', 'invoice readiness failed',
            error: e, stackTrace: st);
      }
      if (!mounted || _memberId != memberId || _period != period) return;
      setState(() {
        _preview = result;
        _previewFailed = false;
        _judged = judged;
        _loading = false;
      });
    } on Object catch (e, st) {
      // The preview is advisory (issuing re-derives server-side), but a
      // failing fetch still leaves a breadcrumb.
      TraceLogger.instance
          .error('money', 'invoice preview failed', error: e, stackTrace: st);
      if (!mounted) return;
      setState(() {
        _preview = null;
        _previewFailed = true;
        _judged = noJudgement;
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
    _changed();
    setState(() {
      _period = yearMonth(next.year, next.month);
      _preview = null;
      _judged = noJudgement;
    });
    unawaited(_load());
  }

  Widget _periodRow(BuildContext context, String monthLabel, bool atCurrent) =>
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
    ]);

  List<Widget> _publicBuyerFields() {
    final l10n = widget.l10n;
    return [
        TextField(
          key: const ValueKey('invoice-form-purchase-order'),
          controller: _purchaseOrder,
          decoration: InputDecoration(
            labelText: l10n.invoicePurchaseOrder,
            helperText: l10n.invoicePurchaseOrderHint,
            helperMaxLines: 2,
          ),
        ),
        TextField(
          key: const ValueKey('invoice-form-buyer-reference'),
          controller: _buyerReference,
          decoration: InputDecoration(
            labelText: l10n.invoiceBuyerReference,
            helperText: l10n.invoiceBuyerReferenceHint,
            helperMaxLines: 2,
          ),
        ),
    ];
  }

  InvoiceIssueReadiness _readiness(List<InvoiceLine> lines) =>
      InvoiceIssueReadiness(
        memberId: _memberId,
        lineCount: lines.length,
        missing: _missing,
        correctionReason: _correctionReason,
      );

  Widget _missingBanner(InvoiceIssueBlock block) =>
      InvoiceMissingBanner(l10n: widget.l10n, block: block, missing: _missing);

  /// #4058 — the button names the amount; pressed only on a read preview.
  Widget _submitButton(BuildContext context, List<InvoiceLine> lines) {
    final preview = _preview;
    final ready = preview != null && !_loading && !_previewFailed;
    return FilledButton(
          key: const ValueKey('invoice-submit'),
          onPressed: !ready || !_readiness(lines).canIssue
              ? null
              : () {
                  TaskSession.maybeOf(context)?.completed();
                  Navigator.of(context).pop((
                    memberId: _memberId!,
                    period: _period,
                    detailed: _detailed,
                    buyerReference:
                        _publicBuyer ? _buyerReference.text.trim() : '',
                    purchaseOrder:
                        _publicBuyer ? _purchaseOrder.text.trim() : '',
                    correctionReason: _correctionReason,
                  ));
                },
          child: Text(
            ready
                ? widget.l10n.invoiceIssueAmount(
                    widget.currency.formatMinor(preview.totalCents),
                  )
                : widget.l10n.invoiceIssue,
          ),
        );
  }

  /// A chosen member or month is a change leaving asks about.
  void _changed() => TaskSession.maybeOf(context)?.markChanged();

  @override
  Widget build(BuildContext context) {
    final l10n = widget.l10n;
    final replacesNumber = widget.replacesNumber;
    final replacesBanner = replacesNumber == null
        ? null
        : l10n.invoicePdfReplacesNumber(replacesNumber);
    final monthLabel = appFormatOf(context).dates(DateShape.monthYear).format(_month);
    final now = widget.now;
    final atCurrent = _month.year == now.year && _month.month == now.month;
    final preview = _preview;
    final lines = preview?.lines ?? const <InvoiceLine>[];

    return SheetShell(
      title: l10n.invoiceCreate,
      children: [
        if (replacesBanner != null) ...[
          const SizedBox(height: AppSpacing.sm),
          InlineBanner(
            key: const ValueKey('invoice-replaces-banner'),
            icon: Icons.published_with_changes_outlined,
            text: replacesBanner,
            severity: InlineBannerSeverity.info,
          ),
        ],
        const SizedBox(height: AppSpacing.sm),
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
            _changed();
            setState(() {
              _memberId = value;
              _preview = null;
              _judged = noJudgement;
            });
            unawaited(_load());
          },
          decoration: InputDecoration(
            labelText: l10n.invoiceMemberLabel,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        _periodRow(context, monthLabel, atCurrent),
        // 0067 — a month can be invoiced ONCE; invoicing the running one
        // freezes numbers that are still moving.
        if (atCurrent)
          InlineBanner(
            key: const ValueKey('invoice-running-month-banner'),
            icon: Icons.hourglass_bottom_outlined,
            text: l10n.invoiceRunningMonth,
            severity: InlineBannerSeverity.info,
          ),
        const SizedBox(height: AppSpacing.sm),
        InvoicePreviewBody(
          memberPicked: _memberId != null,
          loading: _loading,
          failed: _previewFailed,
          preview: preview,
          l10n: l10n,
          currency: widget.currency,
          association: widget.association,
          period: _period,
        ),
        const SizedBox(height: AppSpacing.xs),
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
        if (_publicBuyer) ..._publicBuyerFields(),
        if (_readiness(lines).asksCorrectionReason)
          InvoiceCorrectionReasonField(
            key: const ValueKey('invoice-correction-reason-field'),
            country: widget.countryCode,
            value: _correctionReason,
            onChanged: _setCorrectionReason,
          ),
        if (_readiness(lines).block != InvoiceIssueBlock.none)
          _missingBanner(_readiness(lines).block)
        else if (_judged.gaps.isNotEmpty)
          EInvoiceGapsWarning(l10n: widget.l10n, gaps: _judged.gaps),
        const SizedBox(height: AppSpacing.xs),
        _submitButton(context, lines),
        // #4058 — what issuing means, said before it is done.
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.xs),
          child: Text(
            widget.canEmail ? l10n.invoiceIssueKeptEmail : l10n.invoiceIssueKept,
            key: const ValueKey('invoice-issue-original'),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}
