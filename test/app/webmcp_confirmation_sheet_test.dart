// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #2504 — the sheet an assistant's request opens: it says which workspace,
// what is asked and the answer it would send; Confirm and Decline are
// equal, and closing it decides nothing.
import 'package:deskilo/app/webmcp_confirmation_sheet.dart';
import 'package:deskilo/app/webmcp_confirmations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/pump_app.dart';

const _request = WebMcpConfirmationRequest(
  key: 'a|w|respond_to_validation|r1',
  operation: 'respond_to_validation',
  input: {'event_id': 'e1', 'accept': true},
);

void main() {
  for (final (button, expected) in [
    ('webmcp-confirm-accept', true),
    ('webmcp-confirm-decline', false),
  ]) {
    testWidgets('$button answers $expected', (tester) async {
      bool? answer;
      await pumpApp(
        tester,
        Builder(
          builder: (context) => TextButton(
            key: const ValueKey('open'),
            onPressed: () async => answer = await showWebMcpConfirmationSheet(
              context,
              _request,
              workspaceName: 'Atelier',
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('open')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Atelier'), findsOneWidget);
      await tester.tap(find.byKey(ValueKey(button)));
      await tester.pumpAndSettle();
      expect(answer, expected);
    });
  }
}
