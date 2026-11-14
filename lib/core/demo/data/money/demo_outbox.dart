// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3960 — the Demo's outbox: an invoice or a reminder "sent by e-mail" is
// RECORDED here, in memory, and answered as the server answers a send that
// the provider accepted. Nothing leaves the device (the way the push
// endpoints of demo_outward_edges.dart record an attempt instead of
// sending); the Demo's own notice already says so.
//
// The rules mirror the server's (0726 reminders, 0730 invoices) where the
// Demo can know them: the customer's address on file (a refusal in the
// server's words), the first e-mail of an invoice and a reminder level once,
// the same attempt id replaying the same send, and a reminder only for an
// invoice that still owes. What only the provider could say (an e-mail
// nobody can confirm) is never produced here: every send is accepted.
import 'package:deskilo_invoice_model/deskilo_invoice_model.dart';

import '../../../../features/money/domain/invoice_mail.dart';
import '../../../../features/money/domain/reminder_mail.dart';
import '../../demo_fixture.dart';
import '../../demo_space_ids.dart';

/// #3960 — the member of the main space the Demo holds no e-mail address
/// for: the refusal "no address on file" is reachable on their bills.
const demoMemberWithoutAddress = 'member-3';

/// What an e-mail of the outbox was.
enum DemoMailKind { invoice, reminder }

/// One message the outbox holds: what the server's row and the letter say.
class DemoMailRecord {
  const DemoMailRecord({
    required this.kind,
    required this.attemptId,
    required this.invoiceId,
    required this.level,
    required this.recipient,
    required this.subject,
    required this.fileName,
    required this.language,
    required this.at,
    this.resend = false,
  });

  final DemoMailKind kind;
  final String attemptId;
  final String invoiceId;

  /// The reminder level; 0 for an invoice.
  final int level;
  final String recipient;
  final String subject;

  /// The name of the attached document.
  final String fileName;
  final String language;
  final DateTime at;
  final bool resend;
}

/// The Demo's in-memory outbox; [DemoReminderMail] and [DemoInvoiceMail]
/// are its two faces.
class DemoOutbox {
  DemoOutbox._(this._fixture) {
    _seed();
  }

  static final Expando<DemoOutbox> _perSession = Expando<DemoOutbox>();

  /// The outbox of the session [fixture]: one per session, so a switch of
  /// persona reaches the same messages.
  static DemoOutbox of(DemoFixture fixture) =>
      _perSession[fixture] ??= DemoOutbox._(fixture);

  /// The refusal for a customer without an address, in the server's words
  /// (`begin_reminder_email_v1`, 0726).
  static const noAddressMessage = 'the customer has no e-mail address on file';

  final DemoFixture _fixture;
  final List<DemoMailRecord> _records = [];

  /// Every message recorded, oldest first.
  List<DemoMailRecord> get sent => List.unmodifiable(_records);

  DateTime get _now => _fixture.seededAt;

  String _addressOf(String invoiceId) {
    final invoice = _invoice(invoiceId);
    if (invoice == null) return '';
    return _fixture.workspaces.memberEmails[invoice.memberId] ?? '';
  }

  Invoice? _invoice(String id) =>
      _fixture.money.invoices.where((i) => i.id == id).firstOrNull;

  bool _owes(String invoiceId) {
    final invoice = _invoice(invoiceId);
    if (invoice == null) return false;
    final paid = _fixture.money.invoiceMatchesStore[invoiceId]?.paidCents ?? 0;
    return invoice.totalCents > paid;
  }

  /// Already sent when the Demo opens, on the Demo's day: one invoice e-mailed
  /// when it was issued, and the reminder the bill of Bruno already carries.
  void _seed() {
    const sentInvoice = 'demo-invoice-bruno';
    final invoice = _invoice(sentInvoice);
    final address = _addressOf(sentInvoice);
    if (invoice != null && address.isNotEmpty) {
      _records.add(
        DemoMailRecord(
          kind: DemoMailKind.invoice,
          attemptId: 'demo-mail-seed-invoice',
          invoiceId: sentInvoice,
          level: 0,
          recipient: address,
          subject: invoice.number,
          fileName: '${invoice.number}.pdf',
          language: 'fr',
          at: invoice.issuedAt,
        ),
      );
    }
    final reminded = _fixture.money.invoiceReminders[sentInvoice];
    if (reminded != null && reminded.isNotEmpty && address.isNotEmpty) {
      _records.add(
        DemoMailRecord(
          kind: DemoMailKind.reminder,
          attemptId: 'demo-mail-seed-reminder',
          invoiceId: sentInvoice,
          level: 1,
          recipient: address,
          subject: 'Rappel ${invoice?.number}',
          fileName: 'rappel-${invoice?.number}.pdf',
          language: 'fr',
          at: reminded.first,
        ),
      );
    }
  }

  Iterable<DemoMailRecord> _of(DemoMailKind kind) =>
      _records.where((r) => r.kind == kind);

  ReminderMailTarget _target(String workspaceId, String invoiceId) {
    if (workspaceId != demoFirstSpaceId) {
      return const ReminderMailTarget(
        available: false,
        reason: ReminderMailUnavailable.featureOff,
      );
    }
    final address = _addressOf(invoiceId);
    return address.isEmpty
        ? const ReminderMailTarget(
            available: false,
            reason: ReminderMailUnavailable.noAddress,
          )
        : ReminderMailTarget(available: true, recipient: address);
  }

