// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4178 (F4) -- one engagement (`/money/engagements/:id`): what was ordered and
// for whom, where it stands, the steps it may take, its whole history, and the
// quote and invoices beside it with what was paid -- facts that are READ here and
// never changed by following the work. A step names the revision the engagement
// was read at; a stale one is refused and the engagement read again. A step whose
// answer never came is retried under the SAME request identity.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/failure/app_failure.dart';
import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../core/ui/kit/page_title.dart';
import '../../../../core/ui/loading_view.dart';
import '../../domain/service_fulfilment.dart';
import '../../providers/billing_customer_providers.dart';
import '../../providers/service_fulfilment_providers.dart';
import '../engagements/engagement_text.dart';
import '../quotes/quote_text.dart';
import 'money_view_data.dart';

class ServiceFulfilmentScreen extends ConsumerStatefulWidget {
  const ServiceFulfilmentScreen({super.key, required this.fulfilmentId});

  final String fulfilmentId;

  @override
  ConsumerState<ServiceFulfilmentScreen> createState() => _State();
}

class _State extends ConsumerState<ServiceFulfilmentScreen> {
  bool _busy = false;
  String? _said;

  /// The request identity of a step whose answer is not known yet, by its intent.
  final _pending = <String, String>{};

  Future<void> _step(String workspaceId, ServiceFulfilment e, FulfilmentState to, {String reason = ''}) async {
    final l10n = context.l10n;
    final intent = '${e.id}|${e.revision}|${to.wire}|$reason';
    setState(() {
      _busy = true;
      _said = null;
    });
    final outcome = await ref
        .read(serviceFulfilmentCommandProvider)
        .step(workspaceId, e, to: to, requestId: _pending.putIfAbsent(intent, newRequestId), reason: reason);
    if (!mounted) return;
    switch (outcome) {
      case CommandDone():
        _pending.remove(intent);
        _said = null;
        ref
          ..invalidate(serviceFulfilmentProvider((workspaceId: workspaceId, fulfilmentId: e.id)))
          ..invalidate(serviceFulfilmentsProvider(workspaceId));
      case CommandRefused(refusal: Refusal(cause: final FulfilmentRefusal refusal)):
        _pending.remove(intent);
        _said = engagementRefusalText(l10n, refusal);
        // a stale or refused step is answered by what the engagement is now
        ref.invalidate(serviceFulfilmentProvider((workspaceId: workspaceId, fulfilmentId: e.id)));
      case _:
        _said = l10n.engagementUnreached; // the request identity is kept for the retry
    }
    setState(() => _busy = false);
  }

  Future<void> _cancel(String workspaceId, ServiceFulfilment e) async {
    final l10n = context.l10n;
    final reason = await showDialog<String>(context: context, builder: (_) => const _ReasonDialog());
    if (reason == null || !mounted) return;
    if (reason.isEmpty) {
      setState(() => _said = l10n.engagementRefusedIncomplete);
      return;
    }
    await _step(workspaceId, e, FulfilmentState.cancelled, reason: reason);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final workspace = MoneyViewData.gates(ref).workspace;
    final canIssue = MoneyViewData.purchasePermissionNames(ref).contains('issueInvoices');
    return Scaffold(
      appBar: AppBar(
        title: PageTitle(l10n.engagementsTitle),
        actions: [HelpDot(l10n.engagementsTitle, anchor: HelpAnchor.moneyEngagements)],
      ),
      body: workspace == null
          ? const SizedBox.shrink()
          : ref
                .watch(serviceFulfilmentProvider((workspaceId: workspace.id, fulfilmentId: widget.fulfilmentId)))
                .when(
                  loading: () => const LoadingView(),
                  error: (error, _) => Center(
                    child: Text(
                      error is FulfilmentRefusal ? engagementRefusalText(l10n, error) : l10n.engagementsLoadFailed,
                      key: const ValueKey('engagement-failed'),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  data: (e) => Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 720),
                      child: _Content(
                        workspaceId: workspace.id,
                        item: e,
                        canAct: canIssue,
                        busy: _busy,
                        said: _said,
                        onStep: (to) => to == FulfilmentState.cancelled ? _cancel(workspace.id, e) : _step(workspace.id, e, to),
                      ),
                    ),
                  ),
                ),
    );
  }
}

