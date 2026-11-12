// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — a payment reminder by e-mail, its dialogs. With reminders by
// e-mail on, the person first chooses how the letter leaves: by e-mail to
// the customer's address on file (shown before anything is sent), or shared
// as before. A customer the e-mail cannot reach says why in that list. The
// letter, its subject and its text are in the customer's document language,
// never the sender's on a guess. One attempt id per press, reused when the
// person retries it; an e-mail nobody confirmed is decided by a person,
// never sent again. The decisions are ReminderMailCommands'.
import 'dart:convert';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/features/enabled_feature_keys.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/trace/trace_logger.dart';
import '../../../core/ui/app_sheet.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../application/reminder_mail_commands.dart';
import '../domain/reminder_mail.dart';
import '../providers/money_providers.dart';
import '../providers/reminder_evidence_providers.dart';
import '../providers/reminder_mail_providers.dart';
import 'invoice_documents.dart' show l10nForLanguage;

/// How a reminder leaves.
enum ReminderChannel { email, share }

/// The reminder letter as built for one invoice and level.
typedef ReminderLetterPdf = ({
  List<int> bytes,
  String fileName,
  String title,
  String language,
});

/// The dialogs of a reminder by e-mail, for one press.
class ReminderEmailFlow {
  ReminderEmailFlow(this.context, this.ref);

  final BuildContext context;
  final WidgetRef ref;

  ReminderMailCommands get _commands => ref.read(reminderMailCommandsProvider);

  /// Asks how the reminder of [invoice] leaves. Share, without asking, while
  /// reminders by e-mail are off; null when the person cancelled, the server
  /// could not be read, or an earlier e-mail first needed their decision.
  Future<ReminderChannel?> choose(Invoice invoice) async {
    if (!featureOn(
      ref.read(enabledFeatureKeysProvider),
      reminderEmailKey,
      byDefault: false,
    )) {
      return ReminderChannel.share;
    }
    ({ReminderMailTarget target, List<ReminderMailSend> waiting})? reach;
    if (!await runGuarded(
          context,
          domain: 'money',
          message: 'reminder e-mail target read failed',
          errorText: context.l10n.readStateFailed,
          action: () async =>
              reach = await _commands.reach(invoice.workspaceId, invoice.id),
        ) ||
        !context.mounted) {
      return null;
    }
    if (reach!.waiting.isNotEmpty) {
      await _decide(invoice, reach!.waiting.first);
      return null;
    }
    return _ask(reach!.target);
  }

