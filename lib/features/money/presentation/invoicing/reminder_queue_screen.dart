// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3587 R1-f -- the reminders shared BY HAND: grouped by level, one Share per
// line, a Preview of the letter, and a bottom bar "Share the next one ·
// {customer}". Sharing is not sending: the letter goes through the device's
// share sheet and a level is recorded only if it left; a closed sheet says
// nothing was recorded and the line stays. Ends on a result page of what was
// shared. When the rules send reminders by themselves this screen is not
// offered.
import 'dart:async';

import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/i18n/format_controller.dart';
import '../../../../core/l10n/context_l10n.dart';
import '../../../../core/share/file_sharer.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/trace/trace_logger.dart';
import '../../../../core/ui/app_snack.dart';
import '../../../../core/ui/kit/bottom_action_bar.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/page_bar.dart';
import '../../../../core/ui/kit/result_page.dart';
import '../../../../core/ui/kit/two_line_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/reminder_queue.dart';
import '../../domain/invoice_report.dart';
import '../../domain/reminder_mail.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart' show requireWorkspaceTaxReference;
import '../invoice_documents.dart';
import '../invoice_journey.dart' show invoiceRemainingCents;
import 'reminder_letter_preview_page.dart';
import 'reminder_queue_line.dart';
import 'reminder_queue_mail.dart';

class ReminderQueueScreen extends ConsumerStatefulWidget {
  const ReminderQueueScreen({
    super.key,
    required this.queue,
    required this.today,
    required this.onMatch,
    @visibleForTesting this.letterOf,
    @visibleForTesting this.previewOf,
    @visibleForTesting this.mailOf,
  });

  /// The lines waiting, as [reminderQueueOf] draws them from the current
  /// reads; null while who holds money received and not assigned is not
  /// known: nothing can be shared until it is. A new queue (the reads
  /// changed) replaces the lines, keeping what already left the device.
  final ReminderQueue? queue;

  /// The business's calendar day (how late each line is).
  final DateTime today;

  /// Opens Payments to match for a customer listed under "Check first".
  final ValueChanged<String> onMatch;

  /// Builds a line's letter; the real one renders the owner's reminder
  /// letter. A test hands in a plain one: the rendering has its own tests.
  final Future<ReminderLetter> Function(QueuedReminder line, Invoice invoice)?
  letterOf;

  /// Builds a line's letter as it is shown on screen; a test hands in a plain
  /// one for the same reason.
  final Future<({String title, InvoiceReport report})> Function(
    QueuedReminder line,
    Invoice invoice,
  )?
  previewOf;

  /// Builds a line's e-mail (#3673) in the language of the invoice it
  /// reminds of (#3850). A test hands in a plain one.
  final Future<ReminderMailLetter> Function(
    QueuedReminder line,
    Invoice invoice,
  )?
  mailOf;

  @override
  ConsumerState<ReminderQueueScreen> createState() =>
      _ReminderQueueScreenState();
}

class _ReminderQueueScreenState extends ConsumerState<ReminderQueueScreen> {
  late final ValueNotifier<ReminderQueue> _queue = ValueNotifier(
    widget.queue ?? const ReminderQueue([]),
  );

  /// #3673 — the queue's e-mail, read from the server's rows.
  late final ReminderQueueMail _mail = ReminderQueueMail(ref);

  /// The queue with what the server recorded for each line's e-mail.
  ReminderQueue get _q => _queue.value.withEmail(_mail.statesOf(_queue.value));

  @override
  void initState() {
    super.initState();
    _mail.follow(() => unawaited(_reload()));
  }

  @override
  void didUpdateWidget(ReminderQueueScreen old) {
    super.didUpdateWidget(old);
    final fresh = widget.queue;
    if (fresh != null && !identical(fresh, old.queue)) {
      _queue.value = _queue.value.refreshedBy(fresh);
      unawaited(_reload());
    }
  }

  /// Reads the server's e-mail rows of the queue's invoices again.
  Future<void> _reload() =>
      _mail.refresh([for (final l in _queue.value.lines) l.invoiceId]);

