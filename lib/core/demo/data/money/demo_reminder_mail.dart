// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3673 — the Demo sends no e-mail: reminders by e-mail are left off in
// every Demo space (demo_flags.dart), and if one were switched on the
// channel is not offered and a send is refused before anything leaves.
import '../../../../features/money/domain/reminder_mail.dart';

class DemoReminderMail implements ReminderMail {
  const DemoReminderMail();

  @override
  Future<ReminderMailTarget> target(
    String workspaceId,
    String invoiceId,
  ) async => const ReminderMailTarget(
    available: false,
    reason: ReminderMailUnavailable.featureOff,
  );

  @override
  Future<List<ReminderMailSend>> awaiting(
    String workspaceId,
    String invoiceId,
  ) async => const [];

  @override
  Future<ReminderMailSend> send({
    required String workspaceId,
    required String invoiceId,
    required int level,
    required String attemptId,
    required ReminderMailLetter letter,
  }) => Future.error(StateError('the Demo sends no e-mail'));

  @override
  Future<ReminderMailSend> resolve(
    String workspaceId,
    String attemptId, {
    required bool delivered,
  }) => Future.error(StateError('the Demo sends no e-mail'));
}
