// SPDX-License-Identifier: AGPL-3.0-or-later
//
// The doors of the transfers that send documents to a connected
// accounting system: deliver a year's postings to one connection, month by
// month, and deliver one document again. The server decides who may and
// what is sent (`accounting-connect`, action deliver); the doors show to a
// billing manager, and the answer is said in one line.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/time/clock.dart';
import '../../../../core/trace/guarded.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/accounting_connection_commands.dart';
import '../../domain/accounting_connection.dart';
import '../../domain/accounting_delivery_run.dart';
import '../../providers/accounting_connection_providers.dart';
import 'accounting_targets_sheet.dart';

/// What [run] says to the person, and whether it is good news; null when
/// there is nothing to say.
({String text, bool fine})? _said(AppLocalizations l10n, DeliveryRun? run) =>
    switch (run) {
      DeliveryRunDone(:final documents) when documents.isEmpty => (
        text: l10n.acctDeliverNothing,
        fine: true,
      ),
      final DeliveryRunDone done => (
        text: [
          l10n.acctDeliverDone(
            done.count(DeliveryRunStatus.acknowledged),
            done.count(DeliveryRunStatus.unchanged),
            done.needingAttention,
          ),
          if (done.missing.isNotEmpty)
            l10n.acctDeliverMissing(done.missing.join(', ')),
        ].join(' '),
        fine: done.needingAttention == 0,
      ),
      DeliveryRunBooksBlocked(:final subjects) => (
        text: l10n.acctDeliverBooksBlocked(subjects.join(', ')),
        fine: false,
      ),
      DeliveryRunTargetRefused(:final detail) => (
        text: l10n.acctDeliverRefused(detail),
        fine: false,
      ),
      DeliveryRunNotConnected() => (
        text: l10n.acctDeliverNotConnected,
        fine: false,
      ),
      null => null,
    };

/// A door that sends documents through the delivery command, then says
/// what the run became and shows the new transfers.
abstract class _DeliveryDoor extends ConsumerWidget {
  const _DeliveryDoor({super.key});

  Future<void> _deliverAndSay(
    BuildContext context,
    WidgetRef ref,
    Future<DeliveryRun> Function(AccountingConnectionCommands commands) deliver,
  ) async {
    final l10n = context.l10n;
    final commands = ref.read(accountingConnectionCommandProvider);
    DeliveryRun? run;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'accounting delivery failed',
      errorText: l10n.acctDeliverFailed,
      action: () async => run = await deliver(commands),
    );
    if (!context.mounted) return;
    ref
      ..invalidate(accountingTransfersProvider)
      ..invalidate(accountingConnectionsProvider);
    final said = ok ? _said(l10n, run) : null;
    if (said == null) return;
    if (said.fine) {
      AppSnack.success(context, said.text);
    } else {
      AppSnack.error(context, said.text);
    }
  }
}

/// One "deliver the year" door per connected connection of the space.
class AccountingDeliverButtons extends _DeliveryDoor {
  const AccountingDeliverButtons({
    required this.workspaceId,
    required this.year,
    super.key,
  });

  final String workspaceId;
  final int year;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connections =
        ref.watch(accountingConnectionsProvider(workspaceId)).value ?? const [];
    return Wrap(
      spacing: AppSpacing.sm,
      children: [
        for (final c in connections)
          if (c.live && c.status == ConnectionStatus.connected)
            OutlinedButton.icon(
              key: ValueKey('acct-deliver-${c.id}'),
              icon: const Icon(Icons.cloud_upload_outlined),
              label: Text(
                context.l10n.acctDeliverYear(
                  '$year',
                  c.displayName.isEmpty
                      ? targetLabel(c.targetId)
                      : c.displayName,
                ),
              ),
              onPressed: () => _deliverAndSay(
                context,
                ref,
                (commands) => commands.deliverYear(
                  c,
                  year,
                  ref.read(clockProvider).now(),
                ),
              ),
            ),
      ],
    );
  }
}

/// Delivers the document of [delivery] to its connection again.
class AccountingRedeliverButton extends _DeliveryDoor {
  const AccountingRedeliverButton({required this.delivery, super.key});

  final AccountingDelivery delivery;

  @override
  Widget build(BuildContext context, WidgetRef ref) => TextButton(
    key: ValueKey('acct-redeliver-${delivery.id}'),
    onPressed: () => _deliverAndSay(
      context,
      ref,
      (commands) => commands.redeliver(delivery),
    ),
    child: Text(context.l10n.acctRedeliver),
  );
}
