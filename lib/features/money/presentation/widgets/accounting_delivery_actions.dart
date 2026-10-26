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
import '../../../../core/ui/loading_view.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/accounting_connection_commands.dart';
import '../../domain/accounting_connection.dart';
import '../../domain/accounting_delivery_run.dart';
import '../../providers/accounting_connection_providers.dart';
import 'accounting_targets_sheet.dart';

/// What a refusal of a whole run says, its trailing words aside.
String _reasonOf(AppLocalizations l10n, DeliveryRun reason) => switch (reason) {
  DeliveryRunBooksBlocked(:final subjects) => l10n.acctDeliverBooksBlocked(
    subjects.join(', '),
  ),
  DeliveryRunTargetRefused(:final detail) => l10n.acctDeliverRefused(detail),
  DeliveryRunNotConnected() => l10n.acctDeliverNotConnected,
  DeliveryRunNotAllowed() => l10n.acctConnRefused,
  // A run is never stopped by a run that went through, or by a stop.
  DeliveryRunDone() || DeliveryRunStopped() => l10n.acctDeliverFailed,
};

/// What [run] says to the person, and whether it is good news; null when
/// there is nothing to say. [monthYear] names a month.
({String text, bool fine})? _said(
  AppLocalizations l10n,
  DeliveryRun? run,
  String Function(DateTime) monthYear,
) => switch (run) {
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
      ...done.details,
    ].join(' '),
    fine: done.needingAttention == 0,
  ),
  DeliveryRunStopped(:final reason, :final month, :final before) => (
    text: [
      _reasonOf(l10n, reason),
      if (before.count(DeliveryRunStatus.acknowledged) == 0)
        l10n.acctDeliverNothingSent
      else
        l10n.acctDeliverStoppedAt(
          monthYear(month),
          before.count(DeliveryRunStatus.acknowledged),
        ),
    ].join(' '),
    fine: false,
  ),
  null => null,
  final DeliveryRun reason => (
    text: '${_reasonOf(l10n, reason)} ${l10n.acctDeliverNothingSent}',
    fine: false,
  ),
};

/// A door that sends documents through the delivery command. While its
/// run goes it is disabled and shows that it works, so a second tap never
/// starts a second run; then it says what the run became and shows the new
/// transfers.
abstract class _DeliveryDoor extends ConsumerStatefulWidget {
  const _DeliveryDoor({super.key});

  /// The run this door starts.
  Future<DeliveryRun> deliver(
    AccountingConnectionCommands commands,
    DateTime today,
  );

  /// The door itself; [onPressed] is null while a run goes.
  Widget door(
    BuildContext context, {
    required VoidCallback? onPressed,
    required Widget? busy,
  });

  @override
  ConsumerState<_DeliveryDoor> createState() => _DeliveryDoorState();
}

class _DeliveryDoorState extends ConsumerState<_DeliveryDoor> {
  bool _running = false;

  Future<void> _deliverAndSay() async {
    final l10n = context.l10n;
    final material = MaterialLocalizations.of(context);
    final commands = ref.read(accountingConnectionCommandProvider);
    final today = ref.read(clockProvider).now();
    setState(() => _running = true);
    DeliveryRun? run;
    final ok = await runGuarded(
      context,
      domain: 'money',
      message: 'accounting delivery failed',
      errorText: l10n.acctDeliverFailed,
      action: () async => run = await widget.deliver(commands, today),
    );
    if (!mounted) return;
    setState(() => _running = false);
    ref
      ..invalidate(accountingTransfersProvider)
      ..invalidate(accountingConnectionsProvider);
    final said = ok ? _said(l10n, run, material.formatMonthYear) : null;
    if (said == null) return;
    if (said.fine) {
      AppSnack.success(context, said.text);
    } else {
      AppSnack.error(context, said.text);
    }
  }

  @override
  Widget build(BuildContext context) => widget.door(
    context,
    onPressed: _running ? null : _deliverAndSay,
    busy: _running
        ? const SizedBox.square(dimension: AppSpacing.lg, child: LoadingView())
        : null,
  );
}

/// One "deliver the year" door per connected connection of the space.
class AccountingDeliverButtons extends ConsumerWidget {
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
            _DeliverYearButton(
              key: ValueKey('acct-deliver-door-${c.id}'),
              connection: c,
              year: year,
            ),
      ],
    );
  }
}

/// Delivers [year] to [connection], month by month.
class _DeliverYearButton extends _DeliveryDoor {
  const _DeliverYearButton({
    required this.connection,
    required this.year,
    super.key,
  });

  final AccountingConnection connection;
  final int year;

  @override
  Future<DeliveryRun> deliver(
    AccountingConnectionCommands commands,
    DateTime today,
  ) => commands.deliverYear(connection, year, today);

  @override
  Widget door(
    BuildContext context, {
    required VoidCallback? onPressed,
    required Widget? busy,
  }) => OutlinedButton.icon(
    key: ValueKey('acct-deliver-${connection.id}'),
    icon: busy ?? const Icon(Icons.cloud_upload_outlined),
    label: Text(
      context.l10n.acctDeliverYear(
        '$year',
        connection.displayName.isEmpty
            ? targetLabel(connection.targetId)
            : connection.displayName,
      ),
    ),
    onPressed: onPressed,
  );
}

/// Delivers the document of [delivery] to its connection again.
class AccountingRedeliverButton extends _DeliveryDoor {
  const AccountingRedeliverButton({required this.delivery, super.key});

  final AccountingDelivery delivery;

  @override
  Future<DeliveryRun> deliver(
    AccountingConnectionCommands commands,
    DateTime today,
  ) => commands.redeliver(delivery);

  @override
  Widget door(
    BuildContext context, {
    required VoidCallback? onPressed,
    required Widget? busy,
  }) => TextButton(
    key: ValueKey('acct-redeliver-${delivery.id}'),
    onPressed: onPressed,
    child: busy ?? Text(context.l10n.acctRedeliver),
  );
}