  ReminderMailSend _reminderSend(DemoMailRecord r) => ReminderMailSend(
    id: r.attemptId,
    invoiceId: r.invoiceId,
    level: r.level,
    state: ReminderMailState.accepted,
    recipient: r.recipient,
    createdAt: r.at,
  );

  InvoiceMailSend _invoiceSend(DemoMailRecord r) => InvoiceMailSend(
    id: r.attemptId,
    invoiceId: r.invoiceId,
    kind: r.resend ? InvoiceMailKind.resend : InvoiceMailKind.first,
    state: ReminderMailState.accepted,
    recipient: r.recipient,
    createdAt: r.at,
    finishedAt: r.at,
  );

  // ── reminders ──────────────────────────────────────────────────────────

  Future<ReminderMailTarget> target(
    String workspaceId,
    String invoiceId,
  ) async => _target(workspaceId, invoiceId);

  Future<Map<String, ReminderMailLine>> lines(
    String workspaceId,
    List<String> invoiceIds,
  ) async => {
    for (final id in invoiceIds)
      id: ReminderMailLine(
        target: _target(workspaceId, id),
        lastSend: _of(DemoMailKind.reminder)
            .where((r) => r.invoiceId == id)
            .map(_reminderSend)
            .lastOrNull,
      ),
  };

  Future<List<ReminderMailSend>> awaiting(
    String workspaceId,
    String invoiceId,
  ) async => const [];

  Future<ReminderMailSend> sendReminder({
    required String workspaceId,
    required String invoiceId,
    required int level,
    required String attemptId,
    required ReminderMailLetter letter,
  }) async {
    final replay = _of(DemoMailKind.reminder)
        .where((r) => r.attemptId == attemptId)
        .firstOrNull;
    if (replay != null) return _reminderSend(replay);
    final target = _target(workspaceId, invoiceId);
    if (!target.available) {
      throw const ReminderMailRefused(noAddressMessage);
    }
    if (!_owes(invoiceId)) {
      throw const ReminderMailRefused('the invoice owes nothing');
    }
    if (_of(DemoMailKind.reminder)
        .any((r) => r.invoiceId == invoiceId && r.level == level)) {
      throw const ReminderMailRefused(
        'this reminder was already sent by e-mail',
      );
    }
    final record = _record(DemoMailKind.reminder, letter, (
      attemptId: attemptId,
      invoiceId: invoiceId,
      level: level,
      recipient: target.recipient,
    ));
    return _reminderSend(record);
  }

  DemoMailRecord _record(
    DemoMailKind kind,
    ReminderMailLetter letter,
    ({String attemptId, String invoiceId, int level, String recipient}) to, {
    bool resend = false,
  }) {
    final record = DemoMailRecord(
      kind: kind,
      attemptId: to.attemptId,
      invoiceId: to.invoiceId,
      level: to.level,
      recipient: to.recipient,
      subject: letter.subject,
      fileName: letter.fileName,
      language: letter.language,
      at: _now,
      resend: resend,
    );
    _records.add(record);
    return record;
  }

  // Nothing here is ever unconfirmed, so a person never decides one.
  Future<ReminderMailSend> resolveReminder(String attemptId) async =>
      _reminderSend(_records.firstWhere((r) => r.attemptId == attemptId));

  Future<InvoiceMailSend> resolveInvoice(String attemptId) async =>
      _invoiceSend(_records.firstWhere((r) => r.attemptId == attemptId));

  // ── invoices ───────────────────────────────────────────────────────────

  Future<InvoiceMailView> state(String workspaceId, String invoiceId) async {
    final target = _target(workspaceId, invoiceId);
    return InvoiceMailView(
      available: target.available,
      recipient: target.recipient,
      reason: switch (target.reason) {
        ReminderMailUnavailable.noAddress => InvoiceMailUnavailable.noAddress,
        ReminderMailUnavailable.featureOff => InvoiceMailUnavailable.featureOff,
        ReminderMailUnavailable.senderNotConfigured =>
          InvoiceMailUnavailable.senderNotConfigured,
        ReminderMailUnavailable.none => InvoiceMailUnavailable.none,
      },
      sends: [
        for (final r in _of(DemoMailKind.invoice).toList().reversed)
          if (r.invoiceId == invoiceId) _invoiceSend(r),
      ],
    );
  }

  Future<InvoiceMailSend> sendInvoice({
    required String workspaceId,
    required String invoiceId,
    required InvoiceMailKind kind,
    required String attemptId,
    required InvoiceMailLetter letter,
  }) async {
    final replay = _of(DemoMailKind.invoice)
        .where((r) => r.attemptId == attemptId)
        .firstOrNull;
    if (replay != null) return _invoiceSend(replay);
    final target = _target(workspaceId, invoiceId);
    if (!target.available) {
      throw const ReminderMailRefused(noAddressMessage);
    }
    if (kind == InvoiceMailKind.first &&
        _of(DemoMailKind.invoice).any((r) => r.invoiceId == invoiceId)) {
      throw const ReminderMailRefused(
        'this invoice was already sent by e-mail',
      );
    }
    return _invoiceSend(
      _record(
        DemoMailKind.invoice,
        letter,
        (
          attemptId: attemptId,
          invoiceId: invoiceId,
          level: 0,
          recipient: target.recipient,
        ),
        resend: kind == InvoiceMailKind.resend,
      ),
    );
  }
}
