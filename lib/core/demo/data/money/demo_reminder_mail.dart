// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3960 — reminders by e-mail in the Demo: the session's outbox records the
// send and answers as the server does; nothing leaves the device.
import '../../../../features/money/domain/reminder_mail.dart';
import 'demo_outbox.dart';

class DemoReminderMail implements ReminderMail {
  const DemoReminderMail(this._outbox);

  final DemoOutbox _outbox;

  @override
  Future<ReminderMailTarget> target(String workspaceId, String invoiceId) =>
      _outbox.target(workspaceId, invoiceId);

  @override
  Future<Map<String, ReminderMailLine>> lines(
    String workspaceId,
    List<String> invoiceIds,
  ) => _outbox.lines(workspaceId, invoiceIds);

  @override
  Future<List<ReminderMailSend>> awaiting(
    String workspaceId,
    String invoiceId,
  ) => _outbox.awaiting(workspaceId, invoiceId);

  @override
  Future<ReminderMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required int level,
    required String attemptId,
    required ReminderMailLetter letter,
  }) => _outbox.sendReminder(
    workspaceId: workspaceId,
    invoiceId: invoiceId,
    level: level,
    attemptId: attemptId,
    letter: letter,
  );

  // Every e-mail of the outbox is accepted: none is left to decide.
  @override
  Future<ReminderMailSend> resolve(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) => _outbox.resolveReminder(attemptId);
}