  /// Who holds money is not known yet: nothing is shared.
  bool get _checking => widget.queue == null;

  /// The invoice being shared (its buttons wait), or null.
  final ValueNotifier<String?> _working = ValueNotifier(null);

  @override
  void dispose() {
    _mail.dispose();
    _queue.dispose();
    _working.dispose();
    super.dispose();
  }

  /// The invoice [id], once the archive has answered.
  Future<Invoice?> _invoiceOf(String id) async {
    await readDocumentPolicies(ref); // #3742 — the letter's policies, read
    final invoices = await ref.read(invoicesProvider.future);
    return invoices.where((i) => i.id == id).firstOrNull;
  }

  /// The letter and its message for [line], read before any wait.
  Future<ReminderLetter> _letterOf(QueuedReminder line, Invoice invoice) async {
    final l10n = context.l10n;
    final money = ref.read(appFormatProvider).moneyIn(invoice.currency);
    final owed = invoiceRemainingCents(
      invoice,
      ref.read(invoiceMatchesProvider).value?[invoice.id],
    );
    final message =
        l10n.invoiceReminderMessage(invoice.number, money.formatMinor(owed));
    final pdf = await buildReminderPdfFile(
      context,
      ref,
      invoice,
      level: line.level,
      reference: requireWorkspaceTaxReference(ref),
    );
    return (
      bytes: Uint8List.fromList(pdf.bytes),
      fileName: pdf.fileName,
      message: message,
    );
  }

  void _settle(QueuedReminder line, ReminderHandled result) =>
      _queue.value = _queue.value.withResult(line.invoiceId, result);

  Future<void> _share(QueuedReminder line) async {
    // A letter that left is never shared again: Record only.
    if (_working.value != null || _checking) return;
    if (_q.hasLeft(line)) return;
    _working.value = line.invoiceId;
    try {
      final invoice = await _invoiceOf(line.invoiceId);
      if (invoice == null) return _settle(line, ReminderHandled.failed);
      final ReminderLetter letter;
      try {
        letter = await (widget.letterOf ?? _letterOf)(line, invoice);
      } on Object {
        return _settle(line, ReminderHandled.failed);
      }
      final result = await shareQueuedReminder(
        line: line,
        repository: ref.read(invoiceCommandsProvider),
        share: ref.read(fileSharerProvider),
        letter: letter,
      );
      _settle(line, result);
      ref.invalidate(invoiceRemindersProvider);
    } finally {
      if (mounted) _working.value = null;
    }
  }

  /// E-mails [lines], each its own attempt, one after the other: a refused
  /// or unconfirmed line does not stop the rest. What each shows afterwards
  /// is the server's row, read again.
  Future<void> _email(List<QueuedReminder> lines) async {
    if (_working.value != null || _checking) return;
    final letterOf =
        widget.mailOf ?? (l, i) => _mail.letterOf(context, l, i);
    try {
      for (final line in lines) {
        if (!mounted || _q.hasLeft(line)) continue;
        _working.value = line.invoiceId;
        final invoice = await _invoiceOf(line.invoiceId);
        if (invoice == null || !mounted) continue;
        try {
          await _mail.send(line, await letterOf(line, invoice));
        } on Object catch (e, st) {
          TraceLogger.instance.error('money', 'reminder queue e-mail failed',
              error: e, stackTrace: st);
          _settle(line, ReminderHandled.failed);
        }
      }
      await _reload();
      ref.invalidate(invoiceRemindersProvider);
    } finally {
      if (mounted) _working.value = null;
    }
  }

  /// "E-mail all reachable", after the person confirmed what will happen.
  Future<void> _emailAll() async {
    final lines = await _mail.confirmAll(context, _q);
    if (lines.isNotEmpty && mounted) await _email(lines);
  }

  /// A person decides [line]'s e-mail nobody confirmed.
  Future<void> _decide(QueuedReminder line, {required bool delivered}) async {
    if (_working.value != null) return;
    _working.value = line.invoiceId;
    try {
      await _mail.decide(line, delivered: delivered);
      await _reload();
      ref.invalidate(invoiceRemindersProvider);
    } on Object catch (e, st) {
      TraceLogger.instance.error('money', 'reminder queue decision failed',
          error: e, stackTrace: st);
      if (mounted) {
        AppSnack.error(context, context.l10n.reminderEmailDecisionFailed);
      }
    } finally {
      if (mounted) _working.value = null;
    }
  }

