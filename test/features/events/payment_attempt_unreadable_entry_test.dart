// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4136: the notice that a payment attempt could not be checked at its
// provider, in every language: which payment, whose, how much, at which
// provider and why; once the attempt was read, paid or ended, it says so.
// Filed under money, read with viewFinances, and its row opens the account of
// the member who pays.
import 'package:deskilo/core/demo/data/event_visibility.dart';
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/events/domain/notification_feed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_destination.dart';
import 'package:deskilo/features/events/presentation/event_labels.dart';
import 'package:deskilo/features/events/presentation/event_lines.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvent _notice(String reason, {String? ended}) => WorkspaceEvent(
  id: 'notice-$reason-$ended',
  workspaceId: 'ws-1',
  type: EventType.fromDb('payment_attempt_unreadable'),
  action: EventAction.created,
  actorMemberId: 'owner',
  subjectMemberId: 'owner',
  payload: {
    'intent': 'intent-1',
    'member_id': 'payer',
    'reference': 'PAY-2026-0117',
    'provider': 'paypal',
    'amount_cents': 4200,
    'currency': 'EUR',
    'reason': reason,
    'ended': ?ended,
  },
  status: EventStatus.applied,
  createdAt: DateTime.utc(2026, 11),
);

final _money = MoneyFormat('EUR', locale: null);

String _line(AppLocalizations l10n, WorkspaceEvent event) => eventLine(
  l10n,
  event,
  const {'owner': 'Florian', 'payer': 'Camille'},
  const {},
  _money,
);

void main() {
  for (final language in const ['en', 'fr', 'de', 'es', 'it']) {
    test('$language: the notice names the payment, its member, the provider '
        'and the reason; its end', () {
      final l10n = lookupAppLocalizations(Locale(language));
      final reasons = {
        'unreachable': l10n.paymentAttemptReasonUnreachable,
        'refused': l10n.paymentAttemptReasonRefused,
        'not_configured': l10n.paymentAttemptReasonNotConfigured,
        'unknown_order': l10n.paymentAttemptReasonUnknownOrder,
        'mismatch': l10n.paymentAttemptReasonMismatch,
        'unexpected_answer': l10n.paymentAttemptReasonUnexpectedAnswer,
        'record_failed': l10n.paymentAttemptReasonRecordFailed,
        'approved_not_captured': l10n.paymentAttemptReasonApprovedNotCaptured,
      };
      for (final MapEntry(key: wire, value: words) in reasons.entries) {
        expect(
          _line(l10n, _notice(wire)),
          l10n.eventPaymentAttemptUnreadable(
            'PAY-2026-0117',
            'Camille',
            _money.formatMinor(4200),
            'PayPal',
            words,
          ),
        );
      }
      expect(
        reasons.values.toSet(),
        hasLength(reasons.length),
        reason: 'each reason in its own words',
      );
      final open = _line(l10n, _notice('refused'));
      expect(
        _line(l10n, _notice('refused', ended: 'read')),
        '$open · ${l10n.eventPaymentAttemptNoticeRead}',
      );
      expect(
        _line(l10n, _notice('refused', ended: 'settled')),
        '$open · ${l10n.eventPaymentAttemptNoticeSettled}',
      );
      expect(
        _line(l10n, _notice('refused', ended: 'ended')),
        '$open · ${l10n.eventPaymentAttemptNoticeEnded}',
      );
      expect(
        open,
        isNot(contains('Florian')),
        reason: 'the job acts, nobody did',
      );
      expect(
        eventTypeLabel(l10n, EventType.paymentAttemptUnreadable),
        l10n.eventTypePaymentAttemptUnreadable,
      );
    });
  }

  test('the wire word is read, filed under money, read with viewFinances, '
      'and opens the member\'s account', () {
    final notice = _notice('unreachable');
    expect(notice.type, EventType.paymentAttemptUnreadable);
    expect(categoryOfEvent(notice), NotificationCategory.money);
    expect(eventTypeViewPermissions('payment_attempt_unreadable'), {
      WorkspacePermission.viewFinances,
    });
    expect(eventDestination(notice), '/invoices/customer/payer');
    expect(
      eventDestination(_credentialEntry()),
      isNull,
      reason: 'another notice leads nowhere',
    );
  });
}

WorkspaceEvent _credentialEntry() => WorkspaceEvent(
  id: 'entry',
  workspaceId: 'ws-1',
  type: EventType.credentialChange,
  action: EventAction.modified,
  actorMemberId: 'owner',
  subjectMemberId: 'owner',
  payload: const {},
  status: EventStatus.applied,
  createdAt: DateTime.utc(2026, 11),
);
