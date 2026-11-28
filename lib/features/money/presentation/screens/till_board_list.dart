// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4454 -- the till boards of the business on Settings › Devices: each with its till, its model, its fingerprint and
// whether it waits for approval or is connected. The owner approves a waiting board after comparing the fingerprint
// on its screen, and removes a board; the server decides, and its refusal is said in words.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/devices/connected_boards_provider.dart';
import '../../../../core/devices/device_board.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/form_kit.dart';
import '../../../../l10n/app_localizations.dart';
import 'till_board_cashier.dart';

/// The words for a refusal of a board command, or for a server that did not answer.
String tillBoardFailureText(AppLocalizations l10n, Object error) => switch (error) {
  TillBoardRefused(reason: TillBoardRefusal.notAllowed) => l10n.devicePairingNotOwner,
  TillBoardRefused(reason: TillBoardRefusal.scope) => l10n.devicePairingTillInactive,
  TillBoardRefused(reason: TillBoardRefusal.proof) => l10n.devicePairingWrongFingerprint,
  TillBoardRefused(reason: TillBoardRefusal.used) => l10n.devicePairingNotWaiting,
  _ => l10n.devicePairingFailed,
};

class TillBoardList extends ConsumerWidget {
  const TillBoardList({super.key, required this.workspaceId, required this.boards, required this.owner});

  final String workspaceId;
  final List<TillBoard> boards;

  /// Whether the actions are offered: the server refuses them to anyone else anyway.
  final bool owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    if (boards.isEmpty) return Text(l10n.devicePairingNone, key: const ValueKey('device-pairing-none'));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final b in boards) ...[
          _BoardCard(workspaceId: workspaceId, board: b, owner: owner),
          const FormGap.small(),
        ],
      ],
    );
  }
}

class _BoardCard extends ConsumerWidget {
  const _BoardCard({required this.workspaceId, required this.board, required this.owner});

  final String workspaceId;
  final TillBoard board;
  final bool owner;

  Future<void> _act(BuildContext context, WidgetRef ref, Future<void> Function(TillBoardPort port) command) async {
    final l10n = context.l10n;
    try {
      await command(ref.read(tillBoardPortProvider));
    } on Object catch (e, st) {
      TraceLogger.instance.log(TraceLevel.info, 'till', 'a till board command refused or failed', error: e, stackTrace: st);
      if (context.mounted) AppSnack.error(context, tillBoardFailureText(l10n, e));
    }
    ref.invalidate(connectedTillBoardsProvider(workspaceId));
  }

  Future<bool> _confirm(BuildContext context, String title, String body, String action) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              key: const ValueKey('device-board-cancel'),
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            FilledButton(
              key: const ValueKey('device-board-confirm'),
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(action),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final waiting = board.status == TillBoardStatus.pendingApproval;
    final model = board.profile?.model ?? board.shortId;
    return Card(
      key: ValueKey('device-connected-${board.shortId}'),
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.devicePairingBoard(board.shortId, model), style: theme.textTheme.titleMedium),
            Text(l10n.devicePairingTill(board.tillName)),
            Text(waiting ? l10n.devicePairingStatusPending : l10n.devicePairingStatusPaired),
            Text(l10n.devicePairingFingerprint(board.fingerprint), style: theme.textTheme.bodySmall),
            // #4517 -- whether it asks for a cashier, and who sells on it until when
            if (board.lease case final TillBoardLease lease)
              Text(boardLeaseText(context, lease), key: ValueKey('device-board-lease-${board.shortId}'))
            else if (board.cashierAsked)
              Text(l10n.boardCashierAsks, key: ValueKey('device-board-asks-${board.shortId}')),
            if (owner)
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: AppSpacing.sm,
                children: [
                  TextButton(
                    key: ValueKey('device-board-revoke-${board.shortId}'),
                    onPressed: () async {
                      if (await _confirm(context, l10n.devicePairingRevoke, l10n.devicePairingRevokeBody, l10n.devicePairingRevoke) &&
                          context.mounted) {
                        await _act(context, ref, (port) => port.revoke(board.id));
                      }
                    },
                    child: Text(l10n.devicePairingRevoke),
                  ),
                  if (board.lease case final TillBoardLease lease)
                    TextButton(
                      key: ValueKey('device-board-end-${board.shortId}'),
                      onPressed: () => _act(context, ref, (port) => port.endLease(lease.id)),
                      child: Text(l10n.boardCashierEnd),
                    ),
                  if (waiting)
                    FilledButton(
                      key: ValueKey('device-board-approve-${board.shortId}'),
                      onPressed: () async {
                        if (await _confirm(context, l10n.devicePairingApprove, l10n.devicePairingApproveBody(board.fingerprint),
                                l10n.devicePairingApprove) &&
                            context.mounted) {
                          await _act(context, ref, (port) => port.approve(board.id, board.fingerprint));
                        }
                      },
                      child: Text(l10n.devicePairingApprove),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
