// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Who the app tells about what, and how it reaches them — the product's own
// rule, read from the switched-on features. The events trigger sends a
// phone notification for a request waiting on whoever decides it, a booking
// an administrator removed, a message, a mention and a payment reminder
// (`send-push`); a device registers for them only while phone notifications
// are on. The check-in reminder is scheduled on the member's own phone and
// needs no push at all. Pure Dart: the setup guide's notifications step
// shows it, and nothing here decides who receives anything.
import 'workspace_feature.dart';

/// Who is told: whoever decides a request (an administrator, or the member
/// a request concerns), or the members.
enum NotifiedAudience { deciders, members }

/// How it reaches them: in the app, as a phone notification, or as a
/// reminder the member's own phone schedules.
enum NotificationChannel { app, push, device }

/// One kind of notice, by the event that raises it.
class NotificationLine {
  const NotificationLine(
    this.event, {
    required this.audience,
    required this.channels,
  });

  /// `pending_request`, `reservation_cancelled`, `check_in`, `member_note`,
  /// `member_mention` or `invoice_reminder`.
  final String event;
  final NotifiedAudience audience;
  final Set<NotificationChannel> channels;
}

/// The notices a workspace whose features are [on] sends, the deciders'
/// first.
List<NotificationLine> notificationLines(Set<WorkspaceFeature> on) {
  final inApp = {
    NotificationChannel.app,
    if (on.contains(WorkspaceFeature.pushNotifications))
      NotificationChannel.push,
  };
  return [
    NotificationLine(
      'pending_request',
      audience: NotifiedAudience.deciders,
      channels: inApp,
    ),
    NotificationLine(
      'reservation_cancelled',
      audience: NotifiedAudience.members,
      channels: inApp,
    ),
    const NotificationLine(
      'check_in',
      audience: NotifiedAudience.members,
      channels: {NotificationChannel.device},
    ),
    if (on.contains(WorkspaceFeature.memberNotifications))
      NotificationLine(
        'member_note',
        audience: NotifiedAudience.members,
        channels: inApp,
      ),
    if (on.contains(WorkspaceFeature.messageMentions))
      NotificationLine(
        'member_mention',
        audience: NotifiedAudience.members,
        channels: inApp,
      ),
    if (on.contains(WorkspaceFeature.dunning))
      NotificationLine(
        'invoice_reminder',
        audience: NotifiedAudience.members,
        channels: inApp,
      ),
  ];
}
