// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the reminder queue sends by e-mail as well as by sharing. What a
// line shows about its e-mail is the server's row (0728, read again after
// every send and decision), never what this screen remembers: a queue
// opened again after the app closed mid-way shows the same truth. Each
// invoice is its own attempt through the fence (0726), one after the other;
// a refused or unconfirmed line does not stop the rest. What the screen
// keeps for itself is only what the server never recorded: a level that
// moved, a request that may not have reached it (retried with the same
// attempt id), a refusal before the fence.
import 'dart:convert';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/features/enabled_feature_keys.dart';
import '../../../../core/ids/request_id.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/reminder_mail_commands.dart';
import '../../application/reminder_queue.dart';
import '../../domain/reminder_mail.dart';
import '../../providers/money_providers.dart';
import '../../providers/reminder_mail_providers.dart';
import '../invoice_actions.dart' show requireWorkspaceTaxReference;
import '../invoice_documents.dart';
import '../invoice_journey.dart' show invoiceRemainingCents;
import '../mail_refusal_text.dart';

/// What the server never recorded about a line's e-mail in this sitting.
enum QueueMailNote {
  /// The level moved between the list and the send: nothing left; the
  /// line waits for the next pass, never sent at the new level by itself.
  levelMoved,

  /// The request may not have reached the server; a retry keeps its id.
  unreached,

  /// Refused before the fence (rights, the invoice, the address).
  notSent,
}

/// The queue's e-mail: the server's rows for its invoices and one send per
/// press.
class ReminderQueueMail {
  ReminderQueueMail(this._ref);

  final WidgetRef _ref;

  /// invoice id -> the server's row (0728).
  final ValueNotifier<Map<String, ReminderMailLine>> lines = ValueNotifier(
    const {},
  );

  /// invoice id -> what only this sitting knows.
  final ValueNotifier<Map<String, QueueMailNote>> notes = ValueNotifier(
    const {},
  );

  /// invoice id -> the attempt a retry of it reuses (a request that may not
  /// have reached the server).
  final Map<String, String> _attempts = {};

  ReminderMailCommands get _commands => _ref.read(reminderMailCommandsProvider);

  /// Whether reminders by e-mail are on in this space.
  bool get on => featureOn(
    _ref.read(enabledFeatureKeysProvider),
    reminderEmailKey,
    byDefault: false,
  );

  /// The server's e-mail state of each line of [queue].
  Map<String, QueuedEmail> statesOf(ReminderQueue queue) => {
    for (final l in queue.lines)
      l.invoiceId: queuedEmailOf(l, lines.value[l.invoiceId]),
  };

  /// The lines of [queue] that can be e-mailed now.
  List<QueuedReminder> reachable(ReminderQueue queue) => [
    for (final l in queue.remaining)
      if (lines.value[l.invoiceId]?.target.available ?? false) l,
  ];

  /// Calls [reload] once the business and its switches are known, and
  /// again whenever they change.
  void follow(VoidCallback reload) => _ref
    ..listenManual(invoicesProvider, (_, _) => reload())
    ..listenManual(
      enabledFeatureKeysProvider,
      (_, _) => reload(),
      fireImmediately: true,
    );

  /// The business the queue is in: its invoices' (the queue lists them).
  String? get workspaceId =>
      _ref.read(invoicesProvider).value?.firstOrNull?.workspaceId;

