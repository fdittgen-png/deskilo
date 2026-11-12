// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — an issued invoice sent by e-mail from the business's own sender.
// The server decides whether it may leave (0730: the first e-mail of an
// invoice once, "send again" as its own deliberate attempt, never a voided
// invoice, the customer's address on file, the sender configured) and holds
// the key; the app builds the invoice, its subject and its text in the
// customer's document language and asks.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

import 'reminder_mail.dart';

/// The feature key of invoices by e-mail (`WorkspaceFeature.invoiceEmail`).
const invoiceEmailKey = 'invoiceEmail';

/// The e-mail as it leaves: the same shape as a reminder's (0726).
typedef InvoiceMailLetter = ReminderMailLetter;

/// The first e-mail of an invoice, or a deliberate "send again".
enum InvoiceMailKind {
  first('first'),
  resend('resend');

  const InvoiceMailKind(this.wire);
  final String wire;

  static InvoiceMailKind of(String wire) =>
      values.firstWhere((k) => k.wire == wire, orElse: () => first);
}

/// Why an invoice cannot leave by e-mail.
enum InvoiceMailUnavailable {
  none(''),
  featureOff('feature_off'),
  voided('voided'),
  noAddress('no_address'),
  senderNotConfigured('sender_not_configured');

  const InvoiceMailUnavailable(this.wire);
  final String wire;

  static InvoiceMailUnavailable of(String wire) =>
      values.firstWhere((r) => r.wire == wire, orElse: () => featureOff);
}

/// One e-mail attempt of an invoice (`invoice_email_sends`, 0730).
class InvoiceMailSend {
  const InvoiceMailSend({
    required this.id,
    required this.invoiceId,
    required this.kind,
    required this.state,
    required this.recipient,
    this.reason = '',
    this.createdAt,
    this.finishedAt,
  });

  factory InvoiceMailSend.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'invoice mail send');
    return InvoiceMailSend(
      id: r.string('id'),
      invoiceId: r.string('invoice_id'),
      kind: InvoiceMailKind.of(r.stringOr('kind', 'first')),
      state: ReminderMailState.of(r.stringOr('state', 'pending')),
      recipient: r.stringOr('recipient'),
      reason: r.stringOr('reason'),
      createdAt: DateTime.tryParse(r.stringOr('created_at')),
      finishedAt: DateTime.tryParse(r.stringOr('finished_at')),
    );
  }

  final String id;
  final String invoiceId;
  final InvoiceMailKind kind;

  /// The same states as a reminder's e-mail (0726): pending, accepted,
  /// refused, unconfirmed, delivered, not delivered.
  final ReminderMailState state;
  final String recipient;
  final String reason;
  final DateTime? createdAt;
  final DateTime? finishedAt;

  /// It left: the provider accepted it, or a person confirmed it arrived.
  bool get left =>
      state == ReminderMailState.accepted ||
      state == ReminderMailState.delivered;

  /// Nobody knows whether it left: a person decides.
  bool get awaitsDecision =>
      state == ReminderMailState.unconfirmed ||
      state == ReminderMailState.pending;
}

/// What the invoice page shows about e-mail (`invoice_email_state_v1`):
/// whether the customer can be e-mailed (or why not), and every attempt,
/// newest first.
class InvoiceMailView {
  const InvoiceMailView({
    required this.available,
    this.recipient = '',
    this.reason = InvoiceMailUnavailable.none,
    this.sends = const [],
  });

  factory InvoiceMailView.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'invoice mail state');
    return InvoiceMailView(
      available: r.boolOr('available', fallback: false),
      recipient: r.stringOr('recipient'),
      reason: InvoiceMailUnavailable.of(r.stringOr('reason')),
      sends: r.objects('sends', (row) => InvoiceMailSend.fromJson(row.json)),
    );
  }

  final bool available;
  final String recipient;
  final InvoiceMailUnavailable reason;
  final List<InvoiceMailSend> sends;

  /// The latest attempt, or null when none was made.
  InvoiceMailSend? get latest => sends.firstOrNull;

  /// The latest e-mail that left, or null.
  InvoiceMailSend? get lastLeft => sends.where((s) => s.left).firstOrNull;
}

/// The server's side of invoices by e-mail.
abstract interface class InvoiceMail {
  /// What the invoice page shows for [invoiceId].
  Future<InvoiceMailView> state(String workspaceId, String invoiceId);

  /// Sends [letter] as [kind]; [attemptId] is drawn once per press and
  /// replays the same attempt. A refusal throws a [ReminderMailRefusal]
  /// (the same three as a reminder's); any other failure may not have
  /// reached the server.
  Future<InvoiceMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required InvoiceMailKind kind,
    required String attemptId,
    required InvoiceMailLetter letter,
  });

  /// A person decides an e-mail nobody could confirm.
  Future<InvoiceMailSend> resolve(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  });
}
