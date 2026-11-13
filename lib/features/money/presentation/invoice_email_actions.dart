// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — an invoice by e-mail, on its page. What the page says is the
// server's rows (0730): "E-mailed to … on …" with "Send again", the
// decision on an e-mail nobody confirmed, a refusal in words, why the
// customer cannot be e-mailed, or "Send by e-mail" to the address shown.
// The invoice is the one share and download print — one builder, one set
// of options — in the invoice's document language, frozen at issue (#3850),
// and so are the subject and the text. One attempt id per press, reused when
// the person retries it.
import 'dart:convert';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/features/enabled_feature_keys.dart';
import '../../../core/i18n/app_format.dart';
import '../../../core/i18n/format_controller.dart';
import '../../../core/ids/request_id.dart';
import '../../../core/l10n/context_l10n.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/trace/guarded.dart';
import '../../../core/ui/app_snack.dart';
import '../../../l10n/app_localizations.dart';
import '../application/invoice_mail_commands.dart';
import '../domain/invoice_mail.dart';
import '../domain/reminder_mail.dart';
import '../providers/invoice_mail_providers.dart';
import '../providers/money_providers.dart';
import 'invoice_documents.dart';
import 'invoice_journey.dart' show invoiceRemainingCents;
import 'invoice_pdf_actions.dart';
import 'mail_refusal_text.dart';

/// Builds [invoice]'s document in [language] for the e-mail: by default
/// the builder share and download use, with their options.
typedef InvoiceMailDocumentBuilder =
    Future<({List<int> bytes, String fileName})> Function(
      Invoice invoice,
      String language,
    );

/// The dialogs and sends of an invoice by e-mail, for one press.
class InvoiceEmailFlow {
  InvoiceEmailFlow(
    this.context,
    this.ref, {
    @visibleForTesting this.documentOf,
    @visibleForTesting this.languageOf,
  });

  final BuildContext context;
  final WidgetRef ref;

  /// A test hands in its own builder; the app uses [_document].
  final InvoiceMailDocumentBuilder? documentOf;

  /// A test hands in the document's language; the app reads the invoice's
  /// own ([invoiceDocumentLocale], #3850).
  final Future<String> Function(Invoice invoice)? languageOf;

  InvoiceMailCommands get _commands => ref.read(invoiceMailCommandsProvider);

  /// The document share and download give. The annexes are asked as they
  /// ask them; null when the person cancelled.
  Future<({List<int> bytes, String fileName})?> _document(Invoice invoice) async {
    final annexes = await askRegroupedAnnexes(context, ref, invoice);
    if (annexes == null || !context.mounted) return null;
    return buildInvoicePdfFile(
      context,
      invoice,
      invoiceShareOptions(context, ref, invoice, annexes),
    );
  }

  /// Sends [invoice] as [kind]: the first e-mail, or "send again".
  Future<void> send(Invoice invoice, InvoiceMailKind kind) async {
    // The business's own rules first (the due date the e-mail states).
    if (!await runGuarded(
          context,
          domain: 'money',
          message: 'invoice e-mail policies read failed',
          errorText: context.l10n.readStateFailed,
          action: () => readDocumentPolicies(ref),
        ) ||
        !context.mounted) {
      return;
    }
    final language = languageOf == null
        ? invoiceDocumentLocale(ref, invoice).language
        : await languageOf!(invoice);
    if (!context.mounted) return;
    ({List<int> bytes, String fileName})? pdf;
    if (!await runGuarded(
          context,
          domain: 'money',
          message: 'invoice e-mail document failed',
          errorText: context.l10n.invoiceEmailFailed,
          action: () async => pdf = documentOf == null
              ? await _document(invoice)
              : await documentOf!(invoice, language),
        ) ||
        !context.mounted ||
        pdf == null) {
      return;
    }
    final letter = _commands.letter(
      l10n: l10nForLanguage(language),
      document: (
        title: '',
        language: language,
        pdfBase64: base64Encode(pdf!.bytes),
        fileName: pdf!.fileName,
      ),
      number: invoice.number,
      amounts: (
        currency: invoice.currency,
        totalCents: invoice.totalCents,
        owedCents: invoiceRemainingCents(
          invoice,
          ref.read(invoiceMatchesProvider).value?[invoice.id],
        ),
        dueOn: invoiceDueAt(ref, invoice),
      ),
    );
    final attemptId = newRequestId();
    InvoiceMailAnswer answer;
    do {
      answer = await _commands.send(
        workspaceId: invoice.workspaceId,
        invoiceId: invoice.id,
        kind: kind,
        attemptId: attemptId,
        letter: letter,
      );
      if (!context.mounted) return;
    } while (answer is InvoiceMailUnreached && await _retry());
    if (context.mounted) await _tell(invoice, answer);
  }

  Future<void> _tell(Invoice invoice, InvoiceMailAnswer answer) async {
    final l10n = context.l10n;
    _refresh(invoice);
    switch (answer) {
      case InvoiceMailAnswered(:final send):
        switch (send.state) {
          case ReminderMailState.accepted:
            AppSnack.success(context, l10n.purchaseOrderSentTo(send.recipient));
          case ReminderMailState.refused:
            AppSnack.error(
              context,
              l10n.invoiceEmailRefused(mailRefusalText(l10n, send.reason)),
            );
          case _:
            AppSnack.error(context, l10n.invoiceEmailUnconfirmed);
        }
      case InvoiceMailToDecide(:final waiting?):
        await decide(invoice, waiting);
      case InvoiceMailToDecide():
        AppSnack.error(context, l10n.invoiceEmailUnconfirmed);
      case InvoiceMailNotSent() || InvoiceMailUnreached():
        AppSnack.error(context, l10n.invoiceEmailFailed);
    }
  }

