// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3914: the entry a credentials change leaves, in every language: who set,
// replaced or cleared which provider's credentials, and the names of the keys
// -- the entry holds no value, so none can be shown.
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

WorkspaceEvent _entry(String area, String change) => WorkspaceEvent(
  id: 'entry-$area-$change',
  workspaceId: 'ws-1',
  type: EventType.fromDb('credential_change'),
  action: EventAction.modified,
  actorMemberId: 'delegate',
  subjectMemberId: 'owner',
  payload: {
    'area': area,
    'provider': area == 'payment' ? 'stripe' : 'peppol',
    'change': change,
    'keys': const ['api_key', 'endpoint'],
  },
  status: EventStatus.applied,
  createdAt: DateTime.utc(2026, 11),
);

String _line(AppLocalizations l10n, WorkspaceEvent event) => eventLine(
  l10n,
  event,
  const {'delegate': 'Camille', 'owner': 'Florian'},
  const {},
  MoneyFormat('EUR', locale: null),
);

void main() {
  for (final language in const ['en', 'fr', 'de', 'es', 'it']) {
    test('$language: the entry names who changed which provider\'s '
        'credentials, and the keys', () {
      final l10n = lookupAppLocalizations(Locale(language));
      expect(
        _line(l10n, _entry('payment', 'set')),
        l10n.eventCredentialSet(
          'Camille',
          'stripe',
          l10n.eventCredentialAreaPayment,
          'api_key, endpoint',
        ),
      );
      expect(
        _line(l10n, _entry('einvoice', 'replace')),
        l10n.eventCredentialReplaced(
          'Camille',
          'peppol',
          l10n.eventCredentialAreaEinvoice,
          'api_key, endpoint',
        ),
      );
      expect(
        _line(l10n, _entry('einvoice', 'clear')),
        l10n.eventCredentialCleared(
          'Camille',
          'peppol',
          l10n.eventCredentialAreaEinvoice,
          'api_key, endpoint',
        ),
      );
      expect(
        _line(l10n, _entry('payment', 'set')),
        isNot(contains('Florian')),
        reason: 'one entry, no suffix',
      );
      expect(
        eventTypeLabel(l10n, EventType.credentialChange),
        l10n.eventTypeCredentialChange,
      );
    });
  }

  test('the wire word is read, filed under money, and seen by those who '
      'manage the integrations', () {
    final event = _entry('payment', 'set');
    expect(event.type, EventType.credentialChange);
    expect(categoryOfEvent(event), NotificationCategory.money);
    expect(eventTypeViewPermissions('credential_change'), {
      WorkspacePermission.manageIntegrations,
    });
  });
}
