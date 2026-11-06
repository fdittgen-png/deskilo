// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3336 (0692) — whether the accounting connectors admit NEW work, with the
// moves the person may make: stop it, resume it (a manager), retire the
// connectors or reopen them for servicing (the owner, with a reason). The
// server decides and records who and why; this offers only the moves the
// contract allows, and says in words why one was refused. Hidden from whoever
// may not manage the connectors.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/help/help_anchors.dart';
import '../../../../core/help/help_dot.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/accounting_connection_commands.dart';
import '../../domain/capability_state.dart';
import '../../providers/accounting_connection_providers.dart';

class CapabilityStateCard extends ConsumerWidget {
  const CapabilityStateCard({
    required this.workspaceId,
    required this.manage,
    required this.owner,
    super.key,
  });

  final String workspaceId;
  final bool manage;
  final bool owner;

  static String _label(AppLocalizations l10n, CapabilityStateKind kind) =>
      switch (kind) {
        CapabilityStateKind.active => l10n.acctStateActive,
        CapabilityStateKind.servicing => l10n.acctStateServicing,
        CapabilityStateKind.retired => l10n.acctStateRetired,
      };

  static String _action(
    AppLocalizations l10n,
    CapabilityStateKind from,
    CapabilityStateKind to,
  ) => switch ((from, to)) {
    (_, CapabilityStateKind.active) => l10n.acctStateActionResume,
    (_, CapabilityStateKind.retired) => l10n.acctStateActionRetire,
    (CapabilityStateKind.retired, _) => l10n.acctStateActionReopen,
    _ => l10n.acctStateActionStop,
  };

  static String _confirm(
    AppLocalizations l10n,
    CapabilityStateKind from,
    CapabilityStateKind to,
  ) => switch ((from, to)) {
    (_, CapabilityStateKind.active) => l10n.acctStateConfirmResume,
    (_, CapabilityStateKind.retired) => l10n.acctStateConfirmRetire,
    (CapabilityStateKind.retired, _) => l10n.acctStateConfirmReopen,
    _ => l10n.acctStateConfirmStop,
  };

  Future<void> _move(
    BuildContext context,
    WidgetRef ref,
    CapabilityStateKind from,
    CapabilityStateKind to,
  ) async {
    final l10n = context.l10n;
    final reason = await showDialog<String>(
      context: context,
      builder: (_) => _MoveDialog(
        title: _action(l10n, from, to),
        body: _confirm(l10n, from, to),
        needsReason: capabilityMoveNeedsReason(from, to),
      ),
    );
    if (reason == null || !context.mounted) return;
    CapabilityRefusal? refused;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'capability state change failed',
      errorText: l10n.acctStateFailed,
      action: () async {
        try {
          await ref
              .read(accountingConnectionCommandProvider)
              .moveCapability(
                workspaceId,
                from: from,
                to: to,
                reason: reason,
                owner: owner,
              );
        } catch (e, st) {
          final why = AccountingConnectionCommands.refusalOf(e);
          // only a refusal the server words is shown in words; anything else
          // keeps the failure message and its trace
          if (why == CapabilityRefusal.other) Error.throwWithStackTrace(e, st);
          refused = why;
        }
      },
    );
    if (!ok || !context.mounted) return;
    ref.invalidate(capabilityStateProvider(workspaceId));
    final why = refused;
    if (why == null) {
      AppSnack.success(context, l10n.acctStateChanged);
      return;
    }
    AppSnack.error(context, switch (why) {
      CapabilityRefusal.unresolved => l10n.acctStateRefusedUnresolved,
      CapabilityRefusal.owner => l10n.acctStateRefusedOwner,
      CapabilityRefusal.switchedOff => l10n.acctStateRefusedOff,
      CapabilityRefusal.other => l10n.acctStateFailed,
    });
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!manage) return const SizedBox.shrink();
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final state = ref.watch(capabilityStateProvider(workspaceId));
    return state.maybeWhen(
      data: (s) => Card(
        key: const ValueKey('acct-state-card'),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.acctStateTitle,
                      style: theme.textTheme.titleSmall,
                    ),
                  ),
                  HelpDot(
                    l10n.helpTopicAccounting,
                    anchor: HelpAnchor.invoicingAccountingState,
                  ),
                ],
              ),
              const FormGap.small(),
              Text(
                _label(l10n, s.kind),
                key: const ValueKey('acct-state-chip'),
                style: theme.textTheme.bodyMedium,
              ),
              if (s.derived)
                Text(
                  l10n.acctStateDerived,
                  key: const ValueKey('acct-state-derived'),
                  style: theme.textTheme.bodySmall,
                )
              else if (s.reason.isNotEmpty)
                Text(s.reason, style: theme.textTheme.bodySmall),
              const FormGap.small(),
              Wrap(
                spacing: AppSpacing.sm,
                children: [
                  for (final to in capabilityMoves(s.kind, owner: owner))
                    OutlinedButton(
                      key: ValueKey('acct-state-to-${to.wire}'),
                      onPressed: () => _move(context, ref, s.kind, to),
                      child: Text(_action(l10n, s.kind, to)),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _MoveDialog extends StatefulWidget {
  const _MoveDialog({
    required this.title,
    required this.body,
    required this.needsReason,
  });

  final String title;
  final String body;
  final bool needsReason;

  @override
  State<_MoveDialog> createState() => _MoveDialogState();
}

class _MoveDialogState extends State<_MoveDialog> {
  final _reason = TextEditingController();
  bool _missing = false;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _confirm() {
    if (widget.needsReason && _reason.text.trim().isEmpty) {
      setState(() => _missing = true);
      return;
    }
    Navigator.of(context).pop(_reason.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.body),
            if (widget.needsReason) ...[
              const FormGap(),
              AppTextField(
                key: const ValueKey('acct-state-reason'),
                controller: _reason,
                label: l10n.acctStateReasonLabel,
                maxLength: capabilityReasonWidth,
                error: _missing ? l10n.acctStateReasonRequired : null,
                onChanged: (_) {
                  if (_missing) setState(() => _missing = false);
                },
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('acct-state-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('acct-state-confirm'),
          onPressed: _confirm,
          child: Text(l10n.acctStateSubmit),
        ),
      ],
    );
  }
}
