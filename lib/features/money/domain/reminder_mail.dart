// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — a payment reminder sent by e-mail from the business's own sender.
// The server decides whether it may leave (0726: once per invoice and
// level, the customer's address on file, the sender configured) and holds
// the key; the app composes the letter, the subject and the text in the
// customer's document language and asks.
import 'package:deskilo_money_kernel/deskilo_money_kernel.dart';

/// The feature key of reminders by e-mail (`WorkspaceFeature.reminderEmail`).
const reminderEmailKey = 'reminderEmail';

/// Why a reminder of one invoice cannot leave by e-mail.
enum ReminderMailUnavailable {
  none(''),
  featureOff('feature_off'),
  noAddress('no_address'),
  senderNotConfigured('sender_not_configured');

  const ReminderMailUnavailable(this.wire);
  final String wire;

  static ReminderMailUnavailable of(String wire) =>
      values.firstWhere((r) => r.wire == wire, orElse: () => featureOff);
}

/// Whether a reminder of one invoice can leave by e-mail, and to whom
/// (`reminder_email_target_v1`).
class ReminderMailTarget {
  const ReminderMailTarget({
    required this.available,
    this.recipient = '',
    this.reason = ReminderMailUnavailable.none,
  });

  factory ReminderMailTarget.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'reminder mail target');
    return ReminderMailTarget(
      available: r.boolOr('available', fallback: false),
      recipient: r.stringOr('recipient'),
      reason: ReminderMailUnavailable.of(r.stringOr('reason')),
    );
  }

  final bool available;
  final String recipient;
  final ReminderMailUnavailable reason;
}

/// Where one e-mail of a reminder stands. `unconfirmed` is nobody knowing
/// whether it left: a person decides it; it is never sent again on its own.
enum ReminderMailState {
  pending('pending'),
  accepted('accepted'),
  refused('refused'),
  unconfirmed('unconfirmed'),
  delivered('delivered'),
  notDelivered('not_delivered');

  const ReminderMailState(this.wire);
  final String wire;

  static ReminderMailState of(String wire) =>
      values.firstWhere((s) => s.wire == wire, orElse: () => pending);
}

/// One e-mail attempt of a reminder (`reminder_email_sends`, 0726).
class ReminderMailSend {
  const ReminderMailSend({
    required this.id,
    required this.invoiceId,
    required this.level,
    required this.state,
    required this.recipient,
    this.reason = '',
    this.createdAt,
  });

  factory ReminderMailSend.fromJson(Object? raw) {
    final r = JsonReader.of(raw, context: 'reminder mail send');
    return ReminderMailSend(
      id: r.string('id'),
      invoiceId: r.string('invoice_id'),
      level: r.integer('level'),
      state: ReminderMailState.of(r.stringOr('state', 'pending')),
      recipient: r.stringOr('recipient'),
      reason: r.stringOr('reason'),
      createdAt: DateTime.tryParse(
        r.stringOrNull('created_at') ?? r.stringOr('created_datetime'),
      ),
    );
  }

  final String id;
  final String invoiceId;
  final int level;
  final ReminderMailState state;
  final String recipient;
  final String reason;
  final DateTime? createdAt;

  /// Nobody knows whether it left: a person decides.
  bool get awaitsDecision => state == ReminderMailState.unconfirmed;
}

/// The letter as it leaves: composed by the app in the customer's document
/// [language], which the server records and never chooses.
class ReminderMailLetter {
  const ReminderMailLetter({
    required this.language,
    required this.subject,
    required this.text,
    required this.pdfBase64,
    required this.fileName,
  });

  final String language;
  final String subject;
  final String text;
  final String pdfBase64;
  final String fileName;
}

/// The server refused to send, for a reason the person acts on.
sealed class ReminderMailRefusal implements Exception {
  const ReminderMailRefusal();
}

/// The reminder level moved on since the letter was built: nothing left.
class ReminderMailLevelChanged extends ReminderMailRefusal {
  const ReminderMailLevelChanged();
}

/// An earlier e-mail of this reminder has no confirmed outcome: a person
/// decides it before anything is sent again.
class ReminderMailAwaitsDecision extends ReminderMailRefusal {
  const ReminderMailAwaitsDecision();
}

/// Any other refusal (rights, the invoice, the address): nothing left.
class ReminderMailRefused extends ReminderMailRefusal {
  const ReminderMailRefused(this.message);
  final String message;
}

/// The server's side of reminders by e-mail.
abstract interface class ReminderMail {
  /// Whether a reminder of [invoiceId] can leave by e-mail, and to whom.
  Future<ReminderMailTarget> target(String workspaceId, String invoiceId);

  /// The e-mails of [invoiceId] that nobody could confirm.
  Future<List<ReminderMailSend>> awaiting(String workspaceId, String invoiceId);

  /// Sends the reminder at [level]; [attemptId] is drawn once per press and
  /// replays the same attempt. A refusal throws a [ReminderMailRefusal];
  /// any other failure may not have reached the server.
  Future<ReminderMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required int level,
    required String attemptId,
    required ReminderMailLetter letter,
  });

  /// A person decides an e-mail nobody could confirm.
  Future<ReminderMailSend> resolve(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  });
}