  /// Records a reminder that already left: the record only, no share.
  Future<void> _record(QueuedReminder line) async {
    if (_working.value != null) return;
    _working.value = line.invoiceId;
    try {
      _settle(
        line,
        await recordQueuedReminder(
          line: line,
          repository: ref.read(invoiceCommandsProvider),
        ),
      );
      ref.invalidate(invoiceRemindersProvider);
    } finally {
      if (mounted) _working.value = null;
    }
  }

  /// The real letter: the owner's bands, in the member's language.
  Future<({String title, InvoiceReport report})> _previewOf(
    QueuedReminder line,
    Invoice invoice,
  ) async {
    final letter = await reminderLetterReport(
      ref,
      context,
      invoice,
      level: line.level,
      reference: requireWorkspaceTaxReference(ref),
    );
    return (title: '${letter.title} ${invoice.number}', report: letter.report);
  }

  /// The letter on screen, as it will be shared; Share is in that view's bar.
  Future<void> _preview(QueuedReminder line) async {
    final invoice = await _invoiceOf(line.invoiceId);
    if (invoice == null || !mounted) return;
    final letter = await (widget.previewOf ?? _previewOf)(line, invoice);
    final images = widget.previewOf != null
        ? const <String, Uint8List>{}
        : await resolveReportImages(ref, letter.report);
    if (!mounted) return;
    final share = await showDialog<bool>(
      context: context,
      builder: (_) => Dialog.fullscreen(
        child: ReminderLetterPreviewPage(
          title: letter.title,
          report: letter.report,
          images: images,
          canShare: !_q.hasLeft(line),
        ),
      ),
    );
    if (share == true && mounted) await _share(line);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: pageBar(context, title: l10n.reminderQueueTitle),
      body: ListenableBuilder(
        listenable: Listenable.merge(
          [_queue, _working, _mail.lines, _mail.notes],
        ),
        builder: (context, _) => _q.isDone
            ? _result(l10n, _q)
            : _list(context, l10n, _q),
      ),
    );
  }

  Widget _list(BuildContext context, AppLocalizations l10n, ReminderQueue q) {
    final next = q.next;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppSpacing.mdAll,
            children: [
              QuietLine(l10n.reminderQueueIntro, icon: Icons.info_outline),
              if (_checking) ...[
                const SizedBox(height: AppSpacing.sm),
                QuietLine(
                  l10n.invoicingCheckingPayments,
                  key: const ValueKey('reminder-queue-checking'),
                ),
              ],
              // Their money is held unassigned: not chased, checked FIRST.
              if (q.checkFirst.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.md),
                KitLabel(l10n.reminderQueueCheckFirst),
                const SizedBox(height: AppSpacing.sm),
                RowList(
                  rows: [
                    for (final c in q.checkFirst)
                      Padding(
                        key: ValueKey('reminder-queue-check-${c.customerId}'),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                c.customerName,
                                style: Theme.of(context).textTheme.titleSmall,
                              ),
                            ),
                            FilledButton.tonal(
                              key: ValueKey(
                                'reminder-queue-match-${c.customerId}',
                              ),
                              style: FilledButton.styleFrom(
                                minimumSize: const Size(48, 48),
                              ),
                              onPressed: _checking
                                  ? null
                                  : () => widget.onMatch(c.customerId),
                              child: Text(l10n.invoicingActionMatch),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
              for (final level in q.levels) ...[
                const SizedBox(height: AppSpacing.md),
                KitLabel(l10n.reminderQueueLevel(level)),
                const SizedBox(height: AppSpacing.sm),
                RowList(
                  rows: [for (final l in q.ofLevel(level)) _line(l10n, q, l)],
                ),
              ],
            ],
          ),
        ),
        BottomActionBar(
          actions: [
            if (_mail.reachable(q).isNotEmpty)
              FilledButton.tonal(
                key: const ValueKey('reminder-queue-email-all'),
                onPressed: _working.value != null || _checking
                    ? null
                    : _emailAll,
                child: Text(
                  l10n.reminderQueueEmailAll(_mail.reachable(q).length),
                ),
              ),
            FilledButton(
              key: const ValueKey('reminder-queue-next'),
              onPressed: next == null || _working.value != null || _checking
                  ? null
                  : () => _share(next),
              child: Text(
                next != null
                    ? l10n.reminderQueueShareNext(next.receivable.customerName)
                    : _checking
                    ? l10n.reminderQueueShare
                    : l10n.reminderQueueDoneEmpty,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _line(AppLocalizations l10n, ReminderQueue q, QueuedReminder line) =>
      ReminderQueueLineView(
        line: line,
        queue: q,
        today: widget.today,
        busy: _working.value != null || _checking,
        row: _mail.lines.value[line.invoiceId],
        mailText: _mail.on
            ? queueMailText(l10n, line, _mail.lines.value[line.invoiceId],
                _mail.notes.value[line.invoiceId])
            : null,
        actions: (
          onPreview: () => _preview(line),
          onShare: () => _share(line),
          onRecord: () => _record(line),
          onEmail: () => _email([line]),
          onDecide: ({required delivered}) =>
              _decide(line, delivered: delivered),
        ),
      );

  Widget _recordButton(
    AppLocalizations l10n,
    QueuedReminder line, {
    required bool busy,
  }) => FilledButton.tonal(
    key: ValueKey('reminder-queue-record-${line.invoiceId}'),
    style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
    onPressed: busy ? null : () => _record(line),
    child: Text(l10n.reminderQueueRecord),
  );

  Widget _result(AppLocalizations l10n, ReminderQueue q) {
    ResultLine line(QueuedReminder l, String detail, String outcome) =>
        (title: l.receivable.customerName, detail: detail, outcome: outcome);
    // #3673 — e-mailed and to decide are the server's rows, read again.
    String mailText(QueuedReminder l) =>
        queueMailText(l10n, l, _mail.lines.value[l.invoiceId], null) ?? '';
    final sent = q.shared.length + q.emailed.length;
    final busy = _working.value != null;
    return ResultPage(
      key: const ValueKey('reminder-queue-result'),
      tone: q.unrecorded.isEmpty && q.toDecide.isEmpty
          ? ResultTone.ok
          : ResultTone.partial,
      title: sent == 0
          ? l10n.reminderQueueResultNone
          : q.emailed.isEmpty
          ? l10n.reminderQueueResultTitle(sent)
          : l10n.reminderQueueResultSentTitle(sent),
      subtitle: l10n.reminderQueueResultSubtitle,
      done: [
        for (final l in q.shared)
          line(l, l.receivable.number, l10n.reminderQueueShared),
        for (final l in q.emailed) line(l, l.receivable.number, mailText(l)),
      ],
      // Shared, but the level is not on the invoice: Record, never Share.
      // An e-mail nobody confirmed: the person decides it.
      notDone: [
        for (final l in q.unrecorded)
          line(l, l.receivable.number, l10n.reminderQueueSharedNotRecorded),
        for (final l in q.toDecide) line(l, l.receivable.number, mailText(l)),
      ],
      notDoneActions: [
        for (final l in q.unrecorded) _recordButton(l10n, l, busy: busy),
        for (final l in q.toDecide)
          FilledButton.tonal(
            key: ValueKey('reminder-queue-result-arrived-${l.invoiceId}'),
            onPressed: busy ? null : () => _decide(l, delivered: true),
            child: Text(l10n.purchaseOrderSendArrived),
          ),
      ],
      notDoneHeading: q.toDecide.isEmpty
          ? l10n.reminderQueueNotRecordedHeading
          : l10n.reminderQueueStillOpenHeading,
      staysNote: l10n.reminderQueueRecordStays,
      doneLabel: l10n.reminderQueueDone,
      onDone: () => Navigator.of(context).maybePop(),
    );
  }
}
