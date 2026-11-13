// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3829 — revoking sold guest passes from the records table: one question,
// then one pass after another, each with its own request id, and one
// outcome per pass. A pass the server refused stays as it was and says
// why; nothing is reported revoked that the server did not revoke. No money
// moves here: the invoice is corrected on its page.
import 'package:flutter/material.dart';

import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/trace/refusal_text.dart';
import '../../../../core/ui/kit/result_page.dart';
import '../../application/guest_pass_commands.dart';
import '../../domain/guest_pass.dart';

/// Asks, then revokes [passes] of [workspaceId] through [commands], one
/// after another; [holder] names each pass's guest in the result, and
/// [onRevoked] runs once they were sent.
Future<void> revokeGuestPasses(
  BuildContext context, {
  required GuestPassCommands commands,
  required String workspaceId,
  required List<GuestPassRecord> passes,
  required String Function(GuestPassRecord pass) holder,
  required VoidCallback onRevoked,
}) async {
  final l10n = context.l10n;
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialog) => AlertDialog(
      scrollable: true,
      title: Text(l10n.guestPassRevokeConfirmTitle(passes.length)),
      content: Text(l10n.guestPassRevokeConfirmBody),
      actions: [
        TextButton(
          key: const ValueKey('guest-pass-revoke-cancel'),
          onPressed: () => Navigator.of(dialog).pop(false),
          child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
        ),
        FilledButton(
          key: const ValueKey('guest-pass-revoke-confirm'),
          onPressed: () => Navigator.of(dialog).pop(true),
          child: Text(l10n.badgeRevoke),
        ),
      ],
    ),
  );
  if (ok != true || !context.mounted) return;

  final outcomes = await commands.revokeEach(workspaceId, [
    for (final p in passes) p.id,
  ]);
  onRevoked();
  final byId = {for (final p in passes) p.id: p};
  final done = <ResultLine>[
    for (final o in outcomes)
      if (o.cancelled case final cancelled?)
        (
          title: holder(byId[o.passId]!),
          detail: l10n.guestPassRevokeCancelled(cancelled),
          outcome: l10n.guestPassRevoked,
        ),
  ];
  final notDone = <ResultLine>[
    for (final o in outcomes)
      if (o.error case final error?)
        (
          title: holder(byId[o.passId]!),
          detail: knownRefusalText(l10n, error) ?? l10n.guestPassRevokeFailed,
          outcome: '',
        ),
  ];
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (dialog) => Dialog.fullscreen(
      child: Scaffold(
        body: SafeArea(
          child: ResultPage(
            key: const ValueKey('guest-pass-revoke-result'),
            tone: notDone.isEmpty
                ? ResultTone.ok
                : done.isEmpty
                ? ResultTone.failed
                : ResultTone.partial,
            title: l10n.guestPassRevokeResultTitle(done.length),
            subtitle: l10n.guestPassRevokeResultSubtitle,
            done: done,
            notDone: notDone,
            notDoneHeading: l10n.guestPassRevokeNotDone,
            staysNote: l10n.guestPassRevokeStays,
            doneLabel: l10n.commonDone,
            onDone: () => Navigator.of(dialog).pop(),
          ),
        ),
      ),
    ),
  );
}
