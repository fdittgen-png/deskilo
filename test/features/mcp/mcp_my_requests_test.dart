// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #3978 — the assistants page lists the person's own requests: the waiting
// ones with the way to their confirmation page, the answered ones with
// their answer and no way in; nothing to list, no section; a failed read
// says so. The server's answer is read as one request is.
import 'dart:convert';

import 'package:deskilo/features/mcp/data/supabase_action_confirmation_repository.dart';
import 'package:deskilo/features/mcp/domain/action_confirmation.dart';
import 'package:deskilo/features/mcp/presentation/widgets/mcp_my_requests_section.dart';
import 'package:deskilo/features/mcp/providers/my_confirmations_provider.dart';
import 'package:deskilo/l10n/app_localizations_en.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/pump_app.dart';

final _en = AppLocalizationsEn();

ActionConfirmation _request(String id, ConfirmationStatus status) =>
    ActionConfirmation(
      id: id,
      status: status,
      operation: 'respond_to_validation',
      workspaceName: 'Atelier',
      clientName: 'Helper',
      askedAt: DateTime.utc(2026, 5, 4, 9),
    );

Future<void> _pump(
  WidgetTester tester,
  Future<List<ActionConfirmation>> Function() read, {
  Size size = const Size(390, 900),
}) async {
  await pumpApp(
    tester,
    const Scaffold(body: SingleChildScrollView(child: McpMyRequestsSection())),
    size: size,
    overrides: [myActionConfirmationsProvider.overrideWith((ref) => read())],
  );
  await tester.pump();
}

void main() {
  for (final size in const [Size(390, 900), Size(1280, 900)]) {
    testWidgets('waiting requests open their page, answered ones carry their '
        'answer (${size.width.toInt()} wide)', (tester) async {
      await _pump(
        tester,
        () async => [
          _request('w', ConfirmationStatus.pending),
          _request('a', ConfirmationStatus.acknowledged),
          _request('d', ConfirmationStatus.declined),
          _request('x', ConfirmationStatus.expired),
        ],
        size: size,
      );
      expect(find.text(_en.mcpRequestsWaitingTitle), findsOneWidget);
      expect(find.byKey(const ValueKey('mcp-request-open-w')), findsOneWidget);
      expect(find.text(_en.mcpRequestsAnsweredTitle), findsOneWidget);
      for (final word in [
        _en.mcpRequestConfirmed,
        _en.mcpRequestRefused,
        _en.mcpRequestExpired,
      ]) {
        expect(find.text(word), findsOneWidget);
      }
      expect(find.byKey(const ValueKey('mcp-request-open-a')), findsNothing);
      expect(find.textContaining('Asked by Helper in Atelier'), findsWidgets);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('nothing to list shows no section', (tester) async {
    await _pump(tester, () async => const []);
    expect(find.byKey(const ValueKey('mcp-requests')), findsNothing);
    expect(find.text(_en.mcpRequestsWaitingTitle), findsNothing);
  });

  testWidgets('a failed read says so, never an empty list', (tester) async {
    await _pump(tester, () async => throw StateError('offline'));
    expect(
      find.byKey(const ValueKey('read-failure')),
      findsOneWidget,
    );
  });

  test('the server is asked for the answers since the moment named, and '
      'its rows read as one request reads', () async {
    Object? sent;
    final client = SupabaseClient(
      'https://assistants.example',
      'sb_publishable_test',
      httpClient: MockClient((r) async {
        sent = jsonDecode(r.body);
        return http.Response(
          jsonEncode([
            {
              'id': 'w',
              'status': 'pending',
              'operation': 'respond_to_validation',
              'client_name': 'Helper',
              'workspace_name': 'Atelier',
              'created_at': '2026-05-04T09:00:00Z',
            },
            {'id': 'u', 'status': 'some_later_state'},
            {'status': 'pending'},
          ]),
          200,
          headers: {'content-type': 'application/json'},
          request: r,
        );
      }),
    );
    final mine = await SupabaseActionConfirmationRepository(client)
        .mine(answeredSince: DateTime.utc(2026, 4, 27));
    expect(sent, {'p_answered_since': '2026-04-27T00:00:00.000Z'});
    expect([for (final c in mine) c.id], ['w', 'u']);
    expect(mine.first.askedAt, DateTime.utc(2026, 5, 4, 9));
    expect(mine.first.status, ConfirmationStatus.pending);
    expect(
      mine.last.status,
      ConfirmationStatus.unavailable,
      reason: 'a state this version cannot read is never waiting',
    );
  });
}
