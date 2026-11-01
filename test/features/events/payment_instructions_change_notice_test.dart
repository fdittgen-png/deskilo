// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3132: the owners' notice that an assistant changed the bank account, in
// every language: it names who and which fields, never the account.
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/events/domain/notification_feed.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_labels.dart';
import 'package:deskilo/features/events/presentation/event_lines.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final language in const ['en', 'fr', 'de', 'es', 'it']) {
    test('$language: the notice names who changed which fields, not the '
        'account', () {
      final l10n = lookupAppLocalizations(Locale(language));
      final event = WorkspaceEvent(
        id: 'notice',
        workspaceId: 'ws-1',
        type: EventType.paymentInstructionsChange,
        action: EventAction.modified,
        actorMemberId: 'delegate',
        subjectMemberId: 'owner',
        payload: const {
          'fields': ['iban', 'bic'],
          'iban_before': '0189',
          'iban_after': '3000',
        },
        status: EventStatus.applied,
        createdAt: DateTime.utc(2026, 11),
      );
      final line = eventLine(
        l10n,
        event,
        const {'delegate': 'Camille', 'owner': 'Florian'},
        const {},
        MoneyFormat('EUR'),
      );
      expect(
        line,
        l10n.eventPaymentInstructionsChange(
          'Camille',
          '${l10n.paymentInstructionsIbanTitle}, ${l10n.paymentBicLabel}',
        ),
      );
      expect(line, isNot(contains('Florian')), reason: 'one notice, no suffix');
      expect(
        eventTypeLabel(l10n, event.type),
        l10n.eventTypePaymentInstructionsChange,
      );
      expect(categoryOfEvent(event), NotificationCategory.money);
    });
  }
}
