// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4325: the notice that an e-invoice attempt stopped half-way, in every
// language: an uncertain dispatch ("outcome unknown, not sent again") and a
// prepared one that was never sent; once the transmission moved on, it says
// so. Filed under money, read with issueInvoices, told by nobody.
import 'package:deskilo/core/demo/data/event_visibility.dart';
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/events/domain/notification_feed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_labels.dart';
import 'package:deskilo/features/events/presentation/event_lines.dart';
import 'package:deskilo/features/workspace/domain/workspace_permission.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

WorkspaceEvent _notice(String phase, {String? ended}) => WorkspaceEvent(
  id: 'notice-$phase-$ended',
  workspaceId: 'ws-1',
  type: EventType.fromDb('einvoice_outcome_unknown'),
  action: EventAction.created,
  actorMemberId: 'owner',
  subjectMemberId: 'owner',
  payload: {
    'transmission': 't-1',
    'invoice_id': 'i-1',
    'phase': phase,
    'provider': 'generic',
    'destination': 'government',
    'environment': 'prod',
    'ended': ?ended,
  },
  status: EventStatus.applied,
  createdAt: DateTime.utc(2026, 11),
);

String _line(AppLocalizations l10n, WorkspaceEvent event) => eventLine(
  l10n,
  event,
  const {'owner': 'Florian'},
  const {},
  MoneyFormat('EUR', locale: null),
);

void main() {
  for (final language in const ['en', 'fr', 'de', 'es', 'it']) {
    test('$language: an uncertain dispatch and a prepared one, each in its '
        'own words, and the end', () {
      final l10n = lookupAppLocalizations(Locale(language));
      final uncertain = _line(l10n, _notice('uncertain'));
      final prepared = _line(l10n, _notice('prepared'));
      expect(uncertain, l10n.eventEinvoiceOutcomeUncertain);
      expect(prepared, l10n.eventEinvoiceStuckPrepared);
      expect(uncertain, isNot(prepared));
      expect(
        _line(l10n, _notice('uncertain', ended: 'accepted')),
        '$uncertain · ${l10n.eventEinvoiceNoticeEnded}',
      );
      expect(uncertain, isNot(contains('Florian')), reason: 'a job acts');
      expect(
        eventTypeLabel(l10n, EventType.einvoiceOutcomeUnknown),
        l10n.eventTypeEinvoiceOutcomeUnknown,
      );
    });
  }

  test('the wire word is read, filed under money and read with '
      'issueInvoices', () {
    final notice = _notice('uncertain');
    expect(notice.type, EventType.einvoiceOutcomeUnknown);
    expect(categoryOfEvent(notice), NotificationCategory.money);
    expect(eventTypeViewPermissions('einvoice_outcome_unknown'), {
      WorkspacePermission.issueInvoices,
    });
  });
}
