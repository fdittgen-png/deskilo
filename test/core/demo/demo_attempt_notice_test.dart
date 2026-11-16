// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #4136 — the Demo's payment attempt that could not be checked: Bruno paid
// his open bill online at Mollie and the reconciliation could not reach it.
// Ada, the owner, reads the notice in her events, naming the payment, Bruno
// and the reason, and its row opens Bruno's account; Bruno, whom it names,
// does not read it.
import 'package:deskilo/core/demo/demo_fixture.dart';
import 'package:deskilo/core/demo/demo_persona.dart';
import 'package:deskilo/core/i18n/money_format.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/features/events/presentation/event_destination.dart';
import 'package:deskilo/features/events/presentation/event_lines.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<List<WorkspaceEvent>> _notices(DemoPersona persona) async {
  final fixture = DemoFixture.build()..becomePersona(persona);
  return [
    for (final e in await fixture.events.fetchEvents('ws-1'))
      if (e.type == EventType.paymentAttemptUnreadable) e,
  ];
}

void main() {
  test(
    'the owner reads the notice of Bruno\'s payment and opens his account',
    () async {
      final notices = await _notices(DemoPersona.owner);
      expect(notices, hasLength(1));
      final notice = notices.single;
      final l10n = lookupAppLocalizations(const Locale('en'));
      final line = eventLine(
        l10n,
        notice,
        const {'member-1': 'Ada Lindqvist', 'member-2': 'Bruno Kessler'},
        const {},
        MoneyFormat('EUR', locale: null),
      );
      expect(line, contains('Bruno Kessler'));
      expect(line, contains('Mollie'));
      expect(line, contains(l10n.paymentAttemptReasonUnreachable));
      expect(line, contains('${notice.payload['reference']}'));
      expect(eventDestination(notice), '/invoices/customer/member-2');
    },
  );

  test('Bruno, whom it names, does not read it without the right', () async {
    expect(await _notices(DemoPersona.member), isEmpty);
  });
}
