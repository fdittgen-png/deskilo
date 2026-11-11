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
import '../../../../core/ui/kit/bottom_action_bar.dart';
import '../../../../core/ui/kit/kit_card.dart';
import '../../../../core/ui/kit/result_page.dart';
import '../../../../core/ui/kit/status_chip.dart';
import '../../../../core/ui/kit/two_line_row.dart';
import '../../../../l10n/app_localizations.dart';
import '../../application/reminder_queue.dart';
import '../../domain/invoice_report.dart';
import '../../providers/money_providers.dart';
import '../invoice_actions.dart' show requireWorkspaceTaxReference;
import '../invoice_documents.dart';
import '../invoice_journey.dart' show invoiceRemainingCents;
import '../widgets/report_page_style.dart';
import '../widgets/report_preview.dart';

class ReminderQueueScreen extends ConsumerStatefulWidget {
  const ReminderQueueScreen({
    super.key,
    required this.queue,
    required this.today,
    required this.onMatch,
    @visibleForTesting this.letterOf,
    @visibleForTesting this.previewOf,
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

  @override
  ConsumerState<ReminderQueueScreen> createState() =>
      _ReminderQueueScreenState();
}

class _ReminderQueueScreenState extends ConsumerState<ReminderQueueScreen> {
  late final ValueNotifier<ReminderQueue> _queue = ValueNotifier(
    widget.queue ?? const ReminderQueue([]),
  );

  @override
  void didUpdateWidget(ReminderQueueScreen old) {
    super.didUpdateWidget(old);
    final fresh = widget.queue;
    if (fresh != null && !identical(fresh, old.queue)) {
      _queue.value = _queue.value.refreshedBy(fresh);
    }
  }

  /// Who holds money is not known yet: nothing is shared.
  bool get _checking => widget.queue == null;

  /// The invoice being shared (its buttons wait), or null.
  final ValueNotifier<String?> _working = ValueNotifier(null);

  @override
  void dispose() {
    _queue.dispose();
    _working.dispose();
    super.dispose();
  }

  /// The invoice [id], once the archive has answered.
  Future<Invoice?> _invoiceOf(String id) async {
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
    final message = l10n.invoiceReminderMessage(
      invoice.number,
      money.formatMinor(owed),
    );
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
    if (_working.value != null || _checking) return;
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
        child: _LetterPreviewPage(
          title: letter.title,
          report: letter.report,
          images: images,
        ),
      ),
    );
    if (share == true && mounted) await _share(line);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.reminderQueueTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([_queue, _working]),
        builder: (context, _) => _queue.value.isDone
            ? _result(l10n, _queue.value)
            : _list(context, l10n, _queue.value),
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
                              onPressed: () => widget.onMatch(c.customerId),
                              child: Text(l10n.reminderQueueMatch),
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
            FilledButton(
              key: const ValueKey('reminder-queue-next'),
              onPressed: next == null || _working.value != null || _checking
                  ? null
                  : () => _share(next),
              child: Text(
                next == null
                    ? l10n.reminderQueueDoneEmpty
                    : l10n.reminderQueueShareNext(next.receivable.customerName),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _line(AppLocalizations l10n, ReminderQueue q, QueuedReminder line) {
    final r = line.receivable;
    final money = ref.watch(appFormatProvider).moneyIn(r.currency);
    final days = -(r.daysToDue(widget.today) ?? 0);
    final handled = q.handled[line.invoiceId];
    final busy = _working.value != null || _checking;
    final left = handled == ReminderHandled.sharedNotRecorded;
    return Padding(
      key: ValueKey('reminder-queue-line-${line.invoiceId}'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  r.customerName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(money.formatMinor(r.openMinor)),
            ],
          ),
          Text(
            l10n.reminderQueueDetail(days, r.number),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          // A closed share is a notice, not an error: nothing went wrong.
          if (handled == ReminderHandled.notRecorded)
            Text(
              l10n.reminderQueueNotRecorded,
              key: ValueKey('reminder-queue-status-${line.invoiceId}'),
              style: TextStyle(color: Theme.of(context).colorScheme.tertiary),
            ),
          if (left)
            Text(
              l10n.reminderQueueSharedNotRecorded,
              key: ValueKey('reminder-queue-status-${line.invoiceId}'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (handled == ReminderHandled.failed)
            Text(
              l10n.reminderQueueFailed,
              key: ValueKey('reminder-queue-status-${line.invoiceId}'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                key: ValueKey('reminder-queue-preview-${line.invoiceId}'),
                style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
                onPressed: busy ? null : () => _preview(line),
                child: Text(l10n.invoiceTemplatePreview),
              ),
              // It already left: Record, never a second share.
              if (left)
                _recordButton(l10n, line, busy: busy)
              else if (handled == ReminderHandled.shared)
                StatusChip(
                  key: ValueKey('reminder-queue-shared-${line.invoiceId}'),
                  label: l10n.reminderQueueShared,
                  tone: StatusTone.ok,
                )
              else
                FilledButton.tonal(
                  key: ValueKey('reminder-queue-share-${line.invoiceId}'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  onPressed: busy ? null : () => _share(line),
                  child: Text(l10n.reminderQueueShare),
                ),
            ],
          ),
        ],
      ),
    );
  }

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
    return ResultPage(
      key: const ValueKey('reminder-queue-result'),
      tone: q.unrecorded.isEmpty ? ResultTone.ok : ResultTone.partial,
      title: q.shared.isEmpty
          ? l10n.reminderQueueResultNone
          : l10n.reminderQueueResultTitle(q.shared.length),
      subtitle: l10n.reminderQueueResultSubtitle,
      done: [
        for (final l in q.shared)
          line(l, l.receivable.number, l10n.reminderQueueShared),
      ],
      // Shared, but the level is not on the invoice: Record, never Share.
      notDone: [
        for (final l in q.unrecorded)
          line(l, l.receivable.number, l10n.reminderQueueSharedNotRecorded),
      ],
      notDoneActions: [
        for (final l in q.unrecorded)
          _recordButton(l10n, l, busy: _working.value != null),
      ],
      notDoneHeading: l10n.reminderQueueNotRecordedHeading,
      staysNote: l10n.reminderQueueRecordStays,
      doneLabel: l10n.reminderQueueDone,
      onDone: () => Navigator.of(context).maybePop(),
    );
  }
}

/// The reminder letter, laid out as the PDF will be, with Share in the bar.
class _LetterPreviewPage extends StatelessWidget {
  const _LetterPreviewPage({
    required this.title,
    required this.report,
    required this.images,
  });

  final String title;
  final InvoiceReport report;
  final Map<String, Uint8List> images;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: AppSpacing.mdAll,
              child: FittedBox(
                fit: BoxFit.fitWidth,
                child: Container(
                  width: ReportPage.width,
                  color: ReportPage.paper,
                  padding: ReportPage.margins,
                  child: ReportBlocksView(report: report, images: images),
                ),
              ),
            ),
          ),
          BottomActionBar(
            actions: [
              FilledButton(
                key: const ValueKey('reminder-queue-preview-share'),
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.reminderQueueShare),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
