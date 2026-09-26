// SPDX-License-Identifier: AGPL-3.0-or-later
//
// #1619 — the person confirms exactly what the assistant asked: the
// screen names the workspace, the assistant, the action, its subject and
// the change; Confirm and Decline are equal and nothing is preselected;
// each answer is sent once and said on screen; an expired, stale, unknown
// or answered confirmation offers nothing to press. The DTO never reads
// an unknown status as answerable.
import 'dart:async';

import 'package:deskilo/app/app.dart';
import 'package:deskilo/core/demo/data/action_confirmation_repository.dart';
import 'package:deskilo/features/mcp/domain/action_confirmation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../helpers/mock_providers.dart';

const _id = '6b1d3f0e-0000-4000-8000-00000000c0f1';

ActionConfirmation refund({ConfirmationStatus status = ConfirmationStatus.pending}) =>
    ActionConfirmation(
      id: _id,
      status: status,
      operation: 'request_refund',
      workspaceName: 'Kraftwerk',
      clientName: 'Test assistant',
      arguments: const {'invoice_id': 'inv-1', 'note': 'double charge'},
      target: const {'kind': 'invoice', 'number': 'F-2026-0042', 'total_cents': 12000, 'currency': 'EUR', 'period': '2026-09'},
    );

Future<FakeActionConfirmationRepository> pump(WidgetTester tester, ActionConfirmation? c) async {
  final repo = FakeActionConfirmationRepository();
  if (c != null) repo.confirmations[c.id] = c;
  tester.view.physicalSize = const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(ProviderScope(
    overrides: standardTestOverrides(actionConfirmations: repo),
    child: const DeskiloApp(),
  ));
  await tester.pumpAndSettle();
  unawaited(GoRouter.of(tester.element(find.byType(Scaffold).first)).push('/mcp/confirm/$_id'));
  await tester.pumpAndSettle();
  return repo;
}

void main() {
  group('the DTO', () {
    test('reads the server answer and never promotes the unknown', () {
      final c = ActionConfirmation.fromJson(_id, {
        'status': 'pending',
        'operation': 'request_refund',
        'workspace_name': 'Kraftwerk',
        'client_name': 'Test assistant',
        'preview': {'arguments': {'invoice_id': 'x'}, 'target': {'kind': 'invoice'}},
        'expires_at': '2026-09-26T12:05:00Z',
      });
      expect(c.status.answerable, isTrue);
      expect(c.target['kind'], 'invoice');
      expect(c.expiresAt, DateTime.utc(2026, 9, 26, 12, 5));
      for (final raw in <Object?>[null, 'x', {'status': 'approved'}, {'status': 'PENDING'}]) {
        final parsed = ActionConfirmation.fromJson(_id, raw);
        expect(parsed.status.answerable, isFalse, reason: '$raw');
      }
      expect(ConfirmationStatus.fromWire('target_changed'), ConfirmationStatus.targetChanged);
    });
  });

  testWidgets('the screen names what is being confirmed', (tester) async {
    await pump(tester, refund());
    expect(find.text('Refund an invoice'), findsOneWidget);
    expect(find.textContaining('F-2026-0042'), findsOneWidget);
    expect(find.textContaining('2026-09'), findsOneWidget);
    expect(find.text('Workspace: Kraftwerk'), findsOneWidget);
    expect(find.text('Asked by: Test assistant'), findsOneWidget);
    expect(find.byKey(const ValueKey('mcp-confirm-accept')), findsOneWidget);
    expect(find.byKey(const ValueKey('mcp-confirm-decline')), findsOneWidget);
  });

  testWidgets('Confirm sends one acceptance and says so', (tester) async {
    final repo = await pump(tester, refund());
    await tester.tap(find.byKey(const ValueKey('mcp-confirm-accept')));
    await tester.pumpAndSettle();
    expect(repo.answers, [(id: _id, accept: true)]);
    expect(find.byKey(const ValueKey('mcp-confirm-status-acknowledged')), findsOneWidget);
    expect(find.byKey(const ValueKey('mcp-confirm-accept')), findsNothing,
        reason: 'answered: nothing left to press');
  });

  testWidgets('Decline sends one refusal and says nothing was done', (tester) async {
    final repo = await pump(tester, refund());
    await tester.tap(find.byKey(const ValueKey('mcp-confirm-decline')));
    await tester.pumpAndSettle();
    expect(repo.answers, [(id: _id, accept: false)]);
    expect(find.text('Declined. Nothing was done.'), findsOneWidget);
  });

  testWidgets('expired, stale and unknown confirmations offer nothing to press',
      (tester) async {
    for (final (c, key) in [
      (refund(status: ConfirmationStatus.expired), 'mcp-confirm-status-expired'),
      (refund(status: ConfirmationStatus.revoked), 'mcp-confirm-status-revoked'),
      (null, 'mcp-confirm-status-notFound'),
    ]) {
      final repo = await pump(tester, c);
      expect(find.byKey(ValueKey(key)), findsOneWidget, reason: key);
      expect(find.byKey(const ValueKey('mcp-confirm-accept')), findsNothing, reason: key);
      expect(repo.answers, isEmpty);
    }
  });
}
