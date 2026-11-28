// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4517 -- a cashier authorizes a till board from the app. The till drawer lists the paired boards of the business: a
// board that asks for a cashier offers "Sell on this board as me", which hands the board a lease in the person's own
// name (the embedded-till function seals their sign-in; the board never sees it); a board they sell on says until when
// and can be ended; a board someone else sells on says who. The owner's Devices card says the same of every board.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/devices/connected_boards_provider.dart';
import '../../../../core/devices/device_board.dart';
import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/async_read_body.dart';
import '../../../../l10n/app_localizations.dart';

/// The words for a refused authorization.
String boardAuthorizeFailureText(AppLocalizations l10n, Object error) =>
    switch (error) {
      TillBoardAuthorizeRefused(reason: TillBoardAuthorizeRefusal.notAllowed) =>
        l10n.boardCashierRefusedNotAllowed,
      TillBoardAuthorizeRefused(reason: TillBoardAuthorizeRefusal.noRequest) =>
        l10n.boardCashierRefusedNoRequest,
      TillBoardAuthorizeRefused(reason: TillBoardAuthorizeRefusal.notPaired) =>
        l10n.boardCashierRefusedNotPaired,
      TillBoardAuthorizeRefused(reason: TillBoardAuthorizeRefusal.signIn) =>
        l10n.boardCashierRefusedSignIn,
      TillBoardAuthorizeRefused(
        reason: TillBoardAuthorizeRefusal.notConfigured,
      ) =>
        l10n.boardCashierRefusedNotConfigured,
      _ => l10n.boardCashierRefusedUncertain,
    };

/// Who sells on [lease] until when, in words.
String boardLeaseText(BuildContext context, TillBoardLease lease) {
  final l10n = context.l10n;
  final time = appFormatOf(context).time(lease.expiresAt);
  if (lease.mine) return l10n.boardCashierMine(time);
  return lease.memberName.isEmpty
      ? l10n.boardCashierSoldByUnnamed(time)
      : l10n.boardCashierSoldBy(lease.memberName, time);
}

/// The paired boards of [workspaceId] on the till drawer, for whom may sell.
class TillBoardCashierCard extends ConsumerWidget {
  const TillBoardCashierCard({super.key, required this.workspaceId});

  final String workspaceId;

  Future<void> _act(
    BuildContext context,
    WidgetRef ref,
    Future<String> Function(TillBoardPort port) command,
  ) async {
    final l10n = context.l10n;
    try {
      final said = await command(ref.read(tillBoardPortProvider));
      if (context.mounted) AppSnack.success(context, said);
    } on Object catch (e, st) {
      TraceLogger.instance.log(
        TraceLevel.info,
        'till',
        'a board was not authorized or ended',
        error: e,
        stackTrace: st,
      );
      if (context.mounted) {
        AppSnack.error(context, boardAuthorizeFailureText(l10n, e));
      }
    }
    ref.invalidate(cashierTillBoardsProvider(workspaceId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final format = appFormatOf(context);
    return Card(
      key: const ValueKey('board-cashier'),
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Padding(
        padding: AppSpacing.gutterAll,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.boardCashierTitle, style: theme.textTheme.titleMedium),
            Text(l10n.boardCashierRenewHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: AppSpacing.sm),
            AsyncReadBody.part(
              value: ref.watch(cashierTillBoardsProvider(workspaceId)),
              isEmpty: (boards) => boards.isEmpty,
              retryKey: const ValueKey('board-cashier-retry'),
              onRetry: () =>
                  ref.invalidate(cashierTillBoardsProvider(workspaceId)),
              data: (boards) => boards.isEmpty
                  ? Text(
                      l10n.boardCashierNone,
                      key: const ValueKey('board-cashier-none'),
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final b in boards)
                          ListTile(
                            key: ValueKey('board-cashier-${b.shortId}'),
                            contentPadding: EdgeInsets.zero,
                            title: Text(l10n.devicePairingTill(b.tillName)),
                            subtitle: Text(switch (b.lease) {
                              final TillBoardLease lease => boardLeaseText(
                                context,
                                lease,
                              ),
                              null =>
                                b.cashierAsked
                                    ? l10n.boardCashierAsks
                                    : l10n.devicePairingFingerprint(
                                        b.fingerprint,
                                      ),
                            }),
                            trailing: switch (b.lease) {
                              TillBoardLease(mine: true, :final id) =>
                                TextButton(
                                  key: ValueKey(
                                    'board-cashier-end-${b.shortId}',
                                  ),
                                  onPressed: () =>
                                      _act(context, ref, (port) async {
                                        await port.endLease(id);
                                        return l10n.boardCashierEnded;
                                      }),
                                  child: Text(l10n.boardCashierEnd),
                                ),
                              null when b.cashierAsked => FilledButton(
                                key: ValueKey(
                                  'board-cashier-sell-${b.shortId}',
                                ),
                                onPressed: () => _act(
                                  context,
                                  ref,
                                  (port) async => l10n.boardCashierAuthorized(
                                    format.time(await port.authorize(b.id)),
                                  ),
                                ),
                                child: Text(l10n.boardCashierSellAsMe),
                              ),
                              _ => null,
                            },
                          ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
