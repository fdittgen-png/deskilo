// SPDX-License-Identifier: 0BSD
//
// #881 — the payment conditions a member's documents print: the
// workspace's default, the member's own keys on top. The member sees
// them and cannot change them; an admin holding paymentTermsEdit
// REQUESTS a change, which validators decide (payment_terms_change) —
// the override is written on confirm, never here.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../events/providers/event_providers.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/domain/workspace_permission.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../domain/invoice_legal.dart';
import '../../domain/payment_terms.dart';

class PaymentTermsCard extends ConsumerWidget {
  const PaymentTermsCard({super.key, required this.member, required this.isSelf});

  final Member member;
  final bool isSelf;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final workspace = ref.watch(currentWorkspaceProvider).value;
    final legal = InvoiceLegal.fromJson(workspace?.invoiceLegal ?? const {});
    final effective = PaymentTerms.ofLegal(legal).mergedWith(member.paymentTerms);
    final overridden = member.paymentTerms != null;
    final me = ref.watch(myMemberProvider).value;
    final perms = ref.watch(myPermissionsProvider);
    final canRequest = !isSelf &&
        ((me?.actsAsOwner ?? false) ||
            perms.contains(WorkspacePermission.paymentTermsEdit));
    final rows = <(String, String)>[
      (l10n?.paymentTermsFieldTerms ?? 'Payment terms', effective.paymentTerms),
      (l10n?.paymentTermsFieldEscompte ?? 'Early-payment discount',
          effective.escompte),
      (l10n?.paymentTermsFieldLatePenalty ?? 'Late-payment penalty',
          effective.latePenalty),
      (l10n?.paymentTermsFieldRecovery ?? 'Recovery indemnity',
          effective.recoveryIndemnity),
    ].where((r) => r.$2.trim().isNotEmpty).toList();
    return Card(
      key: const ValueKey('payment-terms-card'),
      child: Padding(
        padding: AppSpacing.lgAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              const Icon(Icons.request_quote_outlined),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(l10n?.paymentTermsTitle ?? 'Payment conditions',
                    style: theme.textTheme.titleMedium),
              ),
              Chip(
                key: ValueKey(
                    'payment-terms-${overridden ? 'member' : 'workspace'}'),
                label: Text(overridden
                    ? (l10n?.paymentTermsOverridden ?? "Member's own")
                    : (l10n?.paymentTermsInherited ?? 'Workspace default')),
                visualDensity: VisualDensity.compact,
              ),
            ]),
            if (rows.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(l10n?.paymentTermsNone ?? 'No conditions written yet',
                    style: theme.textTheme.bodySmall),
              ),
            for (final row in rows)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(row.$1, style: theme.textTheme.labelMedium),
                    Text(row.$2, style: theme.textTheme.bodyMedium),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.sm),
            if (isSelf)
              Text(
                l10n?.paymentTermsMemberNote ??
                    'These conditions are set by the workspace; a change '
                        'goes through its validation.',
                style: theme.textTheme.bodySmall,
              )
            else if (canRequest)
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: OutlinedButton.icon(
                  key: const ValueKey('payment-terms-edit'),
                  onPressed: () => showPaymentTermsRequestSheet(
                    context,
                    member: member,
                    workspaceTerms: PaymentTerms.ofLegal(legal),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(l10n?.paymentTermsEdit ?? 'Request a change'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The request: the member's own keys (empty = keep the workspace's
/// wording), a reason, and "inherit again" — submitted as a
/// payment_terms_change event for validators.
Future<void> showPaymentTermsRequestSheet(
  BuildContext context, {
  required Member member,
  required PaymentTerms workspaceTerms,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RequestSheet(member: member, workspaceTerms: workspaceTerms),
    );

class _RequestSheet extends ConsumerStatefulWidget {
  const _RequestSheet({required this.member, required this.workspaceTerms});

  final Member member;
  final PaymentTerms workspaceTerms;

  @override
  ConsumerState<_RequestSheet> createState() => _RequestSheetState();
}

class _RequestSheetState extends ConsumerState<_RequestSheet> {
  late final TextEditingController _terms;
  late final TextEditingController _escompte;
  late final TextEditingController _late;
  late final TextEditingController _recovery;
  final _reason = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final own = widget.member.paymentTerms ?? PaymentTerms.empty;
    _terms = TextEditingController(text: own.paymentTerms);
    _escompte = TextEditingController(text: own.escompte);
    _late = TextEditingController(text: own.latePenalty);
    _recovery = TextEditingController(text: own.recoveryIndemnity);
  }

  @override
  void dispose() {
    for (final c in [_terms, _escompte, _late, _recovery, _reason]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit({required bool inherit}) async {
    final l10n = AppLocalizations.of(context);
    final terms = inherit
        ? PaymentTerms.empty
        : PaymentTerms(
            paymentTerms: _terms.text,
            escompte: _escompte.text,
            latePenalty: _late.text,
            recoveryIndemnity: _recovery.text,
          );
    setState(() => _busy = true);
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'payment terms request failed',
      errorText: l10n?.workspaceGenericError ??
          'Something went wrong. Please try again.',
      action: () => ref.read(eventRepositoryProvider).requestPaymentTermsChange(
            widget.member.id,
            terms: terms,
            reason: _reason.text.trim(),
          ),
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (!ok) return;
    ref.invalidate(eventsProvider);
    Navigator.of(context).pop();
    AppSnack.success(
        context,
        l10n?.paymentTermsRequested ??
            'Change requested — pending validation');
  }

  Widget _field(TextEditingController c, String keySuffix, String label,
          String hint) =>
      Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.md),
        child: TextField(
          key: ValueKey('payment-terms-$keySuffix'),
          controller: c,
          maxLines: null,
          enabled: !_busy,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint.isEmpty ? null : hint,
            border: const OutlineInputBorder(),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final w = widget.workspaceTerms;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: AppSpacing.lg,
          right: AppSpacing.lg,
          top: AppSpacing.lg,
          bottom: MediaQuery.of(context).viewInsets.bottom + AppSpacing.lg,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n?.paymentTermsRequestTitle ??
                    'Request a change of payment conditions',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                l10n?.paymentTermsRequestHint ??
                    "Leave a field empty to keep the workspace's wording for "
                        'it. The change applies once validated.',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: AppSpacing.lg),
              _field(_terms, 'terms',
                  l10n?.paymentTermsFieldTerms ?? 'Payment terms', w.paymentTerms),
              _field(_escompte, 'escompte',
                  l10n?.paymentTermsFieldEscompte ?? 'Early-payment discount',
                  w.escompte),
              _field(_late, 'late-penalty',
                  l10n?.paymentTermsFieldLatePenalty ?? 'Late-payment penalty',
                  w.latePenalty),
              _field(_recovery, 'recovery',
                  l10n?.paymentTermsFieldRecovery ?? 'Recovery indemnity',
                  w.recoveryIndemnity),
              _field(_reason, 'reason',
                  l10n?.paymentTermsReason ?? 'Reason (optional)', ''),
              FilledButton(
                key: const ValueKey('payment-terms-submit'),
                onPressed: _busy ? null : () => _submit(inherit: false),
                child: Text(l10n?.paymentTermsSubmit ?? 'Submit request'),
              ),
              if (widget.member.paymentTerms != null)
                TextButton(
                  key: const ValueKey('payment-terms-inherit'),
                  onPressed: _busy ? null : () => _submit(inherit: true),
                  child: Text(l10n?.paymentTermsUseDefault ??
                      'Use the workspace default again'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