class _Content extends ConsumerWidget {
  const _Content({
    required this.workspaceId,
    required this.item,
    required this.canAct,
    required this.busy,
    required this.said,
    required this.onStep,
  });

  final String workspaceId;
  final ServiceFulfilment item;
  final bool canAct;
  final bool busy;
  final String? said;
  final void Function(FulfilmentState to) onStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final names = quoteCustomerNames(
      ref.watch(billingCustomersProvider(workspaceId)).value ?? const [], // empty-ok: the name only labels the engagement
    );
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.md),
      children: [
        Text(engagementScopeLine(item.scope), key: const ValueKey('engagement-title'), style: theme.textTheme.titleLarge),
        const SizedBox(height: AppSpacing.xs),
        Text([?names[item.subjectId], engagementSourceLine(l10n, item)].join(' · ')),
        const SizedBox(height: AppSpacing.sm),
        Text(engagementStateLabel(l10n, item.state), key: const ValueKey('engagement-state'), style: theme.textTheme.titleMedium),
        if (said != null) ...[
          const FormGap(),
          Text(said!, key: const ValueKey('engagement-said'), style: TextStyle(color: theme.colorScheme.error)),
        ],
        if (canAct && item.next.isNotEmpty) ...[
          const FormGap(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final to in item.next)
                if (to == FulfilmentState.cancelled)
                  OutlinedButton(
                    key: ValueKey('engagement-step-${to.wire}'),
                    onPressed: busy ? null : () => onStep(to),
                    child: Text(engagementStepLabel(l10n, to)),
                  )
                else
                  FilledButton(
                    key: ValueKey('engagement-step-${to.wire}'),
                    onPressed: busy ? null : () => onStep(to),
                    child: Text(engagementStepLabel(l10n, to)),
                  ),
            ],
          ),
        ],
        const FormGap(),
        Text(l10n.settingHistory, style: theme.textTheme.titleSmall),
        for (final s in item.history)
          ListTile(
            key: ValueKey('engagement-step-row-${s.revision}'),
            dense: true,
            title: Text(engagementStateLabel(l10n, s.to)),
            subtitle: Text([engagementDate(context, s.at), if (s.reason.isNotEmpty) s.reason].join(' · ')),
          ),
        const FormGap(),
        Text(l10n.engagementBilledOn, style: theme.textTheme.titleSmall),
        if (item.invoices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
            child: Text(l10n.engagementNoInvoice, key: const ValueKey('engagement-no-invoice')),
          ),
        for (final i in item.invoices) ...[
          ListTile(
            key: ValueKey('engagement-invoice-${i.invoiceId}'),
            dense: true,
            title: Text(i.number),
            subtitle: Text(
              l10n.engagementPaidOf(engagementAmount(context, i.paidCents, i.currency), engagementAmount(context, i.totalCents, i.currency)),
            ),
          ),
          for (final c in i.corrections)
            Padding(
              padding: const EdgeInsets.only(left: AppSpacing.md),
              child: Text(l10n.engagementCorrectedBy(c.number)),
            ),
        ],
      ],
    );
  }
}

/// The reason a cancellation is asked for; it owns its field, so the field goes
/// with the dialog's own closing animation, never before it.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.engagementCancel),
      content: AppTextField(
        key: const ValueKey('engagement-cancel-reason'),
        controller: _controller,
        label: l10n.engagementCancelReason,
      ),
      actions: [
        TextButton(
          key: const ValueKey('engagement-cancel-dismiss'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('engagement-cancel-confirm'),
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(l10n.engagementCancel),
        ),
      ],
    );
  }
}
