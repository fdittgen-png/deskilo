// SPDX-License-Identifier: 0BSD
import '../trace/trace_logger.dart';
import 'notification_service.dart';

/// Schedules the member's check-in reminders, best-effort (spec §4.3) —
/// and best-effort still has to be OBSERVABLE (#1094).
///
/// The shell called this from a provider listener, unawaited and with no
/// catch, so a failure completed into nothing: the member never got the
/// reminder and no trace point said why. #614 already cost this
/// subsystem one real reminder-loss bug; a silent path here is how the
/// next one hides.
///
/// A failure is never surfaced to the UI — a reminder is not something
/// the member asked for right now — but it always leaves a breadcrumb.
Future<void> scheduleCheckInReminders(
  NotificationService service,
  List<ReminderRequest> reminders,
) async {
  try {
    await service.rescheduleCheckInReminders(reminders);
  } catch (e, st) {
    TraceLogger.instance.warn(
      'notifications',
      'check-in reminder reschedule failed — ${reminders.length} pending',
      error: e,
      stackTrace: st,
    );
  }
}
