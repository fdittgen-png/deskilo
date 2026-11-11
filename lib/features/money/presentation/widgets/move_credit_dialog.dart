// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2380 — a payment booked on the wrong member: who actually paid, and
// why it moves. The move itself is a correcting entry the server books.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/text/collation.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../workspace/domain/member.dart';
import '../../../workspace/providers/workspace_providers.dart';
import '../../application/credit_move_commands.dart';
import '../../domain/credit_move.dart';
import '../../domain/ledger_entry.dart';
import '../../providers/bank_statement_providers.dart' show WorkspaceFeature;
import '../../providers/credit_move_providers.dart';
import '../../providers/money_providers.dart';

/// Moves [credit] to the member who actually paid, with the bank import
/// on (0688 asks its flag); nothing for any other entry.
class MoveCreditButton extends ConsumerWidget {
  const MoveCreditButton({super.key, required this.credit});

  final LedgerEntry credit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final on = ref
        .watch(enabledFeaturesSyncProvider)
        .contains(WorkspaceFeature.bankImport);
    if (!on || !CreditMoveCommands.movable(credit)) {
      return const SizedBox.shrink();
    }
    return IconButton(
      key: ValueKey('member-payment-move-${credit.id}'),
      tooltip: context.l10n.creditMoveAction,
      icon: const Icon(Icons.swap_horiz),
      onPressed: () => _move(context, ref),
    );
  }

  /// Asks who paid and why, books the move, and reads both members'
  /// money again.
  Future<void> _move(BuildContext context, WidgetRef ref) async {
    final choice = await _showMoveCreditDialog(
      context,
      fromMemberId: credit.memberId,
    );
    if (choice == null || !context.mounted) return;
    // One request id per decision: a retry of this send never moves twice.
    final requestId = newRequestId();
    final l10n = context.l10n;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'credit move failed',
      errorText: l10n.creditMoveFailed,
      action: () => ref
          .read(creditMoveCommandsProvider)
          .move(
            credit,
            toMemberId: choice.toMemberId,
            reason: choice.reason,
            requestId: requestId,
          ),
    );
    for (final member in [credit.memberId, choice.toMemberId]) {
      ref
        ..invalidate(memberLedgerProvider(member))
        ..invalidate(memberAccountProvider(member));
    }
    if (ok && context.mounted) AppSnack.success(context, l10n.creditMoveDone);
  }
}

/// The member a credit moves to and the reason the move is kept with.
typedef _CreditMoveChoice = ({String toMemberId, String reason});

/// Asks where the credit of [fromMemberId] goes; null when cancelled.
Future<_CreditMoveChoice?> _showMoveCreditDialog(
  BuildContext context, {
  required String fromMemberId,
}) => showDialog<_CreditMoveChoice>(
  context: context,
  builder: (_) => _MoveCreditDialog(fromMemberId: fromMemberId),
);

class _MoveCreditDialog extends ConsumerStatefulWidget {
  const _MoveCreditDialog({required this.fromMemberId});

  final String fromMemberId;

  @override
  ConsumerState<_MoveCreditDialog> createState() => _MoveCreditDialogState();
}

class _MoveCreditDialogState extends ConsumerState<_MoveCreditDialog> {
  final _reason = TextEditingController();
  String? _to;
  String? _reasonError;
  String? _memberError;

  @override
  void dispose() {
    _reason.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = context.l10n;
    final reason = _reason.text.trim();
    final to = _to;
    setState(() {
      _memberError = to == null ? l10n.creditMoveMemberRequired : null;
      _reasonError = reason.isEmpty ? l10n.creditMoveReasonRequired : null;
    });
    if (to == null || reason.isEmpty) return;
    Navigator.of(context).pop((toMemberId: to, reason: reason));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final names =
        ref.watch(memberNamesProvider).value ?? const <String, String>{};
    // Someone still in the space, and not the biller: the server refuses a
    // member who left and a move onto, or off, the biller's own account.
    final me = ref.watch(myMemberProvider).value?.id;
    final members = [
      for (final m
          in ref.watch(workspaceMembersProvider).value ?? const <Member>[])
        if (m.id != widget.fromMemberId &&
            m.id != me &&
            m.status != MemberStatus.exited &&
            !m.isKiosk)
          m,
    ]..sort((a, b) => compareNames(names[a.id] ?? '', names[b.id] ?? ''));
    return AlertDialog(
      title: Text(l10n.creditMoveTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.creditMoveBody),
            const FormGap.small(),
            DropdownButtonFormField<String>(
              key: const ValueKey('credit-move-member'),
              initialValue: _to,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: l10n.creditMoveMemberLabel,
                errorText: _memberError,
              ),
              items: [
                for (final m in members)
                  DropdownMenuItem(
                    value: m.id,
                    child: Text(names[m.id] ?? m.id),
                  ),
              ],
              onChanged: (id) => setState(() => _to = id),
            ),
            const FormGap.small(),
            AppTextField(
              key: const ValueKey('credit-move-reason'),
              controller: _reason,
              label: l10n.creditMoveReasonLabel,
              error: _reasonError,
              maxLines: 2,
              maxLength: creditMoveReasonWidth,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('credit-move-cancel'),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.commonCancel),
        ),
        FilledButton(
          key: const ValueKey('credit-move-confirm'),
          onPressed: _submit,
          child: Text(l10n.creditMoveConfirm),
        ),
      ],
    );
  }
}