  /// Reads the server's rows for [invoiceIds] again; a read that fails
  /// keeps the last rows (traced).
  Future<void> refresh(List<String> invoiceIds) async {
    final ws = workspaceId;
    if (!on || ws == null) return;
    try {
      lines.value = await _commands.lines(ws, invoiceIds);
    } on Object catch (e, st) {
      TraceLogger.instance.error(
        'money',
        'reminder queue e-mail read failed',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Sends [line]'s [letter] once.
  Future<void> send(QueuedReminder line, ReminderMailLetter letter) async {
    final workspaceId = this.workspaceId;
    if (workspaceId == null) return;
    final attemptId = _attempts.putIfAbsent(line.invoiceId, newRequestId);
    final answer = await _commands.send(
      workspaceId: workspaceId,
      invoiceId: line.invoiceId,
      level: line.level,
      attemptId: attemptId,
      letter: letter,
    );
    if (answer is! ReminderMailUnreached) _attempts.remove(line.invoiceId);
    _note(line, switch (answer) {
      ReminderMailLevelMoved() => QueueMailNote.levelMoved,
      ReminderMailUnreached() => QueueMailNote.unreached,
      ReminderMailNotSent() => QueueMailNote.notSent,
      ReminderMailAnswered() || ReminderMailToDecide() => null,
    });
  }

  /// [line]'s e-mail: the letter the queue shares, in the customer's
  /// document language, with what is still owed in the invoice's currency;
  /// null when that language is not known (nothing leaves).
  Future<ReminderMailLetter> letterOf(
    BuildContext context,
    QueuedReminder line,
    Invoice invoice,
  ) async {
    final owed = invoiceRemainingCents(
      invoice,
      _ref.read(invoiceMatchesProvider).value?[invoice.id],
    );
    final pdf = await buildReminderPdfFile(
      context,
      _ref,
      invoice,
      level: line.level,
      reference: requireWorkspaceTaxReference(_ref),
    );
    return _commands.letter(
      l10n: l10nForLanguage(pdf.language),
      document: (
        title: pdf.title,
        language: pdf.language,
        pdfBase64: base64Encode(pdf.bytes),
        fileName: pdf.fileName,
      ),
      number: invoice.number,
      currency: invoice.currency,
      owedCents: owed,
    );
  }

  /// The lines "E-mail all reachable" sends, once the person confirmed what
  /// will happen; none when they did not.
  Future<List<QueuedReminder>> confirmAll(
    BuildContext context,
    ReminderQueue queue,
  ) async {
    final reachable = this.reachable(queue);
    final rows = lines.value;
    if (reachable.isEmpty) return const [];
    final go = await _confirmQueueMail(
      context,
      mails: [
        for (final l in reachable)
          (
            customer: l.receivable.customerName,
            recipient: rows[l.invoiceId]!.target.recipient,
          ),
      ],
      noAddress: [
        for (final l in queue.remaining)
          if (rows[l.invoiceId]?.target.reason ==
              ReminderMailUnavailable.noAddress)
            l,
      ].length,
      toDecide: queue.toDecide.length,
    );
    return go ? reachable : const [];
  }

  /// A person decides [line]'s e-mail nobody confirmed.
  Future<void> decide(QueuedReminder line, {required bool delivered}) async {
    final send = lines.value[line.invoiceId]?.sentAt(line.level);
    final workspaceId = this.workspaceId;
    if (send == null || workspaceId == null) return;
    await _commands.decide(workspaceId, send, delivered: delivered);
  }

  void _note(QueuedReminder line, QueueMailNote? note) => notes.value = {
    for (final e in notes.value.entries)
      if (e.key != line.invoiceId) e.key: e.value,
    line.invoiceId: ?note,
  };

  void dispose() {
    lines.dispose();
    notes.dispose();
  }
}

/// The words for a line's e-mail: what the server recorded, what only this
/// sitting knows, or why the customer cannot be e-mailed; null for nothing.
String? queueMailText(
  AppLocalizations l10n,
  QueuedReminder line,
  ReminderMailLine? row,
  QueueMailNote? note,
) {
  final send = row?.sentAt(line.level);
  switch (queuedEmailOf(line, row)) {
    case QueuedEmail.sent:
      return l10n.reminderQueueEmailed(send!.recipient);
    case QueuedEmail.toDecide:
      return l10n.purchaseOrderSendAwaits(send!.recipient);
    case QueuedEmail.refused:
      return l10n.reminderEmailRefused(mailRefusalText(l10n, send!.reason));
    case QueuedEmail.none:
      break;
  }
  return switch (note) {
    QueueMailNote.levelMoved => l10n.reminderQueueLevelMoved,
    QueueMailNote.unreached => l10n.reminderQueueEmailUnreached,
    QueueMailNote.notSent => l10n.reminderEmailFailed,
    null => switch (row?.target) {
      ReminderMailTarget(available: true, :final recipient) =>
        l10n.reminderEmailTo(recipient),
      ReminderMailTarget(reason: ReminderMailUnavailable.noAddress) =>
        l10n.reminderEmailNoAddress,
      ReminderMailTarget(reason: ReminderMailUnavailable.senderNotConfigured) =>
        l10n.reminderEmailNoSender,
      _ => null,
    },
  };
}

/// Asks before "E-mail all reachable": how many e-mails, to which
/// addresses, and how many lines stay for sharing and why. Nothing leaves
/// before the person confirms.
Future<bool> _confirmQueueMail(
  BuildContext context, {
  required List<({String customer, String recipient})> mails,
  required int noAddress,
  required int toDecide,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialog) {
        final l10n = dialog.l10n;
        return AlertDialog(
          title: Text(l10n.reminderQueueEmailAllTitle(mails.length)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final m in mails)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                    child: Text('${m.customer} · ${m.recipient}'),
                  ),
                if (noAddress > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.reminderQueueStaysNoAddress(noAddress)),
                ],
                if (toDecide > 0) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Text(l10n.reminderQueueStaysToDecide(toDecide)),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              key: const ValueKey('reminder-queue-email-all-cancel'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
            ),
            FilledButton(
              key: const ValueKey('reminder-queue-email-all-confirm'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.reminderQueueEmailAllConfirm),
            ),
          ],
        );
      },
    ) ??
    false;
