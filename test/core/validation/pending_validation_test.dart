// SPDX-License-Identifier: 0BSD
//
// #982 — the pending outcome: a request function's answer either
// applied (an id) or was held (a pending event), and runGuarded turns
// the held case into one calm notice, not an error.
import 'package:deskilo/core/trace/guarded.dart';
import 'package:deskilo/core/validation/pending_validation.dart';
import 'package:deskilo/features/events/domain/workspace_event.dart';
import 'package:deskilo/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('applyOrPending: the id when applied, the exception when held', () {
    expect(applyOrPending({'pending': false, 'invoice_id': 'inv-1'}), 'inv-1');
    expect(applyOrPending({'pending': false}), '');
    expect(() => applyOrPending({'pending': true, 'event_id': 'ev-9'}),
        throwsA(isA<PendingValidationException>()
            .having((e) => e.eventId, 'eventId', 'ev-9')));
  });

  test('the six domains exist on the wire, spelled as the server spells them',
      () {
    final wires = EventType.values.map((t) => t.dbName).toSet();
    expect(wires, containsAll([
      'invoice_issue', 'invoice_void', 'refund', 'member_status_change',
      'subscription_change', 'matrix_change',
    ]));
  });

  testWidgets('runGuarded: a held request is a notice, and "not done"',
      (tester) async {
    bool? result;
    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              result = await runGuarded(
                context,
                domain: 'test',
                message: 'held',
                errorText: 'It failed.',
                action: () async =>
                    throw const PendingValidationException('ev-1'),
              );
            },
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    expect(result, isFalse);
    expect(find.textContaining('Sent for validation'), findsOneWidget);
    expect(find.text('It failed.'), findsNothing);
  });
}