  /// Asks whether to try a press again that may not have reached the
  /// server; the same attempt id keeps it from leaving twice.
  Future<bool> _retry() async {
    final again = await showDialog<bool>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(dialog.l10n.reminderEmailRetry),
        actions: [
          TextButton(
            key: const ValueKey('invoice-email-retry-cancel'),
            onPressed: () => Navigator.of(dialog).pop(false),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          FilledButton(
            key: const ValueKey('invoice-email-retry'),
            onPressed: () => Navigator.of(dialog).pop(true),
            child: Text(dialog.l10n.commonRetry),
          ),
        ],
      ),
    );
    return again == true && context.mounted;
  }

  /// A person decides [send], an e-mail nobody could confirm.
  Future<void> decide(
    Invoice invoice,
    InvoiceMailSend send, {
    bool? delivered,
  }) async {
    final answer =
        delivered ??
        await showDialog<bool>(
          context: context,
          builder: (dialog) => AlertDialog(
            content: Text(dialog.l10n.purchaseOrderSendAwaits(send.recipient)),
            actions: [
              TextButton(
                key: const ValueKey('invoice-email-decide-lost'),
                onPressed: () => Navigator.of(dialog).pop(false),
                child: Text(dialog.l10n.purchaseOrderSendLost),
              ),
              FilledButton(
                key: const ValueKey('invoice-email-decide-arrived'),
                onPressed: () => Navigator.of(dialog).pop(true),
                child: Text(dialog.l10n.purchaseOrderSendArrived),
              ),
            ],
          ),
        );
    if (answer == null || !context.mounted) return;
    if (await runGuarded(
      context,
      domain: 'money',
      message: 'invoice e-mail decision failed',
      errorText: context.l10n.reminderEmailDecisionFailed,
      action: () =>
          _commands.decide(invoice.workspaceId, send, delivered: answer),
    )) {
      _refresh(invoice);
    }
  }

  void _refresh(Invoice invoice) => ref.invalidate(
    invoiceMailViewProvider((
      workspaceId: invoice.workspaceId,
      invoiceId: invoice.id,
    )),
  );
}

/// The invoice page's e-mail: nothing while invoices by e-mail are off.
class InvoiceEmailPanel extends ConsumerWidget {
  const InvoiceEmailPanel({super.key, required this.invoice});

  final Invoice invoice;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!featureOn(
      ref.watch(enabledFeatureKeysProvider),
      invoiceEmailKey,
      byDefault: false,
    )) {
      return const SizedBox.shrink();
    }
    final view = ref
        .watch(
          invoiceMailViewProvider((
            workspaceId: invoice.workspaceId,
            invoiceId: invoice.id,
          )),
        )
        .value;
    if (view == null) return const SizedBox.shrink();
    final l10n = context.l10n;
    final flow = InvoiceEmailFlow(context, ref);
    final latest = view.latest;
    final left = view.lastLeft;
    final waiting = latest != null && latest.awaitsDecision ? latest : null;
    final date = appFormatOf(context).dates(DateShape.date);
    return Column(
      key: const ValueKey('invoice-email'),
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: AppSpacing.xs,
      children: [
        Text(
          l10n.invoiceEmailHeading,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        Text(
          _status(l10n, view, date.format),
          key: const ValueKey('invoice-email-state'),
        ),
        if (waiting != null)
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              TextButton(
                key: const ValueKey('invoice-email-lost'),
                onPressed: () =>
                    flow.decide(invoice, waiting, delivered: false),
                child: Text(l10n.purchaseOrderSendLost),
              ),
              FilledButton.tonal(
                key: const ValueKey('invoice-email-arrived'),
                onPressed: () => flow.decide(invoice, waiting, delivered: true),
                child: Text(l10n.purchaseOrderSendArrived),
              ),
            ],
          )
        else if (view.available)
          FilledButton.tonal(
            key: ValueKey(
              left == null ? 'invoice-email-send' : 'invoice-email-again',
            ),
            onPressed: () => flow.send(
              invoice,
              left == null ? InvoiceMailKind.first : InvoiceMailKind.resend,
            ),
            child: Text(
              left == null
                  ? l10n.purchaseOrderSendEmail
                  : l10n.invoiceEmailSendAgain,
            ),
          ),
      ],
    );
  }

  /// What the rows say, newest first: a decision to take, a refusal, the
  /// last e-mail that left, or to whom (or why not) it would go.
  static String _status(
    AppLocalizations l10n,
    InvoiceMailView view,
    String Function(DateTime) date,
  ) {
    final latest = view.latest;
    final left = view.lastLeft;
    if (latest != null && latest.awaitsDecision) {
      return l10n.purchaseOrderSendAwaits(latest.recipient);
    }
    if (latest?.state == ReminderMailState.refused) {
      return l10n.invoiceEmailRefused(mailRefusalText(l10n, latest!.reason));
    }
    // The day it left, as the reminder history shows its days.
    if (left?.finishedAt ?? left?.createdAt case final at?) {
      return l10n.invoiceEmailSentOn(left!.recipient, date(at));
    }
    return switch (view.reason) {
      InvoiceMailUnavailable.none => l10n.reminderEmailTo(view.recipient),
      InvoiceMailUnavailable.voided => l10n.invoiceEmailVoided,
      InvoiceMailUnavailable.noAddress => l10n.reminderEmailNoAddress,
      InvoiceMailUnavailable.senderNotConfigured => l10n.reminderEmailNoSender,
      InvoiceMailUnavailable.featureOff => l10n.reminderEmailOff,
    };
  }
}