  Future<ReminderChannel?> _ask(ReminderMailTarget target) =>
      showAppSheet<ReminderChannel>(
        context: context,
        showDragHandle: true,
        builder: (sheet) {
          final l10n = sheet.l10n;
          return SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  key: const ValueKey('reminder-channel-email'),
                  enabled: target.available,
                  leading: const Icon(Icons.alternate_email),
                  title: Text(l10n.purchaseOrderSendEmail),
                  subtitle: Text(
                    target.available
                        ? l10n.reminderEmailTo(target.recipient)
                        : _unavailable(l10n, target.reason),
                  ),
                  onTap: () => Navigator.of(sheet).pop(ReminderChannel.email),
                ),
                ListTile(
                  key: const ValueKey('reminder-channel-share'),
                  leading: const Icon(Icons.ios_share),
                  title: Text(l10n.reminderChannelShare),
                  onTap: () => Navigator.of(sheet).pop(ReminderChannel.share),
                ),
              ],
            ),
          );
        },
      );

  static String _unavailable(
    AppLocalizations l10n,
    ReminderMailUnavailable reason,
  ) => switch (reason) {
    ReminderMailUnavailable.noAddress => l10n.reminderEmailNoAddress,
    ReminderMailUnavailable.senderNotConfigured => l10n.reminderEmailNoSender,
    ReminderMailUnavailable.featureOff ||
    ReminderMailUnavailable.none => l10n.reminderEmailOff,
  };

  /// Builds the letter of [invoice] at [level] with [letter], then e-mails
  /// it; a letter that cannot be built sends nothing.
  Future<void> build(
    Invoice invoice, {
    required int level,
    required int owedCents,
    required Future<ReminderLetterPdf> Function() letter,
  }) async {
    ReminderLetterPdf? pdf;
    if (!await runGuarded(
          context,
          domain: 'money',
          message: 'reminder e-mail letter failed',
          errorText: context.l10n.reminderEmailFailed,
          action: () async => pdf = await letter(),
        ) ||
        !context.mounted) {
      return;
    }
    await email(invoice, level: level, owedCents: owedCents, pdf: pdf!);
  }

  /// E-mails [pdf], the letter of [invoice] at [level]; [owedCents] is what
  /// is still owed.
  Future<void> email(
    Invoice invoice, {
    required int level,
    required int owedCents,
    required ReminderLetterPdf pdf,
  }) async {
    // No language, no e-mail: the server never chooses one, and neither does
    // the app on the sender's behalf.
    if (pdf.language.isEmpty) {
      AppSnack.error(context, context.l10n.reminderEmailNoLanguage);
      return;
    }
    final letter = _commands.letter(
      l10n: l10nForLanguage(pdf.language),
      document: (
        title: pdf.title,
        language: pdf.language,
        pdfBase64: base64Encode(pdf.bytes),
        fileName: pdf.fileName,
      ),
      number: invoice.number,
      currency: invoice.currency,
      owedCents: owedCents,
    );
    final attemptId = newRequestId();
    ReminderMailAnswer answer;
    do {
      answer = await _commands.send(
        workspaceId: invoice.workspaceId,
        invoiceId: invoice.id,
        level: level,
        attemptId: attemptId,
        letter: letter,
      );
      if (!context.mounted) return;
    } while (answer is ReminderMailUnreached && await _retry(answer));
    if (context.mounted) await _tell(invoice, answer);
  }

  Future<void> _tell(Invoice invoice, ReminderMailAnswer answer) async {
    final l10n = context.l10n;
    switch (answer) {
      case ReminderMailAnswered(:final send):
        _refresh(invoice);
        switch (send.state) {
          case ReminderMailState.accepted:
            AppSnack.success(context, l10n.purchaseOrderSentTo(send.recipient));
          case ReminderMailState.refused:
            AppSnack.error(context, l10n.reminderEmailRefused(send.reason));
          case _:
            AppSnack.error(context, l10n.reminderEmailUnconfirmed);
        }
      case ReminderMailLevelMoved():
        AppSnack.error(context, l10n.reminderEmailLevelChanged);
      case ReminderMailToDecide(:final waiting) when waiting.isNotEmpty:
        await _decide(invoice, waiting.first);
      case ReminderMailToDecide():
        AppSnack.error(context, l10n.reminderEmailUnconfirmed);
      case ReminderMailNotSent() || ReminderMailUnreached():
        AppSnack.error(context, l10n.reminderEmailFailed);
    }
  }

  /// Asks whether to try a press again that may not have reached the
  /// server; the same attempt id keeps it from leaving twice.
  Future<bool> _retry(ReminderMailUnreached unreached) async {
    TraceLogger.instance.error(
      'money',
      'reminder e-mail failed',
      error: unreached.error,
    );
    final again = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(dialog.l10n.reminderEmailRetry),
        actions: [
          TextButton(
            key: const ValueKey('reminder-email-retry-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('reminder-email-retry'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(dialog.l10n.commonRetry),
          ),
        ],
      ),
    );
    return again == true && context.mounted;
  }

  /// A person decides an e-mail nobody could confirm: did it arrive?
  Future<void> _decide(Invoice invoice, ReminderMailSend send) async {
    final delivered = await showDialog<bool>(
      context: context,
      builder: (dialog) {
        final l10n = dialog.l10n;
        return AlertDialog(
          content: Text(l10n.purchaseOrderSendAwaits(send.recipient)),
          actions: [
            TextButton(
              key: const ValueKey('reminder-email-decide-cancel'),
              onPressed: () => Navigator.of(dialog).pop(),
              child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
            ),
            TextButton(
              key: const ValueKey('reminder-email-lost'),
              onPressed: () => Navigator.of(dialog).pop(false),
              child: Text(l10n.purchaseOrderSendLost),
            ),
            FilledButton(
              key: const ValueKey('reminder-email-arrived'),
              onPressed: () => Navigator.of(dialog).pop(true),
              child: Text(l10n.purchaseOrderSendArrived),
            ),
          ],
        );
      },
    );
    if (delivered == null || !context.mounted) return;
    if (await runGuarded(
      context,
      domain: 'money',
      message: 'reminder e-mail decision failed',
      errorText: context.l10n.reminderEmailDecisionFailed,
      action: () =>
          _commands.decide(invoice.workspaceId, send, delivered: delivered),
    )) {
      _refresh(invoice);
    }
  }

  void _refresh(Invoice invoice) => ref
    ..invalidate(invoiceRemindersProvider)
    ..invalidate(reminderEvidenceProvider(invoice.id));
}
